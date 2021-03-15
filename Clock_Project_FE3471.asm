;*******************************************************************************
; Benjamin T. Fenner, FE3471 (Wayne State University)
; This program simulates a simple clock with 12 hours & 60 minutes on four
; 7-segment displays
; Using pin PE7 to adjust time and alarm time
; The user can change the alarm time by pressing PA0. If the user presses PA0
; again the program will allow them to change the time
; Each digit can be changed by using the potentiometer. Once the desired digit
; is displayed press to advance to next digit
; PM is the dot on the leftmost 7-segment display. Once PM/AM is selected the
; program will return you to regular clock
; When the alarm and clock times are equal the buzzer will activate
; Press PA0 to turn alarm off
; (Note: While changing time the alarm will not be active.)
; The alarm automatically shuts off after 30 seconds
; Version 06
;*******************************************************************************

; 2017-12-14        Original
; 2021-03-14        Bug fixes, optimizations, and ASM11 compatibility by tonyp@acm.org

REGS                equ       $1000
PORTDC              equ       REGS+$09
PORTD               equ       REGS+$08
PORTB               equ       REGS+$04
TMSK1               equ       REGS+$22
TFLG1               equ       REGS+$23
TMSK2               equ       REGS+$24
TFLG2               equ       REGS+$25
PACTL               equ       REGS+$26
TOC5                equ       REGS+$1E
TCNT                equ       REGS+$0E
TCTL2               equ       REGS+$21
ADCTL               equ       REGS+$30
ADR1                equ       REGS+$31
TOC3                equ       REGS+$1A
TCTL1               equ       REGS+$20

RAM                 equ       $0000
ROM                 equ       $C000
STACKTOP            equ       $8FFF

BUS_HZ              equ       2000000             ;CPU bus speed in Hz
BUS_KHZ             equ       BUS_HZ/1000         ;CPU bus speed in KHz

PD2                 equ       %00000100
PD3                 equ       %00001000
PD4                 equ       %00010000
PD5                 equ       %00100000

Digit0              equ       $3F
Digit1              equ       $06
Digit2              equ       $5B
Digit3              equ       $4F
Digit4              equ       $66
Digit5              equ       $6D
Digit6              equ       $7D
Digit7              equ       $07
Digit8              equ       $7F
Digit9              equ       $6F
Dot                 equ       $80

;*******************************************************************************
                    #RAM      RAM
;*******************************************************************************

hour                rmb       2                   ;fcb Digit1,Digit1
minute              rmb       2                   ;fcb Digit0,Digit0
am_pm               rmb       1                   ;fcb Dot

alarm_hour          rmb       2                   ;fcb Digit1,Digit1
alarm_minute        rmb       2                   ;fcb Digit0,Digit1
alarm_am_pm         rmb       1                   ;fcb Dot

alarm1              rmb       1                   ;fcb 0
alarm30             rmb       2                   ;dw  0
counter             rmb       2                   ;dw  0

;*******************************************************************************
                    #ROM      ROM                 ; Start Here
;*******************************************************************************

InitVariables       proc
                    clr       counter
                    clr       counter+1
                    clr       alarm1
                    clr       alarm30
                    clr       alarm30+1

                    lda       #Digit1
                    sta       hour
                    sta       hour+1
                    sta       alarm_hour
                    sta       alarm_hour+1
                    sta       alarm_minute+1

                    lda       #Digit0
                    sta       minute
                    sta       minute+1
                    sta       alarm_minute

                    lda       #Dot
                    sta       am_pm
                    rts

MsgA1               fcb       $77
MsgT1               fcb       $78

;*******************************************************************************

