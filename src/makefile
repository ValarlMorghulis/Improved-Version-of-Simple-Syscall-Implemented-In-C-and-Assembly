KERNEL_DIR = kernel
API_DIR = api
APP_DIR = app

QEMU_IMG = qemu-img
NASM_BIN = nasm
NASM_BIN_FLAGS = -f bin
NASM_ELF32_FLAGS = -f elf32
GCC = gcc
GCC_ARCH = -march=i386
GCC_BITS = -m16
GCC_INCLUDE = -I $(API_DIR)
GCC_WALL = -Wall
GCC_NOSTDLIB = -nostdlib
OBJCOPY = objcopy
OBJCOPY_FLAGS = -O binary -j .text -j .data -j .rodata
DD = dd
DD_BS = bs=512
DD_CONV = conv=notrunc 2>/dev/null
QEMU = qemu-system-x86_64
QEMU_FLAGS = -smp sockets=1,cores=1,threads=2 -m 2048

all: run

clean:
	rm -f *.o *.bin *.img

disk.img:
	$(QEMU_IMG) create -f raw disk.img 1M

mbr.bin: $(KERNEL_DIR)/mbr.asm
	$(NASM_BIN) $(NASM_BIN_FLAGS) -o mbr.bin $<

kernel.bin: $(KERNEL_DIR)/kernel.asm
	$(NASM_BIN) $(NASM_BIN_FLAGS) -o kernel.bin $<

api.o: $(API_DIR)/api.asm
	$(NASM_BIN) $(NASM_ELF32_FLAGS) $< -o api.o

demo.o: $(APP_DIR)/demo.c
	$(GCC) $(GCC_ARCH) $(GCC_BITS) $(GCC_INCLUDE) -c $< -o demo.o

os.o: demo.o api.o
	$(GCC) $(GCC_WALL) $(GCC_NOSTDLIB) $(GCC_BITS) -o os.o demo.o api.o

os.bin: os.o
	$(OBJCOPY) $(OBJCOPY_FLAGS) os.o os.bin

disk.img: mbr.bin kernel.bin os.bin
	$(DD) if=mbr.bin of=disk.img $(DD_BS) count=1 $(DD_CONV)
	$(DD) if=kernel.bin of=disk.img $(DD_BS) seek=1 count=2 $(DD_CONV)
	$(DD) if=os.bin of=disk.img $(DD_BS) seek=3 count=26 $(DD_CONV)

run: disk.img
	$(QEMU) $(QEMU_FLAGS) -drive file=disk.img

.PHONY: all clean run
