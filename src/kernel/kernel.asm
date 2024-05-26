;kernel
[BITS 16]
[ORG 0x8000]

_start:
    ;PCB初始化
    MOV BYTE [PCB_0+PCB.STATE], 2
    MOV WORD [PCB_0+PCB.SP], 0x7000
    MOV BYTE [PCB_1+PCB.ID], 1
    MOV WORD [PCB_1+PCB.SP], 0x6000
    MOV BYTE [PCB_2+PCB.ID], 2
    MOV WORD [PCB_2+PCB.SP], 0x5000
    MOV BYTE [PCB_3+PCB.ID], 3
    MOV WORD [PCB_3+PCB.SP], 0x4000
    MOV BYTE [PCB_4+PCB.ID], 4
    MOV WORD [PCB_4+PCB.SP], 0x3000

    MOV AX, 0x0003
    INT 0x10                               ; 清屏

    CALL SET_INTERRUPT                     ; 设置中断向量表
    CALL SET_TIMER                         ; 设置定时器

    ; 模仿硬件中断，先将后续执行代码的CS:IP以及标志寄存器（PSW）的值保存到栈上
    PUSHF
    PUSH CS
    PUSH KERNEL_LOOP
    PUSHA
    PUSH DS
    PUSH ES

    MOV WORD [CURRENT_PROCESS],PCB_0
    MOV WORD [NEXT_PROCESS],PCB_1
    MOV BYTE [PCB_0+PCB.PRIORITY],1
    MOV BYTE [PCB_1+PCB.PRIORITY],5

    CALL SAVE_PCB                         ; 保存当前进程的PCB
    CALL LOAD_PCB                         ; 加载下一个进程的PCB

    PUSHF
    PUSH CS
    PUSH 0x9000
    IRET                                  ; 跳转到C程序执行

KERNEL_LOOP:
    JMP KERNEL_LOOP                        ; 无限循环
    
SET_INTERRUPT:
    MOV AX, 0        
    MOV ES, AX
    MOV WORD [ES:4*0x08], CLOCK_INTERRUPT  ; 将时钟中断处理例程写入中断向量表
    MOV WORD [ES:4*0x08+2], CS
    MOV WORD [ES:4*0x80], INTERUPT_HANDLER ; 将INT 0x80中断处理例程写入中断向量表
    MOV WORD [ES:4*0x80+2], CS
    RET

SET_TIMER:                                 ; 设置8253/4定时器芯片
    MOV AL, 0x36 
    OUT 0x43, AL
    MOV AX, 0x5D37                         ; 每隔20ms产生一次时钟中断
    OUT 0x40, AL
    MOV AL, AH
    OUT 0x40, AL
    RET

FIND_PRIORITY_PROCESS:                      ; 寻找优先级最高的进程
    MOV SI, PCB_0
    MOV CL, 0
    MOV BX, 0
    FIND_PRIORITY:                          ; 遍历寻找优先级最高的进程
        CMP BYTE [SI+PCB.STATE],1           ; 进程处于准备状态
        JNE FIND_SKIP
        CMP BYTE [SI+PCB.PRIORITY],CL
        JL FIND_SKIP
        MOV WORD [NEXT_PROCESS],SI
        MOV BYTE CL,[SI+PCB.PRIORITY]
        FIND_SKIP:
        ADD SI, PCB_SIZE
        INC BX
        CMP BX,5
        JL FIND_PRIORITY
    RET

