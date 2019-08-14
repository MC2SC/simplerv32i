/*
MIT License

Copyright (c) 2019 MC2SC: Multi-Core MicroController Synthesis from C

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Author: Abdullah Yildiz
*/

`timescale 1 ns / 1 ps

// 1-stage risc-v core
// 32-bit memory interface
// reset polarity?

module SimpleRV32I
(

	input 				clk, reset,
	
	input 				debug_en,
	output [31:0] 		debug_pc_out,

	// output reg 			mem_valid, // The core initiates a memory transfer by asserting mem_valid
	// output reg 			mem_instr,
	input 				mem_ready,

	output reg [13:0] mem_addr,
	output reg [31:0] mem_wdata,
	output reg [ 0:0] mem_wstrb,
	input      [31:0] mem_rdata,
	
	input 				mem_vld,
	output reg 			mem_req

);

	reg mem_valid, mem_instr;

	localparam integer regfile_size = 32;
	localparam integer regindex_bits = 5;

	reg [31:0] reg_pc_current, reg_pc_next;
	reg [31:0] reg_op1_current, reg_op1_next;
	reg [31:0] reg_op2_current, reg_op2_next, reg_out;
	reg [31:0] cpu_regs_current [0:regfile_size-1];
	reg [31:0] cpu_regs_next [0:regfile_size-1];
	reg [31:0] mem_rdata_q_current, mem_rdata_q_next;

	integer i;

	localparam cpu_state_alu_exec = 8'b00010000;
	localparam cpu_state_decode   = 8'b00001000;
	localparam cpu_state_fetch  	= 8'b00000100;
	localparam cpu_state_start    = 8'b00000010;
	localparam cpu_state_init	   = 8'b00000001;

	reg [7:0] cpu_state_current, cpu_state_next;
	
	always@(posedge clk) begin
		if(reset) begin
			cpu_state_current 			<= cpu_state_init;
			reg_pc_current 				<= 0;
			reg_op1_current 				<= 0;
			reg_op2_current 				<= 0;
			mem_rdata_q_current 			<= 0;
			for (i = 0; i < regfile_size; i = i+1) begin
				cpu_regs_current[i] 	<= 0;
			end
		end
		else begin
			cpu_state_current 			<= cpu_state_next;
			reg_pc_current 				<= reg_pc_next;
			reg_op1_current 				<= reg_op1_next;
			reg_op2_current 				<= reg_op2_next;
			mem_rdata_q_current 			<= mem_rdata_q_next;
			for (i = 0; i < regfile_size; i = i+1) begin
					cpu_regs_current[i] 	<= cpu_regs_next[i];
			end
		end
	end

	// AR# 20391 - error occurs when I try to use the Verilog 2001 combinational sensitivity list (always @*) when reading a two-dimensional array:
	always @(*) begin
		cpu_state_next 		= cpu_state_current;
		reg_pc_next 			= reg_pc_current;
		reg_op1_next 			= reg_op1_current;
		reg_op2_next 			= reg_op2_current;
		mem_rdata_q_next 		= mem_rdata_q_current;
		mem_valid 				= 0;
		mem_instr 				= 0;
		mem_addr					= 0;
		mem_wdata 				= 0;
		mem_wstrb 				= 0;
		mem_req = 0;
		for (i = 0; i < regfile_size; i = i+1) begin
			cpu_regs_next[i] 	= cpu_regs_current[i];
		end
		
		case(cpu_state_current)
			cpu_state_init: begin
				reg_pc_next 			= 0;
				reg_op1_next 			= 0;
				reg_op2_next 			= 0;
				cpu_state_next 		= cpu_state_start;
				
				// for (i = 0; i < regfile_size; i = i+1)
				// 	cpu_regs_next[i] 	= 0;

				cpu_regs_next[2] 		= 4096; // stack pointer default value
			end
			cpu_state_start: begin
				if(mem_vld) begin
					if(debug_en && mem_ready) begin
						mem_req = 1'b1;
						mem_addr  		= (reg_pc_current);
						cpu_state_next = cpu_state_fetch;
					end
				end
			end
			cpu_state_fetch: begin
				if(mem_vld) begin
					mem_rdata_q_next 	= mem_rdata;
					$display("mem_rdata is %x at time %d", mem_rdata, $time);
					cpu_state_next 	= cpu_state_decode;
				end
			end
			cpu_state_decode: begin
				if(mem_rdata_q_current[6:5] == 2'b01 && mem_rdata_q_current[4:2] == 3'b100) begin // arithmetic instructions
					// add, sub, sll, slt, sltu, xor, srl, sra, or, and instructions
					reg_op1_next 	= cpu_regs_current[mem_rdata_q_current[19:15]];
					reg_op2_next 	= cpu_regs_current[mem_rdata_q_current[24:20]];
					cpu_state_next = cpu_state_alu_exec;
				end
				else if(mem_rdata_q_current[6:5] == 2'b00 && mem_rdata_q_current[4:2] == 3'b100) begin // arithmetic instructions
					// $display("arithmetic instruction");
					cpu_state_next = cpu_state_alu_exec;
					if(mem_rdata_q_current[14:12] == 3'b000) begin // addi instruction - I-type
						$display("addi at %d $time", $time);
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = $signed(mem_rdata_q_current[31:20]);
					end
					else if(mem_rdata_q_current[14:12] == 3'b010) begin // slti instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[31:20];
					end
					else if(mem_rdata_q_current[14:12] == 3'b011) begin // sltiu instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[31:20];
					end
					else if(mem_rdata_q_current[14:12] == 3'b100) begin // xori instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[31:20];
					end
					else if(mem_rdata_q_current[14:12] == 3'b110) begin // ori instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[31:20];
					end
					else if(mem_rdata_q_current[14:12] == 3'b111) begin // andi instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[31:20];
					end
					else if(mem_rdata_q_current[14:12] == 3'b001) begin // slli instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[24:20];
					end
					else if(mem_rdata_q_current[31:25] == 7'b0000000 && mem_rdata_q_current[14:12] == 3'b101) begin // srli instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[24:20];
					end
					else if(mem_rdata_q_current[31:25] == 7'b0100000 && mem_rdata_q_current[14:12] == 3'b101) begin // srai instruction - I-type
						reg_op1_next = cpu_regs_current[mem_rdata_q_current[19:15]];
						reg_op2_next = mem_rdata_q_current[24:20];
					end
				end
				else if(mem_rdata_q_current[6:5] == 2'b01 && mem_rdata_q_current[4:2] == 3'b101) begin // lui instruction - U-type
					if(mem_rdata_q_current[11:7] != 0) begin					
						cpu_regs_next[mem_rdata_q_current[11:7]] = {mem_rdata_q_current[31:12], 12'b000000000000};
					end					
					reg_pc_next = reg_pc_current + 4;
					cpu_state_next = cpu_state_start;
				end
				else if(mem_rdata_q_current[6:5] == 2'b00 && mem_rdata_q_current[4:2] == 3'b101) begin // auipc instruction - U-type
					if(mem_rdata_q_current[11:7] != 0) begin					
						cpu_regs_next[mem_rdata_q_current[11:7]] = reg_pc_current + {mem_rdata_q_current[31:12], 12'b000000000000};
					end
					reg_pc_next 										= reg_pc_current + 4;
					cpu_state_next 									= cpu_state_start;
				end
				else if(mem_rdata_q_current[6:5] == 2'b00 && mem_rdata_q_current[4:2] == 3'b000) begin // memory instructions
					if(mem_vld) begin
						cpu_state_next = cpu_state_alu_exec;
						mem_req = 1;
						if(mem_rdata_q_current[14:12] == 3'b010) begin // lw instruction - I-type
							mem_addr	= $signed(mem_rdata_q_current[31:20]) + $signed(cpu_regs_current[mem_rdata_q_current[19:15]]);
						end
						else if(mem_rdata_q_current[14:12] == 3'b000) begin // lb instruction - I-type
							mem_addr	= mem_rdata_q_current[31:20] + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
						else if(mem_rdata_q_current[14:12] == 3'b001) begin // lh instruction - I-type
							mem_addr	= mem_rdata_q_current[31:20] + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
						else if(mem_rdata_q_current[14:12] == 3'b100) begin // lbu instruction - I-type
							mem_addr	= mem_rdata_q_current[31:20] + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
						else if(mem_rdata_q_current[14:12] == 3'b101) begin // lhu instruction - I-type
							mem_addr	= mem_rdata_q_current[31:20] + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
					end
				end
				else if(mem_rdata_q_current[6:5] == 2'b01 && mem_rdata_q_current[4:2] == 3'b000) begin // memory instructions
					if(mem_vld) begin
						mem_wdata 		= cpu_regs_current[mem_rdata_q_current[24:20]];
						reg_pc_next 	= reg_pc_current + 4;
						cpu_state_next = cpu_state_start;
						mem_req = 1;
						if(mem_rdata_q_current[14:12] == 3'b010) begin // sw instruction - S-type
							mem_wstrb	= 4'b1111;
							mem_addr		= $signed({mem_rdata_q_current[31:25],mem_rdata_q_current[11:7]}) + $signed(cpu_regs_current[mem_rdata_q_current[19:15]]);	
						end
						else if(mem_rdata_q_current[14:12] == 3'b001) begin // sh instruction - S-type
							mem_wstrb 	= 4'b0011;
							mem_addr		= {mem_rdata_q_current[31:25],mem_rdata_q_current[11:7]} + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
						else if(mem_rdata_q_current[14:12] == 3'b000) begin // sb instruction - S-type
							mem_wstrb 	= 4'b0001;
							mem_addr		= {mem_rdata_q_current[31:25],mem_rdata_q_current[11:7]} + cpu_regs_current[mem_rdata_q_current[19:15]];
						end
					end
				end
				else if(mem_rdata_q_current[6:5] == 2'b11 && mem_rdata_q_current[4:2] == 3'b011) begin // unconditional branch instruction - JAL - UJ-type
					cpu_state_next = cpu_state_start;
					reg_pc_next =  $signed(reg_pc_current) + {{12{mem_rdata_q_current[31]}},mem_rdata_q_current[19:12],mem_rdata_q_current[20],mem_rdata_q_current[30:21],1'b0};
					if(mem_rdata_q_current[11:7] != 0) begin
						cpu_regs_next[mem_rdata_q_current[11:7]] = reg_pc_current + 4;
					end
				end
				else if(mem_rdata_q_current[6:5] == 2'b11 && mem_rdata_q_current[4:2] == 3'b001) begin // unconditional branch instruction - JALR - I-type
					cpu_state_next	= cpu_state_start;		
					reg_pc_next 	=  $signed(cpu_regs_current[mem_rdata_q_current[19:15]]) + {{21{mem_rdata_q_current[31]}},mem_rdata_q_current[30:20]};				
					if(mem_rdata_q_current[11:7] != 0) begin
						cpu_regs_next[mem_rdata_q_current[11:7]] = reg_pc_current + 4;
					end
				end
				else if(mem_rdata_q_current[6:5] == 2'b11 && mem_rdata_q_current[4:2] == 3'b000) begin // branch instructions
					cpu_state_next = cpu_state_start;
					if(mem_rdata_q_current[14:12] == 3'b000) begin // beq instruction - SB-type
						// $display("BEQ reg %x val %x reg %x val %x", mem_rdata_q_current[24:20], cpu_regs_current[mem_rdata_q_current[24:20]], mem_rdata_q_current[19:15], cpu_regs_current[mem_rdata_q_current[19:15]]);						
						if(cpu_regs_current[mem_rdata_q_current[24:20]] == cpu_regs_current[mem_rdata_q_current[19:15]]) begin
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end
					end
					else if(mem_rdata_q_current[14:12] == 3'b001) begin // bne instruction - SB-type
						if(cpu_regs_current[mem_rdata_q_current[24:20]] != cpu_regs_current[mem_rdata_q_current[19:15]]) begin
							// $display("bne instruction %d %d", cpu_regs_current[mem_rdata_q_current[24:20]], cpu_regs_current[mem_rdata_q_current[19:15]]);																				
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end
					end
					else if(mem_rdata_q_current[14:12] == 3'b100) begin // blt instruction - SB-type
						if($signed(cpu_regs_current[mem_rdata_q_current[19:15]]) < $signed(cpu_regs_current[mem_rdata_q_current[24:20]])) begin
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
							// $display("branch is taken %x", (reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0}));
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end	
					end					
					else if(mem_rdata_q_current[14:12] == 3'b110) begin // bltu instruction - SB-type
						if(cpu_regs_current[mem_rdata_q_current[19:15]] < cpu_regs_current[mem_rdata_q_current[24:20]]) begin
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end	
					end
					else if(mem_rdata_q_current[14:12] == 3'b101) begin // bge instruction - SB-type
						if($signed(cpu_regs_current[mem_rdata_q_current[19:15]]) >= $signed(cpu_regs_current[mem_rdata_q_current[24:20]])) begin
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end
					end
					else if(mem_rdata_q_current[14:12] == 3'b111) begin // bgeu instruction - SB-type
						if(cpu_regs_current[mem_rdata_q_current[19:15]] >= cpu_regs_current[mem_rdata_q_current[24:20]]) begin
							reg_pc_next = reg_pc_current + {{20{mem_rdata_q_current[31]}},mem_rdata_q_current[7],mem_rdata_q_current[30:25],mem_rdata_q_current[11:8],1'b0};
						end
						else begin
							reg_pc_next = reg_pc_current + 4;							
						end
					end
					else begin
						$display("unknown instruction");
						$finish;
					end
				end
				else begin
					$display("Undefined Instruction");
					$finish;
				end
			end
			cpu_state_alu_exec: begin
				cpu_state_next = cpu_state_start;
				reg_pc_next 	= reg_pc_current + 4;
				if(mem_rdata_q_current[11:7] != 0) begin
					if(mem_rdata_q_current[6:5] == 2'b01 && mem_rdata_q_current[4:2] == 3'b100) begin // arithmetic instructions
						if(mem_rdata_q_current[31:25] == 7'b0000000 && mem_rdata_q_current[14:12] == 3'b000) begin // add instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current + reg_op2_current;
						end
						else if(mem_rdata_q_current[31:25] == 7'b0100000 && mem_rdata_q_current[14:12] == 3'b000) begin // sub instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current - reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b001) begin // sll instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current << reg_op2_current[4:0];
						end
						else if(mem_rdata_q_current[14:12] == 3'b010) begin // slt instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = $signed(reg_op1_current) < $signed(reg_op2_current);
						end
						else if(mem_rdata_q_current[14:12] == 3'b011) begin // sltu instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current < reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b100) begin // xor instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current ^ reg_op2_current;
						end
						else if(mem_rdata_q_current[31:25] == 7'b0000000 && mem_rdata_q_current[14:12] == 3'b101) begin // srl instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current >> reg_op2_current[4:0];
						end
						else if(mem_rdata_q_current[31:25] == 7'b0100000 && mem_rdata_q_current[14:12] == 3'b101) begin // sra instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current >>> reg_op2_current[4:0];
						end
						else if(mem_rdata_q_current[14:12] == 3'b110) begin // or instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current | reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b111) begin // and instruction - R-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current & reg_op2_current;
						end
					end
					else if(mem_rdata_q_current[6:5] == 2'b00 && mem_rdata_q_current[4:2] == 3'b100) begin // arithmetic instructions
						if(mem_rdata_q_current[14:12] == 3'b000) begin // addi instruction - I-type
							$display("%d %d %d", mem_rdata_q_current[11:7], reg_op1_current, reg_op2_current);
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current + reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b010) begin // slti instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = $signed(reg_op1_current) < $signed(reg_op2_current);
						end
						else if(mem_rdata_q_current[14:12] == 3'b011) begin // sltiu instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current < reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b100) begin // xori instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current ^ reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b110) begin // ori instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current | reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b111) begin // andi instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current & reg_op2_current;
						end
						else if(mem_rdata_q_current[14:12] == 3'b001) begin // slli instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current << reg_op2_current;
						end
						else if(mem_rdata_q_current[31:25] == 7'b0000000 && mem_rdata_q_current[14:12] == 3'b101) begin // srli instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current >> reg_op2_current;
						end
						else if(mem_rdata_q_current[31:25] == 7'b0100000 && mem_rdata_q_current[14:12] == 3'b101) begin // srai instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]] = reg_op1_current >>> reg_op2_current;
						end
					end
					else if(mem_rdata_q_current[6:5] == 2'b00 && mem_rdata_q_current[4:2] == 3'b000) begin // memory instructions
						if(mem_rdata_q_current[14:12] == 3'b010) begin // lw instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]]	= mem_rdata;
						end
						else if(mem_rdata_q_current[14:12] == 3'b000) begin // lb instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]]	= $signed(mem_rdata[7:0]);
						end
						else if(mem_rdata_q_current[14:12] == 3'b001) begin // lh instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]]	= $signed(mem_rdata[15:0]);
						end
						else if(mem_rdata_q_current[14:12] == 3'b100) begin // lbu instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]]	= mem_rdata[7:0];
						end
						else if(mem_rdata_q_current[14:12] == 3'b101) begin // lhu instruction - I-type
							cpu_regs_next[mem_rdata_q_current[11:7]]	= mem_rdata[15:0];
						end
					end
				end
			end
		endcase
	end
	
	assign debug_pc_out = reg_pc_current;

endmodule
