; haribote-os boot asm
; TAB=4

BOTPAK	EQU		0x00280000		; bootpack加载目标
DSKCAC	EQU		0x00100000		; 磁盘缓存位置
DSKCAC0	EQU		0x00008000		; 磁盘缓存位置（实模式）

; 与BOOT_INFO相关
CYLS	EQU		0x0ff0			; 设定启动区
LEDS	EQU		0x0ff1
VMODE	EQU		0x0ff2			; 关于颜色数目的信息，颜色的位数
SCRNX	EQU		0x0ff4			; 分辨率的X（screen X）
SCRNY	EQU		0x0ff6			; 分辨率的Y（screen Y）
VRAM	EQU		0x0ff8			; 图像缓冲区的开始地址

		ORG		0xc200			; 此程序要被装载到的内存地址

; 设置屏幕模式

		MOV		AL,0x13			; VGA显卡，320X200X8位彩色
		MOV		AH,0x00
		INT		0x10
		MOV		BYTE [VMODE],8	; 记录画面模式
		MOV		WORD [SCRNX],320
		MOV		WORD [SCRNY],200
		MOV		DWORD [VRAM],0x000a0000

; 用BIOS取得键盘上各种LED指示灯的状态

		MOV		AH,0x02
		INT		0x16 			; keyboard BIOS
		MOV		[LEDS],AL

; 防止PIC接受任何中断（禁止中断防止模式转换过程中被打断）
; 在AT兼容机的规格中，如果您初始化PIC，
; 偶尔挂起（如果未在CLI之前完成）
; PIC初始化将在以后完成

		MOV		AL,0xff
		OUT		0x21,AL
		NOP						; 因为如果继续执行OUT指令，似乎有一个模型不起作用
		OUT		0xa1,AL

		CLI						; 此外，即使在CPU级别，也禁止中断。

; 设置A20GATE，以便CPU可以访问1MB或更多的内存。

		CALL	waitkbdout
		MOV		AL,0xd1
		OUT		0x64,AL
		CALL	waitkbdout
		MOV		AL,0xdf			; enable A20
		OUT		0x60,AL
		CALL	waitkbdout

; 保护模式转换

[INSTRSET "i486p"]				; “想要使用486指令”的叙述

		LGDT	[GDTR0]			; 设定临时GDT
		MOV		EAX,CR0
		AND		EAX,0x7fffffff	; 设置bit31‚为了禁止分页
		OR		EAX,0x00000001	; 设置bit0，为了切换到保护模式
		MOV		CR0,EAX
		JMP		pipelineflush
pipelineflush:
		MOV		AX,1*8			;  可读写的段32bit
		MOV		DS,AX
		MOV		ES,AX
		MOV		FS,AX
		MOV		GS,AX
		MOV		SS,AX

; bootpack的转送

		MOV		ESI,bootpack	; 转送源
		MOV		EDI,BOTPAK		; 转送目的地
		MOV		ECX,512*1024/4
		CALL	memcpy

; 磁盘数据最终转送到它本来的位置去

; 首先从启动扇区开始

		MOV		ESI,0x7c00		; 转送源
		MOV		EDI,DSKCAC		; 转送目的地
		MOV		ECX,512/4
		CALL	memcpy

; 所有剩下的

		MOV		ESI,DSKCAC0+512	; 转送源
		MOV		EDI,DSKCAC+512	; 转送目的地
		MOV		ECX,0
		MOV		CL,BYTE [CYLS]
		IMUL	ECX,512*18*2/4	; 从柱面数转换为字节数/4
		SUB		ECX,512/4		; 减去IPL
		CALL	memcpy

; 必须由asmhead完成的工作至此完毕
; 接下来由bootpack完成

; bootpack的启动

		MOV		EBX,BOTPAK
		MOV		ECX,[EBX+16]
		ADD		ECX,3			; ECX += 3;
		SHR		ECX,2			; ECX /= 4;
		JZ		skip			; 没有要传送的东西时
		MOV		ESI,[EBX+20]	; 转送源
		ADD		ESI,EBX
		MOV		EDI,[EBX+12]	; 转送目的地
		CALL	memcpy
skip:
		MOV		ESP,[EBX+12]	; 找初始值
		JMP		DWORD 2*8:0x0000001b

waitkbdout:
		IN		 AL,0x64
		AND		 AL,0x02
		JNZ		waitkbdout		; AND的结果如果不是0，就跳到waitkbdout
		RET

memcpy:
		MOV		EAX,[ESI]
		ADD		ESI,4
		MOV		[EDI],EAX
		ADD		EDI,4
		SUB		ECX,1
		JNZ		memcpy			; 减法的运算结果如果不是0，就跳转到memcpy
		RET


		ALIGNB	16
GDT0:
		RESB	8				; NULL selector
		DW		0xffff,0x0000,0x9200,0x00cf	; 可以读写的段
		DW		0xffff,0x0000,0x9a28,0x0047	; 可以执行的段

		DW		0
GDTR0:
		DW		8*3-1
		DD		GDT0

		ALIGNB	16
bootpack:
