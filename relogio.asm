segment code
..start:
        ; Initializing segments
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     SS, AX
        MOV     SP, stacktop

        CLI                             ; disable interruptions
        ; Saving DOS original ISRs
        XOR     AX, AX                  ; AX = 0
        MOV     ES, AX                  ; interruptions vector is at 0000h

        ; Backup INT 8 (timer)
        MOV     AX, [ES:clk_int*4]
        MOV     [clk_isr_ip], AX
        MOV     AX, [ES:clk_int*4+2]
        MOV     [clk_isr_cs], AX

        ; Backup INT 9 (keyboard)
        MOV     AX, [ES:key_int*4]
        MOV     [key_isr_ip], AX
        MOV     AX, [ES:key_int*4+2]
        MOV     [key_isr_cs], AX

        ; Setting our own ISRs for clk and keyboard interuptions
        MOV     WORD [ES:clk_int*4], clk_isr    ; sets the ip to our routine
        MOV     [ES:clk_int*4+2], cs            ; sets our cs
        MOV     WORD [ES:key_int*4], key_isr
        MOV     [ES:key_int*4+2], CS
        STI                                     ; enable interruptions

        MOV     AH, 09h
        MOV     DX, usage_msg
        INT     21h

        main_loop:
                ; Keyboard Producer-Consumer Buffer Logic
                MOV     AX, [p_i]
                CMP     AX, [p_t]
                JNE     read_key        ; If p_i != p_t, a new key was pressed
                JMP     display_time    ; If p_i == p_t, no new key was pressed

                ; Reads the key from the circular buffer
                read_key:
                MOV     BX, [p_t]
                INC     word [p_t]
                AND     word [p_t], 7
                XOR     AX, AX
                MOV     AL, [BX+key]

                ; Ignores Break codes (when key is released), processes only Make codes
                CMP     AL, 81h         ; ESC Break code
                JNE     check_break
                JMP     quit_program

                check_break:
                TEST    AL, 80h
                JNZ     display_time    ; If bit 7 is 1, it is a Break code (ignore)

                ; Key processing (Make codes)
                CMP     AL, 01h         ; ESC
                JNE     process_commands
                JMP     quit_program

                process_commands:
                CMP     AL, 20h         ; 'd' -> 12-hour format
                JE      set_12h
                CMP     AL, 2Fh         ; 'v' -> 24-hour format
                JE      set_24h
                CMP     AL, 23h         ; 'h' -> Adjust Hours
                JE      inc_hours
                CMP     AL, 32h         ; 'm' -> Adjust Minutes
                JE      inc_minutes
                CMP     AL, 1Fh         ; 's' -> Adjust Seconds
                JE      inc_seconds
                JMP     display_time

                ; --- Key Handling ---
                set_12h:
                MOV     byte [mode_12h], 1
                JMP     display_time

                set_24h:
                MOV     byte [mode_12h], 0
                JMP     display_time

                inc_hours:
                INC     byte [hours]
                CMP     byte [hours], 24
                JB      display_time
                MOV     byte [hours], 0
                JMP     display_time

                inc_minutes:
                INC     byte [minutes]
                CMP     byte [minutes], 60
                JB      display_time
                MOV     byte [minutes], 0
                JMP     display_time

                inc_seconds:
                INC     byte [seconds]
                CMP     byte [seconds], 60
                JB      display_time
                MOV     byte [seconds], 0
                JMP     display_time

                ; --- Formatting and Display Logic ---
                display_time:
                XOR     AX, AX
                MOV     AL, [hours]

                CMP     byte [mode_12h], 1
                JNE     format_24h

                ; --- 12-hour format logic ---
                CMP     AL, 12
                JAE     is_pm

                ; It is AM
                MOV     byte [string+9], 'a'
                MOV     byte [string+10], 'm'
                JMP     adjust_12h_hour
                is_pm:
                ; It is PM
                MOV     byte [string+9], 'p'
                MOV     byte [string+10], 'm'
                adjust_12h_hour:
                CMP     AL, 12
                JE      skip_sub_12             ; 12 PM remains 12
                CMP     AL, 0
                JE      set_12_midnight         ; 0 hours is 12 AM
                CMP     AL, 12
                JB      skip_sub_12             ; Less than 12, do not subtract
                SUB     AL, 12                  ; 13+ becomes 1, 2, etc.
                JMP     skip_sub_12
                set_12_midnight:
                MOV     AL, 12
                skip_sub_12:
                JMP     do_print_hours

                ; --- 24-hour format logic ---
                format_24h:
                MOV     byte [string+9], ' '    ; Clears 'a'/'p'
                MOV     byte [string+10], ' '   ; Clears 'm'

                do_print_hours:
                ; AL register already has the correct hour to be displayed
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

                ; Writes the time using DOS routine
                MOV     DX, string
                MOV     AH, 09h
                INT     21h

        JMP     main_loop

        quit_program:
        ; Graceful exit
        ; Reseting the isr to DOS original
        CLI
        XOR     AX, AX
        MOV     ES, AX                  ; ES = 0

        ; Restore INT 8
        MOV     AX, [clk_isr_ip]        ; Restore original ip
        MOV     [ES:clk_int*4], AX
        MOV     AX, [clk_isr_cs]        ; Restore original CS
        MOV     [ES:clk_int*4+2], AX

        ; Restore INT 9
        MOV     AX, [key_isr_ip]
        MOV     [ES:key_int*4], AX
        MOV     AX, [key_isr_cs]
        MOV     [ES:key_int*4+2], AX

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
        MOV     byte [minutes], 0

        INC     byte [hours]
        CMP     byte [hours], 24
        JB      quit_isr
        MOV     byte [hours], 0

        ; "Freeing" the interruption pin
        quit_isr:
        MOV     AL, eoi                 ; End of interruption
        OUT     pic_ctrl, AL            ; Sends EOI to the pic
        ; Retreive context
        POP     AX
        IRET

