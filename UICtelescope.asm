; reverse-engineering of the PIC-cotroller HEX-code
; with detailed explanation of used procedures
; prepared for the UIC radio telescope project

    processor 12F675
    #include <P12F675.INC>
    __config 0x3FC4
;   _CPD_OFF & _CP_OFF & _BODEN_ON & _MCLRE_OFF & _PWRTE_ON & _WDT_OFF 
;   & _INTRC_OSC_NOCLKOUT 

; RAM-Variable
LRAM_0x20 equ 0x20
LRAM_0x21 equ 0x21
LRAM_0x22 equ 0x22
LRAM_0x23 equ 0x23
LRAM_0x25 equ 0x25
LRAM_0x26 equ 0x26
LRAM_0x27 equ 0x27
LRAM_0x28 equ 0x28
LRAM_0x29 equ 0x29
LRAM_0x2A equ 0x2A
LRAM_0x2B equ 0x2B

; Program

    Org 0x0000

;   Reset-Vector
    NOP
    GOTO LADR_0x0005

    Org 0x0004

;   Interrupt-Vector
    RETURN
LADR_0x0005
    BSF STATUS,RP0       ; select memory bank 1
    MOVWF OSCCAL         ; calibrate oscillator by the factory stored value
    MOVLW 0x03
    MOVWF TRISIO         ; TRISIO = 000011 (GPIO0-GPIO1 set to input)
    MOVLW 0x13
    MOVWF ANSEL          ; ANSEL = 0010011 (Fosc/8 for A/D conversion, AN0-AN1 set to analog input)
    BSF OPTION_REG,7     ; GPIO pull-ups are disabled
    BCF STATUS,RP0       ; select memory bank 0
    CLRF INTCON	         ; disable all interrupts
    CLRF GPIO            ; all GPIO = 0
    MOVLW 0x81
    MOVWF ADCON0         ; ADCON0 = 10000001 (A/D converter is operating on AN0, not in progress,
                         ; Vdd voltage reference, A/D result right justified - ADFM=1)
    CLRF CMCON           ; clear comparator control register (see PIC12F675 manual, p. 37)
LADR_0x0012
    CLRF LRAM_0x22       ; clear 0x21-0x23 range of memory
    CLRF LRAM_0x21
    CLRF LRAM_0x23
    BSF ADCON0,1         ; start A/D conversion cycle 
LADR_0x0016
    BTFSC ADCON0,1       ; if A/D conversion is in progress, jump to LADR_0x0016
    GOTO LADR_0x0016     ; (basically, wait until the conversion cycle is complete)

                         ; storing the 10-bit result of A/D conversion: 
    BCF STATUS,C         ; clear carry flag
    RRF ADRESH,F         ; rotate 1-bit to right of the upper byte of result through carry flag
    MOVF ADRESH,W        ; move ADRESH to W
    MOVWF LRAM_0x21      ; store W in 0x21
    BSF STATUS,RP0       ; select memory bank 1
    RRF ADRESL,F         ; rotate 1-bit to right of the lower byte of result through carry flag
    MOVF ADRESL,W        ; move ADRESL to W
    MOVWF LRAM_0x22      ; store W in 0x22
                         ; => Result of ADC divided by 2 is stored in memory cells 0x21-0x22

    BCF STATUS,RP0       ; select memory bank 0
    BTFSS LRAM_0x21,0    ; if LRAM_0x21 ends on 0, jump to LADR_0x0027
    GOTO LADR_0x0027
    MOVF LRAM_0x22,W     ; move LRAM_0x22 to W 
    MOVWF LRAM_0x21      ; move W to LRAM_0x21
    BSF LRAM_0x20,0      ; set 0 bit LRAM_0x20 to 1
    GOTO LADR_0x0028     ; jump to LADR_0x0028
LADR_0x0027
    BCF LRAM_0x20,0      ; set 0 bit LRAM_0x20 to 0
                         ; => if result of the A/D conversion /2 is larger than one byte, then
                         ; copy it to the left by one byte.
LADR_0x0028
    CALL LADR_0x002A     ; call the subroutine LADR_0x002A
    GOTO LADR_0x0012     ; jump back to the beginning of the A/D conversion cycle
