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
PORTB               equ       REGS+$04,1          ;Port B Data
PORTD               equ       REGS+$08,1          ;Port D Data
DDRD                equ       REGS+$09,1          ;Data Direction Register D
TCNT                equ       REGS+$0E,2          ;Timer Count
TOC3                equ       REGS+$1A,2          ;Timer Output Compare 3
TOC5                equ       REGS+$1E,2          ;Timer Output Compare 5
TCTL1               equ       REGS+$20,1          ;Timer Control 1
TCTL2               equ       REGS+$21,1          ;Timer Control 2
TFLG1               equ       REGS+$23,1          ;Timer Interrupt Flag 1
TMSK1               equ       REGS+$22,1          ;Timer Interrupt Mask 1
ADCTL               equ       REGS+$30,1          ;A/D Control Status Register
ADR1                equ       REGS+$31,1          ;A/D Result 1

RAM                 def       $0000
ROM                 def       $C000
STACKTOP            def       $8FFF

BUS_HZ              def       2000000             ;CPU bus speed in Hz
BUS_KHZ             equ       BUS_HZ/1000         ;CPU bus speed in KHz

LED_DATA            equ       PORTB
LED_CTRL            equ       PORTD
LED_DDRD            equ       DDRD

PD2                 equ       %00000100
PD3                 equ       %00001000
PD4                 equ       %00010000
PD5                 equ       %00100000

DIGIT0              equ       $3F
DIGIT1              equ       $06
DIGIT2              equ       $5B
DIGIT3              equ       $4F
DIGIT4              equ       $66
DIGIT5              equ       $6D
DIGIT6              equ       $7D
DIGIT7              equ       $07
DIGIT8              equ       $7F
DIGIT9              equ       $6F
Dot                 equ       $80

;*******************************************************************************
                    #RAM      RAM
;*******************************************************************************

hour                rmb       2                   ;fcb DIGIT1,DIGIT1
minute              rmb       2                   ;fcb DIGIT0,DIGIT0
am_pm               rmb       1                   ;fcb Dot

alarm_hour          rmb       2                   ;fcb DIGIT1,DIGIT1
alarm_minute        rmb       2                   ;fcb DIGIT0,DIGIT1
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

                    lda       #DIGIT1
                    sta       hour
                    sta       hour+1
                    sta       alarm_hour
                    sta       alarm_hour+1
                    sta       alarm_minute+1

                    lda       #DIGIT0
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
                    lds       #STACKTOP           ; Initialize stack
                    ldx       #REGS
                    bsr       InitVariables
          ;-------------------------------------- ; configure PD2-PD5 as output
                    lda       #%11000011
                    sta       LED_DDRD
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
                    sta       TMSK1               ; sets the 0C5I to allow interrupts
                    cli                           ; allow IRQ interrupts
;                   bra       Back

;*******************************************************************************

Back                proc
                    lda       hour                ; load high digit of hour
                    sta       LED_DATA
                    lda       #PD5
                    sta       LED_CTRL            ; Turn on PD5 7-seg display
                    jsr       Delay

                    lda       hour+1              ; load low digit of hour
                    sta       LED_DATA
                    lda       #PD4
                    sta       LED_CTRL            ; Turn on PD4 7-seg display
                    bsr       Delay

                    lda       minute              ; Load High Digit of Minute
                    sta       LED_DATA
                    lda       #PD3
                    sta       LED_CTRL            ; Turn on PD3 7-seg display
                    bsr       Delay

                    lda       minute+1            ; Load Low Digit of Minute
                    sta       LED_DATA
                    lda       #PD2
                    sta       LED_CTRL            ; Turn on PD2 7-seg display
                    bsr       Delay

                    lda       am_pm               ; PM/AM
                    sta       LED_DATA
                    lda       #PD4
                    sta       LED_CTRL            ; Turn on PD5 7-seg display
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

                    lda       #DIGIT0
                    cmpb      #25
                    bls       Cont@@

                    lda       #DIGIT1
                    cmpb      #50
                    bls       Cont@@

                    lda       #DIGIT2
                    cmpb      #75
                    bls       Cont@@

                    lda       #DIGIT3
                    cmpb      #100
                    bls       Cont@@

                    lda       #DIGIT4
                    cmpb      #125
                    bls       Cont@@

                    lda       #DIGIT5
                    cmpb      #150
                    bls       Cont@@

                    lda       #DIGIT6
                    cmpb      #175
                    bls       Cont@@

                    lda       #DIGIT7
                    cmpb      #200
                    bls       Cont@@

                    lda       #DIGIT8
                    cmpb      #225
                    bls       Cont@@

                    lda       #DIGIT9

Cont@@              sta       LED_DATA
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; High minute potentiometer sub 0-5

SetHM               proc
                    lda       #PD3
                    sta       LED_CTRL            ; Turn on PD3 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #DIGIT0
                    cmpb      #42
                    bls       Cont@@

                    lda       #DIGIT1
                    cmpb      #84
                    bls       Cont@@

                    lda       #DIGIT2
                    cmpb      #126
                    bls       Cont@@

                    lda       #DIGIT3
                    cmpb      #168
                    bls       Cont@@

                    lda       #DIGIT4
                    cmpb      #210
                    bls       Cont@@

                    lda       #DIGIT5

Cont@@              sta       LED_DATA
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; Low hour with high hour being 1 potentiometer sub 0-2

SetHH               proc
                    lda       #PD4
                    sta       LED_CTRL            ; Turn on PD4 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #DIGIT0
                    cmpb      #85
                    bls       Cont@@

                    lda       #DIGIT1
                    cmpb      #170
                    bls       Cont@@

                    lda       #DIGIT2

Cont@@              sta       LED_DATA
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; High hour set with potentiometer

SetHour             proc
                    lda       #PD5
                    sta       LED_CTRL            ; Turn on PD5 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    lda       #DIGIT0
                    cmpb      #125
                    bls       Cont@@

                    lda       #DIGIT1

Cont@@              sta       LED_DATA
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; PM or AM set with potentiometer

SetAMorPM           proc
                    lda       #PD4
                    sta       LED_CTRL            ; Turn on PD5 7-seg display
                    lda       #%00000001          ; Let TCTL2 accept a rising edge on PA0
                    sta       [TFLG1,x            ; Clear IC3F flag so a capture can be seen

Loop@@              ldb       [ADR1,x

                    clra
                    cmpb      #125
                    bls       Cont@@

                    lda       #Dot

Cont@@              sta       LED_DATA
                    brclr     [TFLG1,x,1,Loop@@   ; Check if TMSK1[0] is 1
                    rts

;*******************************************************************************
; Lets user set time or alarm

SetAlarmTime        proc
                    bsr       ?Delay              ; set AM or PM
                    bsr       SetAMorPM
                    sta       4,y

                    bsr       ?Delay              ; sets high hour of alarm
                    bsr       SetHour
                    sta       ,y

                    lda       hour
                    cmpa      #DIGIT1
                    bne       _1@@
          ;-------------------------------------- ; if HH is 1 code
                    bsr       ?Delay
                    bsr       SetHH               ; if the high hour is 1 this will only allow low hour to be 0,1, or 2
                    sta       1,y
                    bra       LMin@@              ; moves to the next digit

_1@@                lda       #PD4                ; sets low hour of alarm
                    sta       LED_CTRL            ; turn on PD3 7-seg display
                    bsr       ?Delay
                    jsr       SetLH
                    sta       1,y

LMin@@              bsr       ?Delay              ; sets high minute of alarm
                    jsr       SetHM
                    sta       2,y

                    lda       #PD2                ; sets low minute of alarm
                    sta       LED_CTRL            ; turn on PD5 7-seg display
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
                    sta       LED_DATA
                    lda       #PD4
                    sta       LED_CTRL            ; Turn on PD4 7-seg display
                    bsr       ?Delay

                    lda       #DIGIT1             ; Load 1 in HEX
                    sta       LED_DATA
                    lda       #PD3
                    sta       LED_CTRL            ; Turn on PD3 7-seg display
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
                    cmpa      alarm_minute        ; compare to alarm high minute
                    bne       Done@@

                    lda       minute+1            ; load low minute
                    cmpa      alarm_minute+1      ; compare to alarm low minute
                    bne       Done@@

                    lda       am_pm               ; load AMPM
                    cmpa      alarm_am_pm         ; compare to alarm AMPM
                    bne       Done@@

                    lda       #1
                    sta       alarm1              ; stores 1 into Mem for a check if alarm on

                    pshx
                    clrx                          ; resets the alarm30 to zero for a 30 second delay
                    stx       alarm30
                    ldx       counter
                    cpx       #100
                    pulx
                    bhi       Done@@              ; makes sure buzzer doesn't come back on after alarm is off, 1 min

                    lda       #$20
                    sta       TFLG1

                    lda       #%00000010          ; set OM3 and OL3 in TCTL1 to
                    sta       TCTL1               ; 01 so PA5 will toggle on each compare
Done@@              rts

;*******************************************************************************
; Speaker interrupt to allow the speaker to be heard

Speaker_Handler     proc
                    ldd       TOC3                ; TOC3 is connected to PA5
                    addd      #12000
                    std       TOC3
                    lda       #$20                ; sets flag
                    sta       TFLG1
                    rti

;*******************************************************************************
; Increment time 1 minute at a time

Clock_Handler       proc
                    lda       #$08                ; Loads REG A as 0000 1000
                    sta       TFLG1               ; Clears OC5F flag
                    sta       TMSK1               ; sets the 0C5I to allow interrupts
                    cli                           ; allow IRQ interrupts

                    lda       alarm1
                    cmpa      #1                  ; checks if alarm is on
                    bne       _1@@

                    ldx       alarm30
                    inx
                    stx       alarm30
                    cpx       #916                ; Check if 30 seconds have passed
                    bne       _1@@

                    clr       alarm1              ; turns off alarm
                    clrx                          ; resets alarm for future use
                    stx       alarm30

_1@@                ldx       counter
                    inx
                    stx       counter
                    cpx       #1830
                    bne       _2@@
          ;--------------------------------------
          ; 60/0.03277 = 1830.942935
          ; .942935*.03277/.0005m = 61800
          ;--------------------------------------
                    ldd       TCNT
                    addd      #61800
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
                    jsr       Convert             ; Convert to a num from 7-segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       minute+1            ; Changes A to next Hex value
                    cmpa      #10                 ; compare is X = 0009
                    bne       Done@@              ; branch if !=0 Branch back

                    clr       minute+1            ; Reset low minute to zero
                    lda       minute              ; Load High Minute
                    jsr       Convert             ; Convert to a num from 7-segment Hex
                    lda       ,x                  ; Load new Hex
                    sta       minute              ; Changes A to next Hex value
                    cmpa      #DIGIT6             ; If High Minute = 6
                    bne       Done@@              ; If !=0 branch back
          ;-------------------------------------- ; If 60 Minutes Increase hour By 1
                    clr       minute              ; Reset High minute to zero
                    lda       hour                ; Loading High bit to see if It's a 0,1
                    jsr       Convert
                    cmpa      #DIGIT1             ; Compare to 1
                    bne       _4@@                ; Branch to bits 0-9 if less than 1
                    lda       hour+1              ; Load low Hour
                    jsr       Convert             ; Convert to a num from 7-segment Hex
                    lda       ,x                  ; Load New Hex
                    sta       hour+1              ; Changes A to next Hex value

                    cmpa      #DIGIT2             ; Seeing if AM/PM Changed
                    bne       Pass@@
                    lda       am_pm
                    cmpa      #Dot                ; Check if it is PM or not
                    bne       _3@@
                    clr       am_pm               ; set to AM
                    bra       Done@@

_3@@                lda       #Dot                ; set to PM

Pass@@              cmpa      #DIGIT3             ; if low hours = 3
                    bne       Done@@              ; if !=0 branch back
                    lda       #1                  ; load A as 01:00
                    sta       hour+1              ; reset low hour to 01:00
                    clr       hour                ; Set high hour to 0
                    bra       Done@@
          ;-------------------------------------- ; if high hour <= 1
_4@@                lda       hour+1              ; load low hour
                    jsr       Convert             ; convert to a num from 7-segment hex
                    lda       ,x                  ; load new hex
                    sta       hour+1              ; changes A to next hex value
                    cmpa      #10                 ; if low hours = 10
                    bne       Done@@              ; if !=0 branch back
          ;-------------------------------------- ; if high hour > 1
                    clr       hour+1              ; reset low hour to zero
                    lda       hour                ; load high hour
                    jsr       Convert             ; convert to a num from 7-segment hex
                    lda       ,x                  ; load new hex
                    sta       hour                ; changes A to next hex value
Done@@              rti

;*******************************************************************************
; Keeping Time Interrupts
;*******************************************************************************

                    #VECTORS  $00D3               ; clock interrupt
                    jmp       Clock_Handler

                    #VECTORS  $00D9               ; speaker interrupt
                    jmp       Speaker_Handler
