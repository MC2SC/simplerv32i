#!/bin/sh

# run this script to compile main.c to assembly and then binary

set -e

riscv32-unknown-elf-gcc -S -march=rv32i main.c
riscv32-unknown-elf-gcc -c -march=rv32i -o main.o main.c
riscv32-unknown-elf-gcc -Os -T custom.lds -ffreestanding -nostdlib -o main.elf -Wl,--strip-debug main.o
riscv32-unknown-elf-objcopy -O binary main.elf main.bin

# the following script generates corresponding memory file of main.bin as Verilog RTL
python init_mem.py 8192 main.bin