LADR_0x002A
    BCF GPIO,5           ; set GPIO bit 5 to 0
    BSF GPIO,2           ; set GPIO bit 2 to 1 (start communication with DS1867)
    BTFSC LRAM_0x20,0    ; if LRAM_0x20 ends on 1, then
    BSF GPIO,5           ; set GPIO bit 5 to 1 (i.e. GP5 becomes the last bit in 0x20)
                         ; tell DS1867 to read the bit:
    BSF GPIO,4           ; set GPIO bit 4 to 1
    BCF GPIO,4           ; set GPIO bit 4 to 0
    
    MOVLW 0x09           ; W = 1001
    MOVWF LRAM_0x25      ; LRAM_0x25 = 1001
LADR_0x0032
    DECFSZ LRAM_0x25,F   ; decrease LRAM_0x25 by 1
    GOTO LADR_0x0035     ; if the result is not 0, then jump to LADR_0x0035
    GOTO LADR_0x003D     ; otherwise jump to LADR_0x003D
LADR_0x0035
    BCF STATUS,C         ; clear carry flag
    RLF LRAM_0x21,F      ; rotate LRAM_0x21 to the left by 1 byte through carry flag
    BCF GPIO,5           ; set GPIO bit 5 to 0
    BTFSC STATUS,C       ; if carry flag = 1, then
    BSF GPIO,5           ; set GPIO bit 5 to 1 (i.e. GP5 = left bit of 0x21)
                         ; tell DS1867 to read the bit:
    BSF GPIO,4           ; set GPIO bit 4 to 1
    BCF GPIO,4           ; set GPIO bit 4 to 0
    
    GOTO LADR_0x0032     ; jump to LADR_0x0032
LADR_0x003D
    MOVLW 0x09           ; W = 1001
    MOVWF LRAM_0x25      ; LRAM_0x25 = 1001
LADR_0x003F
    DECFSZ LRAM_0x25,F   ; decrease LRAM_0x25 by 1
    GOTO LADR_0x0043     ; if the result is not 0, then jump to LADR_0x0043
    BCF GPIO,2           ; set GPIO bit 2 to 0 (end communication with DS1867)
    RETURN               ; end of the subroutine
LADR_0x0043
    BCF STATUS,C         ; clear carry flag
    RLF LRAM_0x22,F      ; rotate LRAM_0x22 to the left by 1 byte through carry flag
    BCF GPIO,5           ; set GPIO bit 5 to 0
    BTFSC STATUS,C       ; if carry flag = 1, then
    BSF GPIO,5           ; set GPIO bit 5 to 1 (i.e. GP5 = left bit of 0x22)
                         ; tell DS1867 to read the bit:
    BSF GPIO,4           ; set GPIO bit 4 to 1
    BCF GPIO,4           ; set GPIO bit 4 to 0
    
    GOTO LADR_0x003F     ; jump to LADR_0x003F
    MOVLW 0x80           ; W = 10000000
    MOVWF LRAM_0x26      ; LRAM_0x26 = 10000000
LADR_0x004D
    MOVLW 0xFF           ; W = 11111111
    MOVWF LRAM_0x27      ; LRAM_0x27 = 11111111
LADR_0x004F
    DECFSZ LRAM_0x27,F   ; decrease LRAM_0x27 by 1
    GOTO LADR_0x004F     ; if the result is not 0, then jump to LADR_0x004F
    DECFSZ LRAM_0x26,F   ; decrease LRAM_0x26 by 1
    GOTO LADR_0x004D     ; if the result is not 0, then jump to LADR_0x004D
    RETURN               ; end of subroutine
    MOVF LRAM_0x28,W     ; move LRAM_0x28 to W
    SUBWF LRAM_0x2A,F    ; subtract W from LRAM_0x2A and place to LRAM_0x2A
    MOVF LRAM_0x29,W     ; move LRAM_0x28 to W
    SUBWF LRAM_0x2B,F    ; subtract W from LRAM_0x2B and place to LRAM_0x2B
    RETURN               ; end of subroutine
    MOVLW 0x01           ; set 0x28-0x2B to 00000000 00000001 11100101 00000001
    MOVWF LRAM_0x29       
    MOVLW 0x00           
    MOVWF LRAM_0x28
    MOVLW 0x01
    MOVWF LRAM_0x2B
    MOVLW 0xE5
    MOVWF LRAM_0x2A
    RETURN               ; end of subroutine

    End                  ; EOF
