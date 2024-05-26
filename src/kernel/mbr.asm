;mbr
[BITS 16]
[ORG 0x7C00]

_start:
    MOV SP, 0x7000
    XOR AX, AX
    MOV SS, AX
    MOV ES, AX
    MOV DS, AX

    PUSHA
    MOV	AX, CS              ; 置其他段寄存器值与CS相同
    MOV	DS, AX              ; 数据段
    MOV	BP, LOAD_MSG        ; BP=当前串的偏移地址
    MOV	AX, DS              ; ES:BP = 串地址
    MOV	ES, AX              ; 置ES=DS
    MOV	CX, LOAD_MSG_LEN    ; CX = 串长
    MOV	AX, 0x1301          ; AH = 13h（功能号）、AL = 01h（光标置于串尾）
    MOV	BX, 0x0007          ; 页号为0(BH = 0) 黑底白字(BL = 07h)
    MOV DH, 0               ; 行号=0
    MOV	DL, 0               ; 列号=0
    int	0x10                ; BIOS的10h功能：显示一行字符
    POPA

LOAD_OS_KERNEL:                            ; 加载操作系统内核
    PUSHA
    MOV AX,CS                              ; 段地址
    MOV ES,AX                              ; 设置段地址
    MOV BX, 0x8000                         ; 偏移地址
    MOV AH,2                               ; 功能号
    MOV AL,2                               ; 扇区数
    MOV DL,0x80                            ; 驱动器号
    MOV DH,0                               ; 磁头号
    MOV CH,0                               ; 柱面号
    MOV CL,2                               ; 起始扇区号
    INT 0x13
    POPA

LOAD_PROGRAMME:                            ; 加载C程序
    PUSHA
    MOV AX,CS                              ; 段地址
    MOV ES,AX                              ; 设置段地址
    MOV BX, 0x9000                         ; 偏移地址
    MOV AH,2                               ; 功能号
    MOV AL,26                              ; 扇区数
    MOV DL,0x80                            ; 驱动器号
    MOV DH,0                               ; 磁头号
    MOV CH,0                               ; 柱面号
    MOV CL,4                               ; 起始扇区号
    INT 0x13
    POPA

ENTER_OS:
    PUSHF
    PUSH CS
    PUSH 0x8000
    IRET                                   ; 跳转到操作系统内核执行

AFTER:
    JMP $                                  ; 无限循环

LOAD_MSG DB 'Bootloader is loading operating system.'
LOAD_MSG_LEN EQU ($-LOAD_MSG)

TIMES 510-($-$$) DB 0
DW 0xAA55