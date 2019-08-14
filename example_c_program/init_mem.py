#!/usr/bin/python

import sys

# print sys.version

byte_counter = 0
mem_depth = sys.argv[1]
bin_file = sys.argv[2]
hex_word = ''

print "Creating the file instr_data_memory.v"
mem_file = open("instr_data_memory.v", 'w')
mem_file_string = "module memory( \n \
\tinput clk,\n \
\tinput rst,\n \
\tinput [31:0] mem_addr,\n \
\tinput [31:0] mem_wdata,\n \
\tinput [ 3:0] mem_wstrb,\n \
\toutput reg [31:0] mem_rdata\n \
);\n\n \
\tparameter DEPTH = "
# mem_file.write(mem_file_string)
# mem_file.write(mem_depth)
mem_file_string = ";\n \
\treg mem_ready;\n \
\treg [7:0] memory[0:DEPTH-1];\n\n \
\tinitial begin\n"
# mem_file.write(mem_file_string)

with open(bin_file, "rb") as f:
    byte = f.read(1)
    while byte != "":
        if byte_counter == int(mem_depth):
            print "ERROR: Change memory depth."
            sys.exit()
        # Do stuff with byte.
        hex = ''.join(x.encode('hex') for x in byte)
        # print hex
        hex_word += hex
        byte = f.read(1)
        mem_file.write("\t\tmemory[")
        mem_file.write(str(byte_counter))
        mem_file.write("] = 8'h")
        mem_file.write(hex_word)
        mem_file.write(";\n")
        hex_word = ''
        byte_counter += 1

for i in range(byte_counter, int(mem_depth)):
    if byte_counter >= int(mem_depth):
       print "ERROR: Change memory depth."
       sys.exit()
    mem_file.write("\t\tmemory[")
    mem_file.write(str(byte_counter))
    mem_file.write("] = 8'h0;\n")
    byte_counter += 1
    

mem_file_string = "\tend\n\n \
\talways @(posedge clk) begin\n \
\t\tif(rst) begin\n \
\t\t\tmem_ready <= 0;\n \
\t\tend\n \
\t\telse begin\n \
\t\t\tmem_ready <= 1;\n \
\t\t\tmem_rdata[31:24] <= mem[mem_addr+3];\n \
\t\t\tmem_rdata[23:16] <= mem[mem_addr+2];\n \
\t\t\tmem_rdata[15:8]  <= mem[mem_addr+1];\n \
\t\t\tmem_rdata[7:0]   <= mem[mem_addr+0];\n \
\t\t\tif(mem_wstrb == 4'b1111) begin\n \
\t\t\t\tmem[mem_addr+0] <= mem_wdata[7:0];\n \
\t\t\t\tmem[mem_addr+1] <= mem_wdata[15:8];\n \
\t\t\t\tmem[mem_addr+2] <= mem_wdata[23:16];\n \
\t\t\t\tmem[mem_addr+3] <= mem_wdata[31:24];\n \
\t\t\tend\n \
\t\t\telse if(mem_wstrb == 4'b0011) begin\n \
\t\t\t\tmem[mem_addr+0] <= mem_wdata[7:0];\n \
\t\t\t\tmem[mem_addr+1] <= mem_wdata[15:8];\n \
\t\t\tend\n \
\t\t\telse if(mem_wstrb == 4'b0001) begin\n \
\t\t\t\tmem[mem_addr+0] <= mem_wdata[7:0];\n \
\t\t\tend\n \
\t\tend\n \
\tend\n\n \
endmodule\n"
# mem_file.write(mem_file_string)    

mem_file.close()
f.close
