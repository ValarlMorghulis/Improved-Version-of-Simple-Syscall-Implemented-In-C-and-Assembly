; C库函数
[BITS 16]

section .text
[global write]
[global sleep]
[global fork]
write:
    MOV AX,1
    INT 0x80
    RET

sleep:
    MOV AX,2
    INT 0x80
    RET

fork:
    MOV AX,3
    INT 0x80
    RET
