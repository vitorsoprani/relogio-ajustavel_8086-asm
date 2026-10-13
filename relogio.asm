segment code
..start:
        ; Initializing segments
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     SS, AX
        MOV     SP, stacktop

        CLI                             ; disable interruptions
        ; Saving DOS original isr
        XOR     AX, AX                  ; AX = 0
        MOV     ES, AX                  ; interruptions vector is at 0000h
        MOV     AX, [ES:clk_int*4]      ; saves original ip
        MOV     [clk_isr_ip], AX
        MOV     AX, [ES:clk_int*4+2]    ; saves original cs
        MOV     [clk_isr_cs], AX

        ; Setting our own isr for clk interuption
        MOV     WORD [ES:clk_int*4], clk_isr    ; sets the ip to our routine
        MOV     [ES:clk_int*4+2], cs            ; sets our cs
        STI     ; enable interruptions

        main_loop:
                MOV     AH, 0Bh
                INT     21h
                CMP     AL, 0
                JNE     quit_program

                XOR     AX, AX
                MOV     AL, [hours]
                PUSH    AX
                MOV     AX, string
                PUSH    AX
                CALL    int2ascii

                XOR     AX, AX
                MOV     AL, [minutes]
                PUSH    AX
                MOV     AX, string+3
                PUSH    AX
                CALL    int2ascii

                XOR     AX, AX
                MOV     AL, [seconds]
                PUSH    AX
                MOV     AX, string+6
                PUSH    AX
                CALL    int2ascii

                MOV     DX, string
                MOV     AH, 09h
                INT     21h
        JMP main_loop

        quit_program:
        ; Graceful exit
        ; Reseting the isr to DOS original
        CLI
        XOR     AX, AX
        MOV     ES, AX                  ; ES = 0
        MOV     AX, [clk_isr_ip]        ; Restore original ip
        MOV     [ES:clk_int*4], AX
        MOV     AX, [clk_isr_cs]        ; Restore original CS
        MOV     [ES:clk_int*4+2], AX
        STI
        ; Exiting
        MOV     AX, 4C00h
        INT     21h


; Function that converts an integer into an decimal (ascii coded string)
; RESTRICTIONS:
;       The number must be a 2 digit decimal
; USAGE:
;       ; Args passed by stack
;       PUSH    integer         ; Integer to be converted
;       PUSH    string          ; Pointer to where the string will be stored
;       CALL    int2ascii
int2ascii:
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    BX
        PUSH    CX

        MOV     BX, [BP+4]      ; Retreive string pointer
        MOV     AX, [BP+6]      ; Retreive integer
        MOV     CL, 10

        DIV     CL
        ADD     AH, 30h         ; Convert reminder to ascii
        ADD     AL, 30h
        MOV     [BX+1], AH
        MOV     [BX], AL

        ; Retreive context
        POP     CX
        POP     BX
        POP     AX
        POPF
        POP     BP
        RET     4
        


; Custom Interruption Service Routine defined for clock (18hz) interruptions
clk_isr:
        ; Save context
        PUSH    AX

        INC     byte [ticks]
        CMP     byte [ticks], 18        ; 18hz clock, 18 clicks == 1s
        JB      quit_isr                ; Quit isr if ticks < 18
        MOV     byte [ticks], 0         ; Clear ticks counter if ticks >= 18

        INC     byte [seconds]          ; ticks == 18 -> 1s elapsed
        CMP     byte [seconds], 60
        JB      quit_isr
        MOV     byte [seconds], 0

        INC     byte [minutes]
        CMP     byte [minutes], 60
        JB      quit_isr
        MOV     byte [minutes],  0

        INC     byte [hours]
        CMP     byte [hours], 24
        JB      quit_isr
        MOV     byte [hours], 0

        ; "Freeing" the interruption pin
        quit_isr:
        MOV     AL, 20h                 ; End of interruption
        OUT     20h, AL                 ; Sends EOI to the pic
        ; Retreive context
        POP     AX
        IRET

segment data
        clk_int         EQU     08h     ; clk interruption number
        clk_isr_ip      DW      0       ; Original DOS isr ip
        clk_isr_cs      DW      0       ; Original DOS isr cs
        ticks           DB      0       ; Clk interruptions counter
        seconds         DB      0
        minutes         DB      0
        hours           DB      0
        string          DB      "00:00:00", 13, '$'


segment stack stack
        resb    256
stacktop:
