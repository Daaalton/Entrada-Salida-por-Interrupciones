

	ORG $0
	DC.L $8000 * Valor inicial del puntero de pila
	*DC.L PPAL * Programa principal
	DC.L INICIO * Direccion RTI de la interrupcion Reset, etiqueta del programa ppal
	ORG $400


*********************************Definición de equivalencias*********************************

SIZE 	EQU 	2001		* tamaño del buffer

MR1A	EQU		$EFFC01
MR2A	EQU		$EFFC01
SRA		EQU		$EFFC03
CSRA	EQU		$EFFC03
CRA		EQU		$EFFC05
TBA		EQU		$EFFC07
RBA		EQU		$EFFC07

ACR		EQU		$EFFC09
IMR		EQU		$EFFC0B
ISR		EQU		$EFFC0B

MR1B	EQU		$EFFC11
MR2B	EQU		$EFFC11
CRB     EQU     $effc15
TBB     EQU     $effc17
RBB     EQU     $effc17

SRB     EQU     $effc13
CSRB    EQU     $effc13
IVR		EQU		$EFFC19


*********************************SUBRUTINA INIT*********************************

INIT:	MOVE.B 	#%00010000,CRB 		* Reinicia el puntero MR1B
		MOVE.B 	#%00000011,MR1B 	* 8 bits por caracter y RxRDY 
		MOVE.B 	#%00000000,MR2B 	* No activar eco ( bits 6,7 ≠ 01)
		MOVE.B	#%11001100,CSRB 	* Velocidad de recepcion = 38400 bits/s  

		MOVE.B	#%00010000,CRA		* Reinicia el puntero MR1A
		MOVE.B	#%00000011,MR1A		* 8 bits por carácter y RxRDY
		MOVE.B 	#%00000000,MR2A 	* No activar eco ( bits 6,7 ≠ 01)
		MOVE.B 	#%11001100,CSRA 	* Velocidad de recepcion = 38400 bits/s
		
		MOVE.B	#%00000000,ACR		* bit 7 = 0 (conjunto 1, velocidad = 38400 bps)
		MOVE.B	#%00000101,CRB 		* Habilitamos transmisión y recepcion en B  
		MOVE.B	#%00000101,CRA		* Habilitamos transmisión y recepción  en A

        MOVE.B  #%00100010,IMRCP  	* Copiamos IMR 
        MOVE.B  IMRCP,IMR
		MOVE.B  #$40,IVR          	* Vector de interrupcion = 64
        MOVE.L  #RTI,$100         
		BSR		INI_BUFS		
		RTS


*********************************SUBRUTINA SCAN*********************************

	SCAN:	LINK 	A6,#0
			MOVE.L	8(A6),A0		* A0 <- M(A6+8) = Buffer
			EOR.L   D3,D3
	        MOVE.W  12(A6),D3       * D3 <- Descriptor
	        EOR.L 	D4,D4
	        MOVE.W	14(A6),D4		* D4 <- Tamaño
	        EOR.L   D2,D2          	* D2 <- Contador de caracteres leidos

	        CMP.W   #0,D4
	        BEQ     SCAN_END        * ¿ tamaño == 0 ? -> END
			CMP.W   #0,D4          	* ¿ tamaño < 0 ? -> ERROR
	        BLT     SCAN_ERROR
	        CMP.W 	#1,D3
	        BEQ		SLINEA_A
	        CMP.W	#0,D3
	        BEQ		SLINEA_B
	        BRA 	SCAN_ERROR

SLINEA_A:	MOVE.L	#0,D0       	* Ponemos a 0 el descriptor (puerto A)
SLINEA_A_BUCLE:
			BSR 	LEECAR
			CMP.L   #-1,D0  		 	* ¿ buffer vacio ?
            BEQ     SCAN_LEIDO
            MOVE.B  D0,(A0)+   	    * Copiamos el caracter devuelto por LEECAR en la pos del buffer pasada
            SUB.W   #1,D4           * Tamaño --
            ADD.L   #1,D2           * Contador ++
            CMP.W   #0,D4			* ¿ tamaño = 0 ? 	
            BEQ     SCAN_LEIDO
            BRA    	SLINEA_A_BUCLE

SLINEA_B:	MOVE.L 	#1,D0       	* Ponemos a 1 el descriptor (puerto B)
SLINEA_B_BUCLE:
			BSR 	LEECAR
			CMP.L  	#-1,D0   		* ¿ buffer vacio ?
            BEQ     SCAN_LEIDO
            MOVE.B  D0,(A0)+   	    * Copiamos el caracter devuelto por LEECAR en la pos del buffer pasada
            SUB.W   #1,D4           * Tamaño --
            ADD.L   #1,D2           * Contador ++
            CMP.W   #0,D4			* ¿ tamaño = 0 ?
            BEQ     SCAN_LEIDO
            BRA    	SLINEA_B_BUCLE

SCAN_ERROR:	MOVE.L 	#-1,D0			* Escribimos el resultado de error
			BRA 	SCAN_END

SCAN_LEIDO:	MOVE.L 	D2,D0			* Dejamos el resultado en D0

SCAN_END:	UNLK A6
			RTS                  	 




*********************************SUBRUTINA PRINT*********************************

PRINT:          LINK    A6,#0
                MOVE.L  8(A6),A1        * A1 -> direccion del buffer
                EOR.L   D4,D4
                MOVE.W  12(A6),D4       * D4 -> descriptor
                EOR.L   D2,D2 
                MOVE.W  14(A6),D2       * D2 -> tamaño
                EOR.L   D3,D3           * D3 -> retorno (contador de caracteres escritos)
                CLR.L   D5
                MOVE.L  #$2700,D5       * Prepara SR

                CMP.W   #0,D2
                BLT     PRINT_ERROR     * si tamaño < 0 -> error
                CMP.W   #0,D4
                BEQ     PLINEA_A
                CMP.W   #1,D4
                BEQ     PLINEA_B
                BRA     PRINT_ERROR
                
PLINEA_A:       MOVE.L  #2,D0    
                CMP.W   #0,D2           * ¿ tamaño = 0 ?
                BEQ     INTERR_A
PLINEA_A_BUCLE:  MOVE.B  (A1)+,D1
                BSR     ESCCAR
                CMP.L   #-1,D0          * ¿ buffer = -1 ?
                BEQ     INTERR_A            
                ADD.L   #1,D3           * contador ++
                SUB.W   #1,D2           * tamaño --            
                CMP.W   #0,D2
                BNE     PLINEA_A_BUCLE
                BRA     INTERR_A

PLINEA_B:       MOVE.L  #3,D0    
                CMP.W   #0,D2           * ¿ tamaño = 0 ?
                BEQ     INTERR_B
PLINEA_B_BUCLE: MOVE.B  (A1)+,D1    
                BSR     ESCCAR
                CMP.L   #-1,D0          * ¿ buffer = -1 ?
                BEQ     INTERR_B            
                ADD.L   #1,D3           * contador ++
                SUB.W   #1,D2           * tamaño --        
                CMP.W   #0,D2
                BNE     PLINEA_B_BUCLE
                BRA     INTERR_B
    
INTERR_A:       CMP.L   #0,D3    
                BEQ     PRINT_ESCRITO    
                MOVE.W  SR,D6    
                MOVE.W  D5,SR    
                BSET    #0,IMRCP    
                MOVE.B  IMRCP,IMR
                MOVE.W  D6,SR    
                BRA     PRINT_ESCRITO
            
INTERR_B:       CMP.L   #0,D3
                BEQ     PRINT_ESCRITO
                MOVE.W  SR,D6    
                MOVE.W  D5,SR    
                BSET    #4,IMRCP    
                MOVE.B  IMRCP,IMR    
                MOVE.W  D6,SR    
                BRA     PRINT_ESCRITO

PRINT_ERROR:    MOVE.L  #-1,D0
                BRA     PRINT_END

PRINT_ESCRITO:  MOVE.L  D3,D0    

PRINT_END:      UNLK    A6
                RTS


**********************************SUBRUTINA RTI**********************************

RTI:	   	LINK    A6,#-8          * Creacion del marco de pila y guardado de registros RTI
            MOVE.L  D0,-4(A6)
            MOVE.L  D1,-8(A6)

BUCLE_RTI:  MOVE.B  ISR,D1
            AND.B   IMRCP,D1

            BTST    #1,D1           * bit1 IMR y ISR -> Recepcion A
            BNE     REP_A

            BTST    #5,D1           * bit5 IMR y ISR -> Recepcion B
            BNE     REP_B

            BTST    #0,D1           * bit1 IMR y ISR -> Transmision A
            BNE     TR_A

            BTST    #4,D1           * bit1 IMR y ISR -> Transmision B
            BNE     TR_B
            BRA     FIN_RTI       	* Interrupcion no encontrada

REP_A:	    EOR.L   D0,D0
			MOVE.B 	RBA,D1
			
			BSR		ESCCAR
			CMP.L 	#-1,D0
			BEQ		FIN_RTI			* buffer lleno ->fin
			BRA		BUCLE_RTI
			
REP_B:	    MOVE.L 	#1,D0
			MOVE.B 	RBB,D1
			BSR		ESCCAR
			CMP.L 	#-1,D0
			BEQ		FIN_RTI			* buffer lleno -> fin
			BRA		BUCLE_RTI

TR_A:       MOVE.L  #2,D0           * Descriptor buffer transmision A 
            BSR     LEECAR
            CMP.L   #-1,D0          * Si buffer indicado vacio, reset IMR y salir de RTI
            BEQ     IN_A
            MOVE.B  D0,TBA          * Si caracter leido, escribir en linea de transmision A
            BRA    	BUCLE_RTI

IN_A:   	BCLR    #0,IMRCP      	* Inhibicion de transmision por A
            MOVE.B  IMRCP,IMR
            BRA     FIN_RTI

TR_B:       MOVE.L  #3,D0           * Descriptor buffer transmision B     
            BSR     LEECAR
            CMP.L   #-1,D0          * Si buffer indicado  vacio, reset IMR y salir de RTI
            BEQ     IN_B
            MOVE.B  D0,TBB          * Si caracter vacio, escribir en linea de transmision B
            BRA     BUCLE_RTI

IN_B:   	BCLR    #4,IMRCP      	* Inhibicion de transmision por B
            MOVE.B  IMRCP,IMR
			BRA     BUCLE_RTI

FIN_RTI: 	MOVE.L  -8(A6),D1
            MOVE.L  -4(A6),D0
            UNLK    A6
            RTE


IMRCP: 		DS.B 	1 	* Copia de IMR


*************************************PRUEBAS*************************************

INICIO:


INCLUDE bib_aux.s