SAVE_PCB:
    POP WORD [SAVED_IP]                      ; 保存当前函数返回值IP
    ; 保存当前PCB
    MOV WORD SI,[CURRENT_PROCESS]
    POP WORD [SI+PCB.ES]
    POP WORD [SI+PCB.DS]
    POP WORD [SI+PCB.DI]
    POP WORD [SI+PCB.SI]
    POP WORD [SI+PCB.BP]
    POP WORD [SI+PCB.SP]
    POP WORD [SI+PCB.BX]
    POP WORD [SI+PCB.DX]
    POP WORD [SI+PCB.CX]
    POP WORD [SI+PCB.AX]
    POP WORD [SI+PCB.IP]                     ; 从栈顶获取当前进程IRET的IP
    POP WORD [SI+PCB.CS]                     ; 从栈顶获取当前进程IRET的CS
    POP WORD [SI+PCB.FLAGS]                  ; 从栈顶获取当前进程IRET的标志寄存器
    MOV WORD [SI+PCB.SP],SP
    MOV WORD [SI+PCB.SS],SS

    CMP BYTE [SI+PCB.STATE],2                ; 判断进程是否处于运行状态
    JNE SAVE_SKIP
    MOV BYTE [SI+PCB.STATE],1                ; 设置当前进程状态为准备
    SAVE_SKIP:
    PUSH WORD [SAVED_IP]                     ; 恢复函数返回值IP
    RET

LOAD_PCB:
    POP WORD [SAVED_IP]                      ; 保存当前函数返回值IP
    ; 加载下一个PCB
    MOV WORD SI,[NEXT_PROCESS]
    MOV WORD SP,[SI+PCB.SP]
    MOV WORD SS,[SI+PCB.SS]
    PUSH WORD [SI+PCB.FLAGS]
    PUSH WORD [SI+PCB.CS]
    PUSH WORD [SI+PCB.IP]
    PUSH WORD [SI+PCB.AX]
    PUSH WORD [SI+PCB.CX]
    PUSH WORD [SI+PCB.DX]
    PUSH WORD [SI+PCB.BX]
    PUSH WORD [SI+PCB.SP]
    PUSH WORD [SI+PCB.BP]
    PUSH WORD [SI+PCB.SI]
    PUSH WORD [SI+PCB.DI]
    PUSH WORD [SI+PCB.DS]
    PUSH WORD [SI+PCB.ES]

    MOV BYTE [SI+PCB.STATE],2                ; 设置下一个进程状态为运行
    MOV WORD [CURRENT_PROCESS],SI            ; 设置当前进程为下一个进程
    PUSH WORD [SAVED_IP]                     ; 恢复函数返回值IP
    RET

CLOCK_INTERRUPT:                           ; 时钟中断处理例程
    PUSHA
    PUSH DS
    PUSH ES
    CALL SAVE_PCB                          ; 保存当前进程的PCB
    DECREASE_TIMER:                        ; 减少睡眠进程的计数器
        MOV SI, PCB_0
        MOV BX, 0
        DECREASE_LOOP:                     ; 遍历减少睡眠进程的计数器
            CMP BYTE [SI+PCB.STATE],3      ; 进程处于睡眠状态
            JNE DECREACE_SKIP
            DEC WORD [SI+PCB.TIMER]
            CMP WORD [SI+PCB.TIMER],0      ; 计数器为0则转为准备状态
            JNE DECREACE_SKIP
            MOV BYTE [SI+PCB.STATE],1
            DECREACE_SKIP:
            ADD SI, PCB_SIZE
            INC BX
            CMP BX,5
            JL DECREASE_LOOP
    CALL FIND_PRIORITY_PROCESS             ; 寻找优先级最高的进程
    CALL LOAD_PCB                          ; 加载下一个进程的PCB
    MOV AL, 0x20
    OUT 0x20, AL                           ; 发送EOI命令给8259A中断控制器
    JMP INTERUPT_END

INTERUPT_HANDLER:                          ; INT 0x80中断处理
    PUSHA
    PUSH DS
    PUSH ES
    ; 恢复段寄存器
    MOV CX, CS
    MOV DS, CX
    MOV ES, CX

    CMP AX,1
    JE KERNEL_WRITE
    CMP AX,2
    JE KERNEL_SLEEP
    CMP AX,3
    JE KERNEL_FORK
INTERUPT_END:
    POP ES
    POP DS
    POPA
    IRET

KERNEL_WRITE:                              ; 内核输出字符串
    MOV SI, SP
    ADD SI, 30                             ; SI指向字符串地址
    MOV	AX, CS                             ; 置其他段寄存器值与CS相同
    MOV	DS, AX                             ; 数据段
    MOV	BP, [SI]                           ; BP=当前字符串的偏移地址
    MOV	AX, DS                             ; ES:BP = 串地址
    MOV	ES, AX                             ; ES=DS
    MOV	CX, [SI+4]                         ; CX = 字符串长度
    MOV	AX, 0x1301
    MOV	BX, 0x0007
    MOV DH,[LINE]
    MOV DL, 0x00
    INT 0x10

    MOV AL, 0x0A                           ; 换行符的ASCII码
    MOV AH, 0x0E
    INT 0x10

    INC BYTE [LINE]
    MOV AH, 0x02                           ; 功能号2表示设置光标位置
    MOV BH, 0x00                           ; 页号
    MOV DH,[LINE]
    MOV DL, 0x00                           ; 列号（0表示最左侧）
    INT 0x10

    JMP INTERUPT_END

KERNEL_SLEEP:                             ; 进程休眠
    CALL SAVE_PCB                         ; 保存当前进程的PCB
    MOV SI, SP
    ADD SI, 4                             ; SI指向休眠时间
    MOV AX, [SI]
    MOV CX, 50                            ; 将乘数50加载到CX中
    MUL CX                                ; 乘法运算
    MOV SI,[CURRENT_PROCESS]
    MOV WORD [SI+PCB.TIMER], AX           ; 设置计数器
    MOV BYTE [SI+PCB.STATE], 3            ; 设置进程状态为睡眠
    CALL FIND_PRIORITY_PROCESS
    CALL LOAD_PCB                         ; 加载下一个进程的PCB
    
    JMP INTERUPT_END

KERNEL_FORK:                                   ; 创建子进程
    CALL SAVE_PCB                              ; 保存当前进程的PCB
    CREATE_PROCESS:                            ; 寻找空闲进程控制块
        MOV SI, PCB_0
        MOV BX, 0
        FIND_VACANT_PROCESS:                   ; 遍历寻找空闲进程控制块
            CMP BYTE [SI+PCB.STATE],0          ; 进程处于终止状态
            JE CREATE_END
            ADD SI, PCB_SIZE
            INC BX
            CMP BX,5
            JL FIND_VACANT_PROCESS
        CREATE_END:
        MOV BYTE [SI+PCB.STATE],1              ; 设置进程状态为准备
        MOV WORD [NEXT_PROCESS],SI

    COPY_PROCESS:                              ; 复制父进程的PCB
        MOV WORD SI,[CURRENT_PROCESS]
        MOV WORD DI,[NEXT_PROCESS]
        MOV BYTE AL,[SI+PCB.ID]                ; 获取父进程的ID
        MOV BYTE [DI+PCB.PARENT],AL            ; 设置子进程的父进程ID=父进程ID
        XOR AX,AX
        MOV BYTE AL,[DI+PCB.ID]                ; 获取子进程ID
        MOV WORD [SI+PCB.AX],AX                ; 父进程ax返回值=子进程ID
        MOV BYTE AL,[SI+PCB.PRIORITY]          ; 获取父进程的优先级
        DEC AL
        MOV BYTE [DI+PCB.PRIORITY],AL          ; 设置子进程的优先级=父进程优先级-1
        MOV WORD AX,[SI+PCB.BX]                ; 复制父进程的BX
        MOV WORD [DI+PCB.BX],AX                ; 设置子进程的BX
        MOV WORD AX,[SI+PCB.CX]                ; 复制父进程的CX
        MOV WORD [DI+PCB.CX],AX                ; 设置子进程的CX
        MOV WORD AX,[SI+PCB.DX]                ; 复制父进程的DX
        MOV WORD [DI+PCB.DX],AX                ; 设置子进程的DX
        MOV WORD AX,[SI+PCB.DI]                ; 复制父进程的DI
        MOV WORD [DI+PCB.DI],AX                ; 设置子进程的DI
        MOV WORD AX,[SI+PCB.SI]                ; 复制父进程的SI
        MOV WORD [DI+PCB.SI],AX                ; 设置子进程的SI
        MOV WORD AX,[SI+PCB.BP]                ; 复制父进程的BP
        MOV WORD [DI+PCB.BP],AX                ; 设置子进程的BP
        MOV WORD AX,[SI+PCB.IP]                ; 复制父进程的IP
        MOV WORD [DI+PCB.IP],AX                ; 设置子进程的IP
        MOV WORD AX,[SI+PCB.FLAGS]             ; 复制父进程的FLAGS
        MOV WORD [DI+PCB.FLAGS],AX             ; 设置子进程的FLAGS

        ; 复制父进程的堆栈段
        POP WORD [SAVED_IP]                    ; 获取API函数返回值IP
        MOV WORD SP,[DI+PCB.SP]                ; 切换至子进程的SP
        PUSH WORD [SAVED_IP]                   ; 恢复API函数返回值IP
        MOV WORD [DI+PCB.SP],SP
        MOV WORD SP,[SI+PCB.SP]
        PUSH WORD [SAVED_IP]
        ; 复制父进程的代码段、数据段、附加段
        PUSHA
        MOV WORD AX, [SI+PCB.DS]
        MOV CX, AX
        ADD CX, 0x1000
        MOV WORD [DI+PCB.DS], CX               ; 设置子进程的DS=父进程DS+0x1000
        PUSH DS
        PUSH ES
        MOV DS, AX
        MOV SI, 0x9000
        MOV ES, CX
        MOV DI, 0x9000
        MOV CX, 0x3100                         ; 复制0x3000字节
        REP MOVSB                              ; 将DS:SI复制到ES:DI
        POP ES
        POP DS
        MOV WORD AX, [SI+PCB.CS]
        ADD AX, 0x1000
        MOV WORD [DI+PCB.CS], CX               ; 设置子进程的CS=父进程CS+0x1000
        MOV WORD AX, [SI+PCB.ES]
        ADD AX, 0x1000
        MOV WORD [DI+PCB.ES], CX               ; 设置子进程的ES=父进程ES+0x1000
        POPA

    CALL FIND_PRIORITY_PROCESS                 ; 寻找优先级最高的进程
    CALL LOAD_PCB                              ; 加载下一个进程的PCB
    
    JMP INTERUPT_END

LINE DB 0                                  ; 存储当前输出的行数
SAVED_IP DD 0

STRUC PCB
    .ID         RESB 1      ; 进程ID
    .STATE      RESB 1      ; 进程状态(0:终止, 1:准备, 2:运行, 3:睡眠)
    .PRIORITY   RESB 1      ; 进程优先级
    .CS         RESW 1      ; CS代码段寄存器
    .IP         RESW 1      ; IP指令指针
    .FLAGS      RESW 1      ; 标志寄存器
    .AX         RESW 1      ; 通用寄存器AX
    .BX         RESW 1      ; 通用寄存器BX
    .CX         RESW 1      ; 通用寄存器CX
    .DX         RESW 1      ; 通用寄存器DX
    .DI         RESW 1      ; 通用寄存器DI
    .SI         RESW 1      ; 通用寄存器SI
    .BP         RESW 1      ; 通用寄存器BP
    .SS         RESW 1      ; 堆栈段寄存器
    .SP         RESW 1      ; 堆栈指针
    .DS         RESW 1      ; 数据段寄存器
    .ES         RESW 1      ; 附加段寄存器
    .TIMER      RESW 1      ; 时钟中断计数器
    .PARENT     RESB 1      ; 父进程ID
ENDSTRUC
PCB_SIZE EQU 34

CURRENT_PROCESS DW 0
NEXT_PROCESS DW 0
PCB_0: TIMES PCB_SIZE DB 0   ; 内核进程
PCB_1: TIMES PCB_SIZE DB 0
PCB_2: TIMES PCB_SIZE DB 0
PCB_3: TIMES PCB_SIZE DB 0
PCB_4: TIMES PCB_SIZE DB 0


TIMES 1024-($-$$) DB 0