key_isr:
        PUSH    AX
        PUSH    BX
        PUSH    DS

        IN      AL, kb_data             ; Reads port 60h
        INC     word [p_i]              ; Increments keyboard buffer ptr
        AND     word [p_i], 7           ; Keep buffer size (8 bytes)
        MOV     BX, [p_i]
        MOV     [BX+key], AL            ; Saves key code on the buffer

        IN      AL, kb_ctrl             ; Reads keyboard control
        OR      AL, 80h                 ; Sets the clear bit on the keyboard
        OUT     kb_ctrl, AL
        AND     AL, 7Fh                 ; Reset the clear bit
        OUT     kb_ctrl, AL             ; "frees" the keyboard

        MOV     AL, eoi                 ; Loads 20h
        OUT     pic_ctrl, AL            ; sends EOI to the PIC

        POP     DS
        POP     BX
        POP     AX
        IRET

segment data
        clk_int         EQU     08h     ; Clk interruption number
        key_int         EQU     09h     ; Keyboard interruption number
        kb_data         EQU     60h     ; Data port from 8255
        kb_ctrl         EQU     61h     ; Control port from 8255
        pic_ctrl        EQU     20h     ; PIC control port
        eoi             EQU     20h     ; End of interruption code

        ; Timer variables
        clk_isr_ip      DW      0       ; Original DOS isr ip
        clk_isr_cs      DW      0       ; Original DOS isr cs
        ticks           DB      0       ; Clk interruptions counter
        seconds         DB      0
        minutes         DB      0
        hours           DB      0

        ; Keyboard and display variables
        key_isr_ip      DW      0
        key_isr_cs      DW      0
        p_i             DW      0
        p_t             DW      0
        mode_12h        DB      0

        ; Keyboard buffer
        key     TIMES 8 DB 0

        ; Text buffer
        string          DB      "00:00:00   ", 13, '$'
        usage_msg       DB      "USAGE:", 10, 13, 9, "-Press d for 12h format;", 10, 13, 9, "-Press v for 24h format;", 10, 13, 9, "-Press h, m or s to setup hours, minutes or seconds respectively;", 10, 10, 13, '$'



segment stack stack
        resb    256
stacktop:
