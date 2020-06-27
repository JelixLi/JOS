; haribote-ipl
; TAB=4

CYLS	EQU		10				; 读入柱面的个数

		ORG		0x7c00			; 指明程序的装载地址

; 以下的代码适用于标准FAT12格式的软盘

		JMP		entry
		DB		0x90
		DB		"HARIBOTE"		; 您可以自由地写引导扇区的名称（8个字节）
		DW		512				; 1个扇区大小（必须为512）
		DB		1				; 簇（cluster）的大小（必须为1个扇区）
		DW		1				; FAT的起始位置（一般从第一个扇区开始）
		DB		2				; FAT的个数（必须为2）
		DW		224				; 根目录的大小（一般设成224项）
		DW		2880			; 该磁盘的大小（必须为2880扇区）
		DB		0xf0			; 磁盘的种类（必须为0xf0）
		DW		9				; FAT的长度（必须为9扇区）
		DW		18				; 1个磁道（track）有几个扇区（必须为18）
		DW		2				; 磁头数（必须是2）
		DD		0				; 不使用分区，必须是0
		DD		2880			; 重写一次磁盘大小
		DB		0,0,0x29		; 意义不明，固定
		DD		0xffffffff		; （可能是）卷标号码
		DB		"HARIBOTEOS "	; 磁盘的名称（11字节）
		DB		"FAT12   "		; 磁盘格式名称（8字节）
		RESB	18				; 先空出18字节

; 程序主体

entry:
		MOV		AX,0			; 初始化寄存器
		MOV		SS,AX
		MOV		SP,0x7c00
		MOV		DS,AX

; 以下这段用来从软盘中加载数据到内存，一张软盘有2个磁头，80个柱面，18个扇区

		MOV		AX,0x0820
		MOV		ES,AX
		MOV		CH,0			; 柱面0
		MOV		DH,0			; 磁头0
		MOV		CL,2			; 扇区2
readloop:
		MOV		SI,0			; 记录读取失败次数的寄存器
retry:
		MOV		AH,0x02			; AH=0x02 : 读入磁盘
		MOV		AL,1			; 1个扇区
		MOV		BX,0
		MOV		DL,0x00			; A驱动器
		INT		0x13			; 调用磁盘BIOS
		JNC		next			; 没出错时跳转到next
		ADD		SI,1			; 往SI加1
		CMP		SI,5			; 比较SI与5
		JAE		error			; SI>=5时，即连续5次读取失败，则跳转到error
		MOV		AH,0x00
		MOV		DL,0x00			; A驱动器
		INT		0x13			; 重置驱动器
		JMP		retry
next:
		MOV		AX,ES			; 将内存地址后移0x200
		ADD		AX,0x0020
		MOV		ES,AX			; 因为没有ADD ES,0x020的指令，所以这里绕个弯
		ADD		CL,1			; 往CL里加1
		CMP		CL,18			; 比较CL与18
		JBE		readloop		; 如果CL<=18。则跳转到readloop
		MOV		CL,1
		ADD		DH,1
		CMP		DH,2
		JB		readloop		; 如果DH<2，则跳转到readloop
		MOV		DH,0
		ADD		CH,1
		CMP		CH,CYLS
		JB		readloop		; 如果CH<CYLS，则跳转到readloop

; 完成数据读取并加载操作系统程序

		MOV		[0x0ff0],CH		; 请注意IPL已读多远
		JMP		0xc200
;以下为错误处理部分代码
error:
		MOV		SI,msg
;下面这段代码用来向显示器输出字符串
putloop:
		MOV		AL,[SI]
		ADD		SI,1			; 给SI加1
		CMP		AL,0
		JE		fin
		MOV		AH,0x0e			; 显示一个文字
		MOV		BX,15			; 指定字符颜色
		INT		0x10			; 调用显卡BIOS
		JMP		putloop
fin:
		HLT						; 让CPU休眠
		JMP		fin				; 无限循环

;以下是出错时BIOS在显示屏上显示的字符“load error”以及换行符
msg:
		DB		0x0a, 0x0a		; 换行两次
		DB		"load error"
		DB		0x0a			; 换行
		DB		0

		RESB	0x7dfe-$		; 保留的字节

		DB		0x55, 0xaa		; 最后的两个字节，一定得是0x55aa，否则将会报启动错误
