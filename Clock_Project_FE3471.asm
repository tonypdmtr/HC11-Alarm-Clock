; Benjamin T. Fenner, FE3471 (Wayne State University)
; This Program will simulate a simple clock with Hours(12) & Minutes(60) on 4 7-Segment Displays.
; Using pin PE7 to adjust time and alarm time.
; The user can change the alarm time by pressing PA0. If the user presses PA0 again The program will allow them to change the time.
; Each digit can be changed by using the Potentiometer. Once the desired digit is displayed press to advance to next digit.
; PM is the dot on the leftmost 7-Segment Display. Once PM/AM is selected the program will return you to regular clock.
; When the alarm time and clock time are equal the buzzer will activate. Press PA0 to turn alarm off. (Note changing time and..
; the alarm will not be active) Alarm automaticly turns off after 30 seconds.
; Version 06

; 12/14/2017

PD2                 equ       %00000100
PD3                 equ       %00001000
PD4                 equ       %00010000
PD5                 equ       %00100000
PORTDC              equ       $1009
PORTD               equ       $1008
PORTB               equ       $1004
TMSK1               equ       $1022
TFLG1               equ       $1023
TMSK2               equ       $1024
TFLG2               equ       $1025
PACTL               equ       $1026
TOC5                equ       $101E
TCNT                equ       $100E
Counter             equ       $000C
Alarm30             equ       $001D
TCTL1a              equ       $20
TCTL2               equ       $21
TFLG1a              equ       $23
ADCTL               equ       $30
ADR1                equ       $31
BASE                equ       $1000
TOC3                equ       $101A
Alarm1              equ       $001C
TCTL1               equ       $1020


                    org       $0000               ; List of Hex Values
                    fcb       $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F,$0A,$00,$00,$00  ; Hex values 0-9 for 7-Segment
                    org       $0010               ; Time is stored here.
                    fcb       $06,$06,$3F,$3F,$80,$06,$06,$3F,$06,$80,$77,$78,$00,$00,$00,$00  ; *Time, and then followed by alarm Time

                    org       $C000               ; Start Here
                    ldx       #$1000
                    lds       #$8FFF              ; Load Stack
                    ldaa      #%11000011          ; configure PD2-PD5 as output
                    staa      PORTD

; Turns on A/D conversions

                    ldaa      #%00100111          ; Turns on PE7
                    staa      ADCTL,x             ; this triggers the A/D

; Sets up PA0

                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TCTL2,x

; Output Compare

                    ldd       TCNT                ; Loads REG D as the current time
                    std       TOC5                ; Saves REG D into the time keep REG TOC5 so interrupt can happen
                    ldaa      #$29                ; Loads REG A as 0010 1000
                    staa      TFLG1               ; Clears Flag OC5F & IC3F
                    ldaa      #$08
                    staa      TMSK1               ; Sets the 0C5I to allow intrupts
                    bra       Back

BackClr             ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0. * PA0 Is reset to accpet a rising edge: PA0 1 in Bit 0
                    staa      TFLG1               ; Clear Flag at IC3F so a capture can be seen on a falling edge.

Back                cli                           ; Unmask IRQ Interrupts

                    ldaa      $10                 ; Load High Digit of Hour
                    staa      PORTB
                    ldaa      #PD5
                    staa      PORTDC              ; Turn on PD5 7-Display
                    jsr       Delay

                    ldaa      $11                 ; Load Low Digit of Hour
                    staa      PORTB
                    ldaa      #PD4
                    staa      PORTDC              ; Turn on PD4 7-Display
                    jsr       Delay

                    ldaa      $12                 ; Load High Digit of Minute
                    staa      PORTB
                    ldaa      #PD3
                    staa      PORTDC              ; Turn on PD3 7-Display
                    jsr       Delay

                    ldaa      $13                 ; Load Low Digit of Minute
                    staa      PORTB
                    ldaa      #PD2
                    staa      PORTDC              ; Turn on PD2 7-Display
                    jsr       Delay

                    ldaa      $14                 ; PM/AM
                    staa      PORTB
                    ldaa      #PD4
                    staa      PORTDC              ; Turn on PD5 7-Display
                    jsr       Delay


; Following code will check to see if the alarm is on. ie; the current time..
; equals alarm time and then will wait for the PAO to be pressed.


                    ldaa      Alarm1              ; Checks if on
                    cmpa      #$00
                    bne       AlarmOn
F2                  jsr       AlarmCheck
                    bra       Forward

AlarmOn             brclr     TFLG1a,x,1,Back     ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    ldaa      #$00                ; Reset so alarm is off. $01 on, $00 off.
                    staa      Alarm1
                    ldaa      #$00                ; Set OM3 and OL3 in TCTL1 to
                    staa      TCTL1               ; 01 so PA5 will toggle on each compare
BackC1              bra       BackClr


; Following code will allow user to change time or alarm with the potentiometer.


Forward             brclr     TFLG1a,x,1,Back     ; This will check if the flag on TMSK1 bit 0 is flaged to 1.


                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
                    pshy

                    ldy       #$001A              ; Set REG Y to Location for A in HEX
                    jsr       DisA1t1             ; Is a 5 second delay to give user time to press PA0 to...
; advance to Clock seting, Displays A1.

                    brclr     TFLG1a,x,1,JMPa     ; This will check if the flag on TMSK1 bit 0 is flaged to 1.

                    ldy       #$001B              ; Set REG Y to Location for A in HEX
                    jsr       DisA1t1             ; Is a 5 second delay Displays t1.

                    ldy       #$0010
                    jsr       timeSet             ; Will set time for the Clock
                    puly

                    jsr       Delay1
                    bra       BackC1              ; Resets the PA0 Flag

JMPa                ldaa      #$01                ; Clear TCTL2
                    staa      TFLG1a,x            ; Set Flag at IC3F
                    ldy       #$0015
                    jsr       timeSet             ; Will set time for the alarm
                    puly

                    jsr       Delay1
                    bra       BackC1              ; Resets the PA0 Flag

                    swi


; This sub-program will look where the Hex digit is located so that the program...
; can return the next increment of Hex Digit. if $06 it would change to $5B


                    org       $C150
Convert             ldx       #$0000              ; Load X as zero
zLoop1              ldab      ,x                  ; Load The Hex digits 1-9
                    inx                           ; Increase X by 1
                    cba                           ; Compare The Hex code in mem to REG A Hex Code
                    bne       zLoop1
                    rts


; Delay Sub for 5ms so the 7-Segment Display has time to shine


                    org       $C200
Delay               pshx
                    ldx       #1000               ; 1000 is N value for 3ms
dLoop               dex
                    bne       dLoop
                    pulx
                    rts

; 1 second Delay

Delay1              pshb
                    pshx
                    ldab      #6
oLoop               ldx       #65535
iLoop               dex
                    bne       iLoop
                    decb
                    bne       oLoop
                    pulx
                    pulb
                    rts

; Low Hour and Low Minute set with potentiometer


LH                  ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
                    ldx       #$1000
Loop2               ldab      ADR1,x
                    cmpb      #25
                    bls       Digit0
                    cmpb      #50
                    bls       Digit1
                    cmpb      #75
                    bls       Digit2
                    cmpb      #100
                    bls       Digit3
                    cmpb      #125
                    bls       Digit4
                    cmpb      #150
                    bls       Digit5
                    cmpb      #175
                    bls       Digit6
                    cmpb      #200
                    bls       Digit7
                    cmpb      #225
                    bls       Digit8
                    cmpb      #255
                    bls       Digit9
Digit0              ldaa      $00
                    bra       LMLoop

Digit1              ldaa      $01
                    bra       LMLoop

Digit2              ldaa      $02
                    bra       LMLoop

Digit3              ldaa      $03
                    bra       LMLoop

Digit4              ldaa      $04
                    bra       LMLoop

Digit5              ldaa      $05
                    bra       LMLoop

Digit6              ldaa      $06
                    bra       LMLoop

Digit7              ldaa      $07
                    bra       LMLoop

Digit8              ldaa      $08
                    bra       LMLoop

Digit9              ldaa      $09
LMLoop              staa      PORTB
                    brclr     TFLG1a,x,1,Loop2    ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts


; High Minute Potentiometer sub 0-5


HM                  ldaa      #PD3
                    staa      PORTDC              ; Turn on PD3 7-Display
                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
Loop22              ldab      ADR1,x
                    cmpb      #42
                    bls       D0
                    cmpb      #84
                    bls       D1
                    cmpb      #126
                    bls       D2
                    cmpb      #168
                    bls       D3
                    cmpb      #210
                    bls       D4
                    cmpb      #255
                    bls       D5
D0                  ldaa      $00
                    bra       HMLoop

D1                  ldaa      $01
                    bra       HMLoop

D2                  ldaa      $02
                    bra       HMLoop

D3                  ldaa      $03
                    bra       HMLoop

D4                  ldaa      $04
                    bra       HMLoop

D5                  ldaa      $05
HMLoop              staa      PORTB
                    brclr     TFLG1a,x,1,Loop22   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts


; Low Hour with High Hour being 1 Potentiometer sub 0-2


IfHH1               ldaa      #PD4
                    staa      PORTDC              ; Turn on PD4 7-Display
                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
Loop77              ldab      ADR1,x
                    cmpb      #85
                    bls       Dis0
                    cmpb      #170
                    bls       Dis1
                    cmpb      #255
                    bls       Dis2
Dis0                ldaa      $00
                    bra       LOOP17

Dis1                ldaa      $01
                    bra       LOOP17

Dis2                ldaa      $02
LOOP17              staa      PORTB
                    brclr     TFLG1a,x,1,Loop77   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts

; High Hour Set With Potentiometer


Hour                ldaa      #PD5
                    staa      PORTDC              ; Turn on PD5 7-Display
                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
Loop66              ldab      ADR1,x
                    cmpb      #125
                    bls       D00H
                    cmpb      #255
                    bls       D11H
D00H                ldaa      $00
                    bra       HHLoop1

D11H                ldaa      $01
HHLoop1             staa      PORTB
                    brclr     TFLG1a,x,1,Loop66   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts


; PM or AM Set with Potentiometer


AMPM                ldaa      #PD4
                    staa      PORTDC              ; Turn on PD5 7-Display
                    ldaa      #$01                ; Let TCTL2 to accept a rising edge on PA0.
                    staa      TFLG1a,x            ; Clear Flag at IC3F so a capture can be seen.
Loop19              ldab      ADR1,x
                    cmpb      #125
                    bls       AM1
                    cmpb      #255
                    bls       PM1
AM1                 ldaa      #$00
                    bra       AMLoop

PM1                 ldaa      #$80
AMLoop              staa      PORTB
                    brclr     TFLG1a,x,1,Loop19   ; This will check if the flag on TMSK1 bit 0 is flaged to 1.
                    rts


; Lets user set time or alarm.


timeSet             jsr       Delay               ; Set AM or PM
                    bsr       AMPM
                    staa      $04,y

                    jsr       Delay               ; Sets High Hour of Alarm
                    bsr       Hour
                    staa      $00,y

                    ldaa      $10
                    cmpa      #$06
                    bne       Not1

; IF HH is 1 code.
                    jsr       Delay
                    jsr       IfHH1               ; If the High hour is 1 this will only allow Low Hour to be 0,1, or 2.
                    staa      $01,y
                    bra       LMin                ; Moves to the next digit.

Not1                ldaa      #PD4                ; Sets Low hour of Alarm
                    staa      PORTDC              ; Turn on PD3 7-Display
                    jsr       Delay
                    jsr       LH
                    staa      $01,y

LMin                jsr       Delay               ; Sets High minute of Alarm
                    jsr       HM
                    staa      $02,y

                    ldaa      #PD2                ; Sets Low minute of Alarm
                    staa      PORTDC              ; Turn on PD5 7-Display
                    jsr       Delay
                    jsr       LH
                    staa      $03,y

                    jsr       Delay1              ; TFLG1 has a 0 in bit 0. So it will not accept a rising edge.

                    rts

; This will Display A1 or T1 so the user knows what is active for change.
; It is a 5 second delay.


DisA1t1             pshb
                    pshx
                    ldab      #120
oLoop5              ldx       #65535
iLoop5              dex

                    ldaa      $00,y               ; Load A in HEX
                    ldaa      #PD4
                    staa      PORTDC              ; Turn on PD4 7-Display
                    jsr       Delay

                    ldaa      #$06                ; Load 1 in HEX
                    staa      PORTB
                    ldaa      #PD3
                    staa      PORTDC              ; Turn on PD3 7-Display
                    jsr       Delay

                    bne       iLoop5
                    decb
                    bne       oLoop5
                    pulx
                    pulb
                    rts


; This sub will check to see if the current time equals alarm time.


AlarmCheck          ldaa      $10                 ; Load High Hour
                    cmpa      $15                 ; Compare to Alarm High Hour
                    bne       Back3
                    ldaa      $11                 ; Load Low Hour
                    cmpa      $16                 ; Compare to Alarm Low Hour
                    bne       Back3
                    ldaa      $12                 ; Load High Minute
                    cmpa      $17                 ; Compare to Alarm High Minute
                    bne       Back3
                    ldaa      $13                 ; Load Low Minute
                    cmpa      $18                 ; Compare to Alarm Low Minute
                    bne       Back3
                    ldaa      $14                 ; Load AMPM
                    cmpa      $19                 ; Compare to Alarm AMPM
                    bne       Back3
                    ldaa      #$01
                    staa      Alarm1              ; Stores 1 into Mem for a check if alarm on.
                    pshx
                    ldx       #$0000              ; Resets the Alarm30 to #$0000 for a 30second delay.
                    stx       Alarm30
                    ldx       Counter
                    cpx       #100
                    bhi       Loop100             ; Makes sure buzzer doesn't come back on after alarm is off, 1 min.
                    ldaa      #$20
                    staa      TFLG1
                    ldaa      #$10                ; Set OM3 and OL3 in TCTL1 to
                    staa      TCTL1               ; 01 so PA5 will toggle on each compare
Loop100             pulx
Back3               rts


; Keeping Time Interrupts


                    org       $00D9               ; Speaker Interrupt
                    jmp       $C500

                    org       $00D3               ; Clock Interrupt
                    jmp       $C550

; This Interrupt will allow the speaker to be heard.

                    org       $C500               ; Speaker interrupt
                    ldd       TOC3                ; TOC3 is connected to PA5
                    addd      #12000
                    std       TOC3
                    ldaa      #$20                ; Sets Flag
                    staa      TFLG1
                    rti

; This interrupt will Increment time 1 minute at a time.


                    org       $C550
                    ldaa      #$08                ; Loads REG A as 0000 1000
                    staa      TFLG1               ; Clears Flag OC5F
                    staa      TMSK1               ; Sets the 0C5I to allow intrupts
                    cli                           ; Unmask IRQ Interrupts

                    ldaa      Alarm1
                    cmpa      #$01                ; Checks if alarm is on.
                    bne       Aoff
                    ldx       Alarm30
                    inx
                    stx       Alarm30
                    cpx       #916                ; Check if 30 seconds have passed.
                    bne       Aoff
                    ldaa      #$00                ; Turns off alarm.
                    staa      Alarm1
                    ldx       #$0000              ; Resets alarm for future use.
                    stx       Alarm30

Aoff                ldx       Counter
                    inx
                    stx       Counter
                    cpx       #1830
                    bne       Temp1

                    ldd       TCNT
                    addd      #61800              ; 60/0.03277 = 1830.942935; .942935*.03277/.0005m = 61800
                    std       TOC5
                    bra       Branch2

Temp1               cpx       #1831
                    bne       Branch2
                    ldx       #$0000
                    stx       Counter

; now 1 minute has passed. We need to increase minutes by 1.

                    ldaa      $13                 ; Load Low Minute
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    ldaa      ,x                ; Load New Hex
                    staa      $13                 ; Changes A to next Hex value
                    cmpa      #$0A                ; compare is X = 0009
                    bne       Branch2             ; branch if !=0 Branch back

                    ldaa      $00                 ; Load A as zero
                    staa      $13                 ; Reset low minute to zero
                    ldaa      $12                 ; Load High Minute
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    ldaa      ,x                ; Load new Hex
                    staa      $12                 ; Changes A to next Hex value
                    cmpa      #$7D                ; If High Minute = 6
                    bne       Branch2             ; If !=0 branch back

; If 60 Minutes Increase hour By 1

                    ldaa      $00                 ; Load A as zero
                    staa      $12                 ; Reset High minute to zero
                    ldaa      $10                 ; Loading High bit to see if It's a 0,1
                    jsr       Convert
                    cmpa      #$06                ; Compare to 1
                    bne       Skip                ; Branch to bits 0-9 if less than 1
                    ldaa      $11                 ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    ldaa      ,x                ; Load New Hex
                    staa      $11                 ; Changes A to next Hex value

                    cmpa      #$5B                ; Seeing if AM/PM Changed
                    bne       Pass
                    ldaa      $14
                    cmpa      #$80                ; Check if it is PM or not
                    bne       Branch4
                    ldaa      #$00                ; Set to AM
                    staa      $14
                    bra       Branch2

Branch4             ldaa      #$80                ; Set to PM

Pass                cmpa      #$4F                ; If Low Hours = 3
                    bne       Branch2             ; If !=0 branch back
                    ldaa      $01                 ; Load A as 01:00
                    staa      $11                 ; Reset Low Hour to 01:00
                    ldaa      $00                 ; Seting High Hour to 0
                    staa      $10
                    bra       Branch2

; If High Hour <= 1

Skip                ldaa      $11                 ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    ldaa      ,x                ; Load New Hex
                    staa      $11                 ; Changes A to next Hex value
                    cmpa      #$0A                ; If Low Hours = 10
                    bne       Branch2             ; If !=0 branch back

; If High Hour > 1

Skip2               ldaa      $00                 ; Load A as zero
                    staa      $11                 ; Reset Low Hour to zero
                    ldaa      $10                 ; Load High Hour
                    jsr       Convert             ; Convert to a num from 7-Segment Hex
                    ldaa      ,x                ; Load New Hex
                    staa      $10                 ; Changes A to next Hex value
Branch2             rti
