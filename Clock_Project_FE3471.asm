;*******************************************************************************
; Benjamin T. Fenner, FE3471 (Wayne State University)
; This Program will simulate a simple clock with Hours(12) & Minutes(60) on 4
; 7-Segment Displays.
; Using pin PE7 to adjust time and alarm time.
; The user can change the alarm time by pressing PA0. If the user presses PA0
; again The program will allow them to change the time.
; Each digit can be changed by using the Potentiometer. Once the desired digit
; is displayed press to advance to next digit.
; PM is the dot on the leftmost 7-Segment Display. Once PM/AM is selected the
; program will return you to regular clock.
; When the alarm time and clock time are equal the buzzer will activate. Press
; PA0 to turn alarm off. (Note changing time and..
; the alarm will not be active) Alarm automaticly turns off after 30 seconds.
; Version 06
;*******************************************************************************

; 12/14/2017

PD2                 equ       %00000100
PD3                 equ       %00001000
PD4                 equ       %00010000
PD5                 equ       %00100000

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

;*******************************************************************************
                    #RAM      $0000               ; List of Hex values 0-9 for 7-Segment
;*******************************************************************************

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
                    fcb       $0A
                    fcb       0
counter             dw        0

;*******************************************************************************
                    #RAM      $0010               ; Time followed by alarm time
;*******************************************************************************

hour                dw        $0606
minute              dw        $3F3F
am_pm               fcb       $80
alarm_hour          dw        $0606
alarm_minute        dw        $3F06
alarm_am_pm         fcb       $80
                    dw        $7778
alarm1              fcb       0
alarm30             dw        0
                    fcb       0

;*******************************************************************************
                    #ROM      $C000               ; Start Here
;*******************************************************************************

Start               proc
                    ldx       #REGS
                    lds       #$8FFF              ; Load Stack
                    lda       #%11000011          ; configure PD2-PD5 as output
                    sta       PORTD
          ;-------------------------------------- ; Turns on A/D conversions
                    lda       #%00100111          ; Turns on PE7
                    sta       [ADCTL,x            ; this triggers the A/D
          ;-------------------------------------- ; Sets up PA0
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TCTL2,x
          ;-------------------------------------- ; Output Compare
                    ldd       TCNT                ; Loads REG D as the current time
                    std       TOC5                ; Saves REG D into the time keep REG TOC5 so interrupt can happen
                    lda       #$29                ; Loads REG A as 0010 1000
                    sta       TFLG1               ; Clears Flag OC5F & IC3F
                    lda       #$08
                    sta       TMSK1               ; Sets the 0C5I to allow intrupts
;                   bra       Back

;*******************************************************************************

Back                proc
                    cli                           ; Unmask IRQ Interrupts

                    lda       hour                ; Load High Digit of Hour
                    sta       PORTB
                    lda       #PD5
                    sta       PORTDC              ; Turn on PD5 7-Display
                    jsr       Delay

                    lda       hour+1              ; Load Low Digit of Hour
                    sta       PORTB
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-Display
                    bsr       Delay

                    lda       minute              ; Load High Digit of Minute
                    sta       PORTB
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-Display
                    bsr       Delay

                    lda       minute+1            ; Load Low Digit of Minute
                    sta       PORTB
                    lda       #PD2
                    sta       PORTDC              ; Turn on PD2 7-Display
                    bsr       Delay

                    lda       am_pm               ; PM/AM
                    sta       PORTB
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD5 7-Display
                    bsr       Delay
          ;--------------------------------------
          ; Following code will check to see if the alarm is on.
          ; i.e. the current time equals alarm time and then
          ; will wait for the PAO to be pressed.
          ;--------------------------------------
                    lda       alarm1              ; Checks if on
                    bne       AlarmOn
                    jsr       AlarmCheck
                    bra       Forward

;*******************************************************************************

AlarmOn             proc
                    brclr     [TFLG1,x,1,Back     ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    clra
                    sta       alarm1              ; Reset so alarm is off. $01 on, $00 off.
                                                  ; Set OM3 and OL3 in TCTL1 to
                    sta       TCTL1               ; 01 so PA5 will toggle on each compare
BackClr             lda       #$01                ; Let TCTL2 to accept a rising edge on PA0. * PA0 Is reset to accpet a rising edge: PA0 1 in Bit 0
                    sta       TFLG1               ; Clear Flag at IC3F so a capture can be seen on a falling edge.

;*******************************************************************************
; Following code will allow user to change time or alarm with the potentiometer.

Forward             proc
                    brclr     [TFLG1,x,1,Back     ; This will check if the flag on TMSK1 bit 0 is flaged to 1.

                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
                    pshy

                    ldy       #$1A                ; Set REG Y to location for A in HEX
                    jsr       DisA1t1             ; Is a 5 second delay to give user time to press PA0 to...
                                                  ; advance to Clock seting, Displays A1.
                    brclr     [TFLG1,x,1,_@@      ; This will check if the flag on TMSK1 bit 0 is flaged to 1.

                    ldy       #$1B                ; Set REG Y to location for A in HEX
                    jsr       DisA1t1             ; Is a 5 second delay Displays t1.

                    ldy       #$10
                    bra       Cont@@              ; Resets the PA0 Flag

_@@                 lda       #$01                ; Clear TCTL2
                    sta       [TFLG1,x            ; Set Flag at IC3F
                    ldy       #$15
Cont@@              jsr       timeSet             ; Will set time for the alarm
                    puly
                    bsr       Delay1
                    bra       Back@@              ; Resets the PA0 Flag

                    swi
Back@@              equ       BackClr

;*******************************************************************************
; This sub-program will look where the Hex digit is located so that the program...
; can return the next increment of Hex Digit. if $06 it would change to $5B

Convert             proc
                    clrx                          ; Load X as zero
Loop@@              ldb       ,x                  ; Load The Hex digits 1-9
                    inx                           ; Increase X by 1
                    cba                           ; Compare The Hex code in mem to REG A Hex Code
                    bne       Loop@@
                    rts

;*******************************************************************************
; Delay Sub for 5ms so the 7-Segment Display has time to shine

Delay               proc
                    pshx
                    ldx       #1000               ; 1000 is N value for 3ms
Loop@@              dex
                    bne       Loop@@
                    pulx
                    rts

;*******************************************************************************
; 1 second Delay

Delay1              proc
                    pshb
                    pshx
                    ldb       #6
Loop@@              ldx       #65535
_@@                 dex
                    bne       _@@
                    decb
                    bne       Loop@@
                    pulx
                    pulb
                    rts

;*******************************************************************************
; Low Hour and Low Minute set with potentiometer

LH                  proc
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
                    ldx       #REGS
Loop@@              ldb       [ADR1,x
                    cmpb      #25
                    bls       _0@@
                    cmpb      #50
                    bls       _1@@
                    cmpb      #75
                    bls       _2@@
                    cmpb      #100
                    bls       _3@@
                    cmpb      #125
                    bls       _4@@
                    cmpb      #150
                    bls       _5@@
                    cmpb      #175
                    bls       _6@@
                    cmpb      #200
                    bls       _7@@
                    cmpb      #225
                    bls       _8@@
                    cmpb      #255
                    bls       _9@@
_0@@                lda       #Digit0
                    bra       Cont@@

_1@@                lda       #Digit1
                    bra       Cont@@

_2@@                lda       #Digit2
                    bra       Cont@@

_3@@                lda       #Digit3
                    bra       Cont@@

_4@@                lda       #Digit4
                    bra       Cont@@

_5@@                lda       #Digit5
                    bra       Cont@@

_6@@                lda       #Digit6
                    bra       Cont@@

_7@@                lda       #Digit7
                    bra       Cont@@

_8@@                lda       #Digit8
                    bra       Cont@@

_9@@                lda       #Digit9
Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

;*******************************************************************************
; High Minute Potentiometer sub 0-5

HM                  proc
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-Display
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
Loop@@              ldb       [ADR1,x
                    cmpb      #42
                    bls       _0@@
                    cmpb      #84
                    bls       _1@@
                    cmpb      #126
                    bls       _2@@
                    cmpb      #168
                    bls       _3@@
                    cmpb      #210
                    bls       _4@@
                    cmpb      #255
                    bls       _5@@
_0@@                lda       #Digit0
                    bra       Cont@@

_1@@                lda       #Digit1
                    bra       Cont@@

_2@@                lda       #Digit2
                    bra       Cont@@

_3@@                lda       #Digit3
                    bra       Cont@@

_4@@                lda       #Digit4
                    bra       Cont@@

_5@@                lda       #Digit5
Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

;*******************************************************************************
; Low Hour with High Hour being 1 Potentiometer sub 0-2

IfHH1               proc
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-Display
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
Loop@@              ldb       [ADR1,x
                    cmpb      #85
                    bls       _0@@
                    cmpb      #170
                    bls       _1@@
                    cmpb      #255
                    bls       _2@@
_0@@                lda       #Digit0
                    bra       Cont@@

_1@@                lda       #Digit1
                    bra       Cont@@

_2@@                lda       #Digit2
Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

;*******************************************************************************
; High Hour Set With Potentiometer

Hour                proc
                    lda       #PD5
                    sta       PORTDC              ; Turn on PD5 7-Display
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
Loop@@              ldb       [ADR1,x
                    cmpb      #125
                    bls       _0@@
                    cmpb      #255
                    bls       _1@@
_0@@                lda       #Digit0
                    bra       Cont@@

_1@@                lda       #Digit1
Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

;*******************************************************************************
; PM or AM Set with Potentiometer

AMPM                proc
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD5 7-Display
                    lda       #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    sta       [TFLG1,x            ; Clear Flag at IC3F so a capture can be seen.
Loop@@              ldb       [ADR1,x
                    cmpb      #125
                    bls       Am@@
                    cmpb      #255
                    bls       Pm@@
Am@@                clra
                    bra       Cont@@

Pm@@                lda       #$80
Cont@@              sta       PORTB
                    brclr     [TFLG1,x,1,Loop@@   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

;*******************************************************************************
; Lets user set time or alarm.

timeSet             proc
                    jsr       Delay               ; Set AM or PM
                    bsr       AMPM
                    sta       4,y

                    jsr       Delay               ; Sets High Hour of Alarm
                    bsr       Hour
                    sta       ,y

                    lda       hour
                    cmpa      #$06
                    bne       _1@@
          ;-------------------------------------- ; IF HH is 1 code
                    jsr       Delay
                    jsr       IfHH1               ; If the High hour is 1 this will only allow Low Hour to be 0,1, or 2.
                    sta       1,y
                    bra       LMin@@              ; Moves to the next digit.

_1@@                lda       #PD4                ; Sets Low hour of Alarm
                    sta       PORTDC              ; Turn on PD3 7-Display
                    jsr       Delay
                    jsr       LH
                    sta       1,y

LMin@@              jsr       Delay               ; Sets High minute of Alarm
                    jsr       HM
                    sta       2,y

                    lda       #PD2                ; Sets Low minute of Alarm
                    sta       PORTDC              ; Turn on PD5 7-Display
                    jsr       Delay
                    jsr       LH
                    sta       3,y
                    jmp       Delay1              ; TFLG1 has a 0 in bit 0. So it will not accept a rising edge.

;*******************************************************************************
; This will Display A1 or T1 so the user knows what is active for change.
; It is a 5 second delay.

DisA1t1             proc
                    pshb
                    pshx
                    ldb       #120
Loop@@              ldx       #65535
_@@                 dex
                    lda       ,y                  ; Load A in HEX
                    lda       #PD4
                    sta       PORTDC              ; Turn on PD4 7-Display
                    jsr       Delay

                    lda       #Digit1             ; Load 1 in HEX
                    sta       PORTB
                    lda       #PD3
                    sta       PORTDC              ; Turn on PD3 7-Display
                    jsr       Delay

                    bne       _@@
                    decb
                    bne       Loop@@
                    pulx
                    pulb
                    rts

;*******************************************************************************
; This sub will check to see if the current time equals alarm time.

AlarmCheck          proc
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
                    sta       alarm1              ; Stores 1 into Mem for a check if alarm on.
                    pshx
                    clrx                          ; Resets the alarm30 to zero for a 30 second delay.
                    stx       alarm30
                    ldx       counter
                    cpx       #100
                    pulx
                    bhi       Done@@              ; Makes sure buzzer doesn't come back on after alarm is off, 1 min.
                    lda       #$20
                    sta       TFLG1
                    lda       #$10                ; Set OM3 and OL3 in TCTL1 to
                    sta       TCTL1               ; 01 so PA5 will toggle on each compare
Done@@              rts

;*******************************************************************************
; Speaker interrupt to allow the speaker to be heard

Speaker_Handler     proc
                    ldd       TOC3                ; TOC3 is connected to PA5
                    addd      #12000
                    std       TOC3
                    lda       #$20                ; Sets Flag
                    sta       TFLG1
                    rti

;*******************************************************************************
; Increment time 1 minute at a time

Clock_Handler       proc
                    lda       #$08                ; Loads REG A as 0000 1000
                    sta       TFLG1               ; Clears Flag OC5F
                    sta       TMSK1               ; Sets the 0C5I to allow intrupts
                    cli                           ; Unmask IRQ Interrupts

                    lda       alarm1
                    cmpa      #1                  ; Checks if alarm is on.
                    bne       _1@@
                    ldx       alarm30
                    inx
                    stx       alarm30
                    cpx       #916                ; Check if 30 seconds have passed.
                    bne       _1@@
                    clr       alarm1              ; Turns off alarm.
                    clrx                          ; Resets alarm for future use.
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
          ; now 1 minute has passed. We need to increase minutes by 1.
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
                    cmpa      #$7D                ; If High Minute = 6
                    bne       Done@@              ; If !=0 branch back
          ;-------------------------------------- ; If 60 Minutes Increase hour By 1
                    clr       minute              ; Reset High minute to zero
                    lda       hour                ; Loading High bit to see if It's a 0,1
                    jsr       Convert
                    cmpa      #$06                ; Compare to 1
                    bne       _4@@                ; Branch to bits 0-9 if less than 1
                    lda       hour+1              ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       hour+1              ; Changes A to next Hex value

                    cmpa      #$5B                ; Seeing if AM/PM Changed
                    bne       Pass@@
                    lda       am_pm
                    cmpa      #$80                ; Check if it is PM or not
                    bne       _3@@
                    clra                          ; Set to AM
                    sta       am_pm
                    bra       Done@@

_3@@                lda       #$80                ; Set to PM

Pass@@              cmpa      #$4F                ; If Low Hours = 3
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