Start               proc
                    ldx       #REGS
                    lds       #STACKTOP           ; Initialize stack
                    bsr       InitVariables
          ;-------------------------------------- ; configure PD2-PD5 as output
                    lda       #%11000011
                    sta       PORTD
          ;-------------------------------------- ; Turns on A/D conversions
                    lda       #%00100111          ; Turns on PE7
                    sta       [ADCTL,x            ; this triggers the A/D
          ;-------------------------------------- ; Sets up PA0
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TCTL2,x
          ;-------------------------------------- ; Output Compare
                    ldd       TCNT                ; Loads REG D as the current time
                    std       TOC5                ; Saves REG D into the time keep REG TOC5 so interrupt can happen
                    lda       #$29                ; Loads REG A as 0010 1001
                    sta       TFLG1               ; Clears flags OC3F, OC5F & IC3F
                    lda       #$08
                    sta       TMSK1               ; Sets the 0C5I to allow intrupts
                    cli                           ; Allow IRQ interrupts
;                   bra       Back

;*******************************************************************************

Back                proc
                    lda       hour                ; Load high digit of hour
                    sta       PORTB
                    lda       #PD5
                    sta       PORTDC              ; Turn on PD5 7-seg display
                    jsr       Delay

                    lda       hour+1              ; Load Low Digit of Hour
                    sta       PORTB
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-seg display
                    bsr       Delay

                    lda       minute              ; Load High Digit of Minute
                    sta       PORTB
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-seg display
                    bsr       Delay

                    lda       minute+1            ; Load Low Digit of Minute
                    sta       PORTB
                    lda       #PD2
                    sta       PORTDC              ; Turn on PD2 7-seg display
                    bsr       Delay

                    lda       am_pm               ; PM/AM
                    sta       PORTB
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD5 7-seg display
                    bsr       Delay
          ;--------------------------------------
          ; Check to see if the alarm is on, i.e. the current time equals
          ; alarm time and then wait for the PAO to be pressed
          ;--------------------------------------
                    lda       alarm1              ; Checks if on
                    bne       AlarmOn@@
                    jsr       CheckAlarm
                    bra       Forward

AlarmOn@@           brclr     [TFLG1,x,1,Back     ; Check if TMSK1[0] is 1
                    clr       alarm1              ; Reset so alarm is off. $01 on, $00 off
                    lda       #%00000001          ; Set OM3 and OL3 in TCTL1 to 01
                    sta       TCTL1               ; so PA5 will toggle on each compare
;                   bra       BackClr

;*******************************************************************************

BackClr             proc
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                                                  ; PA0 is reset to accept a rising edge: PA0 1 in Bit 0
                    sta       TFLG1               ; Clear IC3F flag so a capture can be seen on a falling edge
;                   bra       Forward

;*******************************************************************************
; Following code will allow user to change time or alarm with the potentiometer

Forward             proc
                    brclr     [TFLG1,x,1,Back     ; Check if TMSK1[0] is 1

                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen
          ;--------------------------------------
                    pshy
                    ldy       #MsgA1              ; Set REG Y to location for A in HEX
                    jsr       DispA1orT1          ; Is a 5 second delay to give user time to press PA0 to
                                                  ; advance to Clock setting displays A1
                    brclr     [TFLG1,x,1,_@@      ; Check if TMSK1[0] is 1

                    ldy       #MsgT1              ; Set REG Y to location for A in HEX
                    jsr       DispA1orT1          ; It's a 5 second delay displays t1

                    ldy       #hour
                    bra       Cont@@              ; Resets PA0 flag

_@@                 lda       #%00000001          ; Clear TCTL2
                    sta       [TFLG1,x            ; Set IC3F flag
                    ldy       #alarm_hour
Cont@@              jsr       SetAlarmTime        ; Will set time for the alarm
                    puly
          ;--------------------------------------
                    jsr       DelayOneSec
                    bra       Back@@              ; Resets PA0 flag

                    swi
Back@@              equ       BackClr

;*******************************************************************************
; This sub-program will look where the Hex digit is located so that the program
; can return the next increment of Hex Digit
; It would change $06 to $5B

Convert             proc
                    clrx                          ; Load X as zero
Loop@@              ldb       ,x                  ; Load the hex digits 1-9
                    inx                           ; Increase X by 1
                    cba                           ; Compare the hex code in mem to REG A hex code
                    bne       Loop@@
                    rts

;*******************************************************************************
; Delay for 5ms so the 7-seg display has time to shine
                              #Cycles
Delay               proc
                    pshx
                    ldx       #DELAY@@
                              #Cycles
Loop@@              dex
                    bne       Loop@@
                              #temp :cycles
                    pulx
                    rts

DELAY@@             equ       3*BUS_KHZ-:cycles-:ocycles/:temp
DELAY_CYCLES        equ       :temp

;*******************************************************************************
; Low hour and low minute set with potentiometer

SetLH               proc
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen
                    ldx       #REGS

Loop@@              ldb       [ADR1,x

                    lda       #Digit0
                    cmpb      #25
                    bls       Cont@@

                    lda       #Digit1
                    cmpb      #50
                    bls       Cont@@

                    lda       #Digit2
                    cmpb      #75
                    bls       Cont@@

                    lda       #Digit3
                    cmpb      #100
                    bls       Cont@@

                    lda       #Digit4
                    cmpb      #125
                    bls       Cont@@

                    lda       #Digit5
                    cmpb      #150
                    bls       Cont@@

                    lda       #Digit6
                    cmpb      #175
                    bls       Cont@@

                    lda       #Digit7
                    cmpb      #200
                    bls       Cont@@

                    lda       #Digit8
                    cmpb      #225
                    bls       Cont@@

                    lda       #Digit9

Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; High minute potentiometer sub 0-5

SetHM               proc
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #Digit0
                    cmpb      #42
                    bls       Cont@@

                    lda       #Digit1
                    cmpb      #84
                    bls       Cont@@

                    lda       #Digit2
                    cmpb      #126
                    bls       Cont@@

                    lda       #Digit3
                    cmpb      #168
                    bls       Cont@@

                    lda       #Digit4
                    cmpb      #210
                    bls       Cont@@

                    lda       #Digit5

Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; Low hour with high hour being 1 potentiometer sub 0-2

SetHH               proc
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #Digit0
                    cmpb      #85
                    bls       Cont@@

                    lda       #Digit1
                    cmpb      #170
                    bls       Cont@@

                    lda       #Digit2

Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; High hour set with potentiometer

SetHour             proc
                    lda       #PD5
                    sta       PORTDC              ; Turn on PD5 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #Digit0
                    cmpb      #125
                    bls       Cont@@

                    lda       #Digit1

Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; PM or AM set with potentiometer

SetAMorPM           proc
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD5 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    clra
                    cmpb      #125
                    bls       Cont@@

                    lda       #Dot

Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; Lets user set time or alarm

SetAlarmTime        proc
                    bsr       ?Delay              ; Set AM or PM
                    bsr       SetAMorPM
                    sta       4,y

                    bsr       ?Delay              ; Sets High Hour of Alarm
                    bsr       SetHour
                    sta       ,y

                    lda       hour
                    cmpa      #Digit1
                    bne       _1@@
          ;-------------------------------------- ; IF HH is 1 code
                    bsr       ?Delay
                    bsr       SetHH               ; If the High hour is 1 this will only allow Low Hour to be 0,1, or 2
                    sta       1,y
                    bra       LMin@@              ; Moves to the next digit

_1@@                lda       #PD4                ; Sets Low hour of Alarm
                    sta       PORTDC              ; Turn on PD3 7-seg display
                    bsr       ?Delay
                    jsr       SetLH
                    sta       1,y

LMin@@              bsr       ?Delay              ; Sets High minute of Alarm
                    jsr       SetHM
                    sta       2,y

                    lda       #PD2                ; Sets Low minute of Alarm
                    sta       PORTDC              ; Turn on PD5 7-seg display
                    bsr       ?Delay
                    jsr       SetLH
                    sta       3,y
;                   bra       DelayOneSec         ; TFLG1 has a 0 in bit 0. So it will not accept a rising edge

;*******************************************************************************
; One second Delay
                              #Cycles
DelayOneSec         proc
                    pshb
                    pshx
                    ldb       #DELAY@@
                              #Cycles
Loop@@              ldx       #BUS_KHZ
                              #temp :cycles
_@@                 dex
                    bne       _@@
                              #temp :cycles*BUS_KHZ+:temp
                    decb
                    bne       Loop@@
                              #temp :cycles+:temp
                    pulx
                    pulb
                    rts

DELAY@@             equ       BUS_HZ-:cycles-:ocycles/:temp

;*******************************************************************************
                              #Cycles
?Delay              jmp       Delay
DELAY_CYCLES        set       :cycles+DELAY_CYCLES

;*******************************************************************************
; Display A1 or T1 so the user knows what is active for change
; It is a 5 second delay
                              #Cycles
DispA1orT1          proc
                    pshb
                    pshx
                    ldb       #DELAY@@
                              #Cycles
Delay@@             ldx       #BUS_KHZ
                              #temp :cycles
Loop@@              lda       ,y                  ; Load A in HEX
                    sta       PORTB
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-seg display
                    bsr       ?Delay

                    lda       #Digit1             ; Load 1 in HEX
                    sta       PORTB
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-seg display
                    bsr       ?Delay

                    dex
                    bne       Loop@@
                              #temp DELAY_CYCLES*2+:cycles*BUS_KHZ+:temp
                    decb
                    bne       Delay@@
                              #temp :cycles+:temp
                    pulx
                    pulb
                    rts

DELAY@@             equ       5*BUS_HZ-:cycles-:ocycles/:temp

;*******************************************************************************
; Check to see if the current time equals alarm time

CheckAlarm          proc
                    lda       hour                ; Load High Hour
                    cmpa      alarm_hour          ; Compare to Alarm High Hour
                    bne       Done@@
                    lda       hour+1              ; Load Low Hour
                    cmpa      alarm_hour+1        ; Compare to Alarm Low Hour
                    bne       Done@@
                    lda       minute              ; Load High Minute
                    cmpa      alarm_minute        ; Compare to Alarm High Minute
                    bne       Done@@
                    lda       minute+1            ; Load Low Minute
                    cmpa      alarm_minute+1      ; Compare to Alarm Low Minute
                    bne       Done@@
                    lda       am_pm               ; Load AMPM
                    cmpa      alarm_am_pm         ; Compare to Alarm AMPM
                    bne       Done@@
                    lda       #1
                    sta       alarm1              ; Stores 1 into Mem for a check if alarm on
                    pshx
                    clrx                          ; Resets the alarm30 to zero for a 30 second delay
                    stx       alarm30
                    ldx       counter
                    cpx       #100
                    pulx
                    bhi       Done@@              ; Makes sure buzzer doesn't come back on after alarm is off, 1 min
                    lda       #$20
                    sta       TFLG1
                    lda       #%00000010          ; Set OM3 and OL3 in TCTL1 to
                    sta       TCTL1               ; 01 so PA5 will toggle on each compare
Done@@              rts

;*******************************************************************************
; Speaker interrupt to allow the speaker to be heard

Speaker_Handler     proc
                    ldd       TOC3                ; TOC3 is connected to PA5
                    addd      #12000
                    std       TOC3
                    lda       #$20                ; Sets flag
                    sta       TFLG1
                    rti

;*******************************************************************************
; Increment time 1 minute at a time

Clock_Handler       proc
                    lda       #$08                ; Loads REG A as 0000 1000
                    sta       TFLG1               ; Clears OC5F flag
                    sta       TMSK1               ; Sets the 0C5I to allow intrupts
                    cli                           ; Unmask IRQ Interrupts

                    lda       alarm1
                    cmpa      #1                  ; Checks if alarm is on
                    bne       _1@@
                    ldx       alarm30
                    inx
                    stx       alarm30
                    cpx       #916                ; Check if 30 seconds have passed
                    bne       _1@@
                    clr       alarm1              ; Turns off alarm
                    clrx                          ; Resets alarm for future use
                    stx       alarm30

_1@@                ldx       counter
                    inx
                    stx       counter
                    cpx       #1830
                    bne       _2@@

                    ldd       TCNT
                    addd      #61800              ; 60/0.03277 = 1830.942935; .942935*.03277/.0005m = 61800
                    std       TOC5
                    bra       Done@@

_2@@                cpx       #1831
                    bne       Done@@
                    clrx
                    stx       counter
          ;--------------------------------------
          ; now 1 minute has passed. We need to increase minutes by 1
          ;--------------------------------------
                    lda       minute+1            ; Load Low Minute
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       minute+1            ; Changes A to next Hex value
                    cmpa      #10                 ; compare is X = 0009
                    bne       Done@@              ; branch if !=0 Branch back

                    clr       minute+1            ; Reset low minute to zero
                    lda       minute              ; Load High Minute
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load new Hex
                    sta       minute              ; Changes A to next Hex value
                    cmpa      #Digit6             ; If High Minute = 6
                    bne       Done@@              ; If !=0 branch back
          ;-------------------------------------- ; If 60 Minutes Increase hour By 1
                    clr       minute              ; Reset High minute to zero
                    lda       hour                ; Loading High bit to see if It's a 0,1
                    jsr       Convert
                    cmpa      #Digit1             ; Compare to 1
                    bne       _4@@                ; Branch to bits 0-9 if less than 1
                    lda       hour+1              ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       hour+1              ; Changes A to next Hex value

                    cmpa      #Digit2             ; Seeing if AM/PM Changed
                    bne       Pass@@
                    lda       am_pm
                    cmpa      #Dot                ; Check if it is PM or not
                    bne       _3@@
                    clr       am_pm               ; Set to AM
                    bra       Done@@

_3@@                lda       #Dot                ; Set to PM

Pass@@              cmpa      #Digit3             ; If Low Hours = 3
                    bne       Done@@              ; If !=0 branch back
                    lda       #1                  ; Load A as 01:00
                    sta       hour+1              ; Reset Low Hour to 01:00
                    clr       hour                ; Seting High Hour to 0
                    bra       Done@@
          ;-------------------------------------- ; If High Hour <= 1
_4@@                lda       hour+1              ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       hour+1              ; Changes A to next Hex value
                    cmpa      #10                 ; If Low Hours = 10
                    bne       Done@@              ; If !=0 branch back
          ;-------------------------------------- ; If High Hour > 1
                    clr       hour+1              ; Reset Low Hour to zero
                    lda       hour                ; Load High Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       hour                ; Changes A to next Hex value
Done@@              rti

;*******************************************************************************
; Keeping Time Interrupts
;*******************************************************************************

                    #VECTORS  $00D9               ; Speaker Interrupt
                    jmp       Speaker_Handler

                    #VECTORS  $00D3               ; Clock Interrupt
                    jmp       Clock_Handler
