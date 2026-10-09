segment code
..start:
        ; Initializing segments
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     AX, SS
        MOV     SP, stacktop

        ; Graceful exit
        MOV     AX, 4C00h
        INT     21h

segment data

segment stack stack
        resb    256
stacktop:
