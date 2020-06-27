OBJS_BOOTPACK = bootpack.obj naskfunc.obj hankaku.obj graphic.obj dsctbl.obj \
		int.obj fifo.obj

TOOLPATH = ../z_tools/
INCPATH  = ../z_tools/haribote/

MAKE     = $(TOOLPATH)make.exe -r
NASK     = $(TOOLPATH)nask.exe #汇编器
CC1      = $(TOOLPATH)cc1.exe -I$(INCPATH) -Os -Wall -quiet #C语言编译器（改造的gcc）
GAS2NASK = $(TOOLPATH)gas2nask.exe -a #将gcc编译出的gas汇编代码转换成能被nask汇编的nas代码
OBJ2BIM  = $(TOOLPATH)obj2bim.exe #将obj目标文件链接成bim文件
BIM2HRB  = $(TOOLPATH)bim2hrb.exe #根据操作系统的不同将bim文件转换成实际可用的hrb文件
RULEFILE = $(TOOLPATH)haribote/haribote.rul
BIN2OBJ  = $(TOOLPATH)bin2obj.exe
EDIMG    = $(TOOLPATH)edimg.exe
IMGTOL   = $(TOOLPATH)imgtol.com
COPY     = copy
DEL      = del
MAKEFONT = $(TOOLPATH)makefont.exe


default :
	$(MAKE) img

ipl10.bin : ipl10.nas Makefile #将初始启动汇编文件汇编成二进制bin文件
	$(NASK) ipl10.nas ipl10.bin ipl10.lst

asmhead.bin : asmhead.nas Makefile #将汇编头用nask汇编成二进制bin文件
	$(NASK) asmhead.nas asmhead.bin asmhead.lst

bootpack.gas : bootpack.c Makefile #用C编译器将C语言文件编译成gas汇编文件
	$(CC1) -o bootpack.gas bootpack.c

bootpack.nas : bootpack.gas Makefile #将gas文件转换成nas文件
	$(GAS2NASK) bootpack.gas bootpack.nas

bootpack.obj : bootpack.nas Makefile #用nask汇编出目标文件
	$(NASK) bootpack.nas bootpack.obj bootpack.lst

naskfunc.obj : naskfunc.nas Makefile #用nask汇编出函数代码的目标文件
	$(NASK) naskfunc.nas naskfunc.obj naskfunc.lst

hankaku.bin : hankaku.txt Makefile
	$(MAKEFONT) hankaku.txt hankaku.bin

hankaku.obj : hankaku.bin Makefile
	$(BIN2OBJ) hankaku.bin hankaku.obj _hankaku

bootpack.bim : $(OBJS_BOOTPACK) Makefile  #将函数文件和主文件链接成bim文件
	$(OBJ2BIM) @$(RULEFILE) out:bootpack.bim stack:3136k map:bootpack.map \
		$(OBJS_BOOTPACK)

# 3MB+64KB=3136KB

bootpack.hrb : bootpack.bim Makefile #将bim文件转换成实际可用的hrb文件
	$(BIM2HRB) bootpack.bim bootpack.hrb 0

haribote.sys : asmhead.bin bootpack.hrb Makefile #加上汇编的头
	copy /B asmhead.bin+bootpack.hrb haribote.sys

haribote.img : ipl10.bin haribote.sys Makefile #加上启动区作程img映像文件
	$(EDIMG)   imgin:../z_tools/fdimg0at.tek \
		wbinimg src:ipl10.bin len:512 from:0 to:0 \
		copy from:haribote.sys to:@: \
		imgout:haribote.img

%.gas : %.c Makefile
	$(CC1) -o $*.gas $*.c

%.nas : %.gas Makefile
	$(GAS2NASK) $*.gas $*.nas

%.obj : %.nas Makefile
	$(NASK) $*.nas $*.obj $*.lst

img :
	$(MAKE) haribote.img

run :
	$(MAKE) img
	$(COPY) haribote.img ..\z_tools\qemu\fdimage0.bin
	$(MAKE) -C ../z_tools/qemu

install :
	$(MAKE) img
	$(IMGTOL) w a: haribote.img

clean :
	-$(DEL) *.bin
	-$(DEL) *.lst
	-$(DEL) *.gas
	-$(DEL) *.obj
	-$(DEL) bootpack.nas
	-$(DEL) bootpack.map
	-$(DEL) bootpack.bim
	-$(DEL) bootpack.hrb
	-$(DEL) haribote.sys

src_only :
	$(MAKE) clean
	-$(DEL) haribote.img
