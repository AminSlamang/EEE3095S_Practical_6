// KTNRIO001 - Rio Katundulu
// SLMAMI010 - Amin Slamang
`timescale 1ns / 1ps

module simple_cpu( clk, rst, instruction,regfile_0_i,regfile_1_i,regfile_2_i,regfile_3_i);

    parameter DATA_WIDTH = 8; //8 bit wide data
    parameter ADDR_BITS = 5; //32 Addresses
    parameter INSTR_WIDTH =20; //20b instruction

    input [INSTR_WIDTH-1:0] instruction;
    input clk, rst;
    output reg [DATA_WIDTH-1:0] regfile_0_i;
    output reg [DATA_WIDTH-1:0] regfile_1_i;
    output reg [DATA_WIDTH-1:0] regfile_2_i;
    output reg [DATA_WIDTH-1:0] regfile_3_i;
    //Wires for connecting to data memory    
    wire [ADDR_BITS-1:0] addr_i;
    wire [DATA_WIDTH-1:0] data_in_i, data_out_i, result2_i ;
    wire wen_i; 
    
    //wire for connecting to the ALU
    wire [DATA_WIDTH-1:0]operand_a_i, operand_b_i, result1_i;
    wire [3:0]opcode_i;
    
   
    //Wire for connecting to CU
    wire [DATA_WIDTH-1:0]offset_i;
    wire sel1_i, sel3_i;
    wire [DATA_WIDTH-1:0] operand_1_i, operand_2_i;
    
    //Instantiating an alu1
    alu #(DATA_WIDTH) alu1 (clk, operand_a_i, operand_b_i, opcode_i, result1_i);
     
    //instantiation of data memory
    reg_mem  #(ADDR_BITS,DATA_WIDTH) data_memory(result1_i, data_in_i, wen_i, clk, data_out_i);
    
    //Instantiation of a CU
    CU  #(DATA_WIDTH,ADDR_BITS, INSTR_WIDTH) CU1(clk, rst, instruction, result2_i,
        operand_1_i, operand_2_i, offset_i, opcode_i, sel1_i, sel3_i, wen_i, regfile_0_i, regfile_1_i, regfile_2_i, regfile_3_i);
    
    //Connect CU to ALU
    assign operand_a_i = operand_1_i;
    assign operand_b_i = (sel3_i == 0) ? operand_2_i: (sel3_i == 1) ? offset_i : 8'bx;
    
    //Connect CU to Memory
    assign data_in_i = operand_2_i;
    
    //Connect datamem to CU
    assign result2_i = (sel1_i == 0) ? data_out_i : (sel1_i == 1) ? result1_i : 8'bx;  

endmodule

module alu( clk, operand_a, operand_b, opcode, result);
    parameter DATA_WIDTH = 8;

    input clk;
    input[DATA_WIDTH-1:0]operand_a,operand_b;
    input [3:0] opcode;
    output reg[DATA_WIDTH-1:0] result;
    
  always@(posedge clk)
    begin
     case(opcode)
        4'b0000: //Addition
           result <= operand_a + operand_b ; 
        4'b0001: //Subtraction 
           result <= operand_a - operand_b;
        default: result <= 8'bx; 
     endcase
     
    end
endmodule

`timescale 1ns / 1ps

module CU (clk,rst, instr, result2, operand1, operand2, offset, opcode, sel1, sel3,w_r,regfile_0,regfile_1,regfile_2,regfile_3);
    //Defaults unless overwritten during instantiation
    parameter DATA_WIDTH = 8; //8 bit wide data
    parameter ADDR_BITS = 5; //32 Addresses
    parameter INSTR_WIDTH =20; 
    //INPUTS
    input clk,rst;
    input [INSTR_WIDTH-1:0]instr;
    input [DATA_WIDTH-1:0] result2;

    //OUTPUTS
    output reg [DATA_WIDTH-1:0] operand1;
    output reg [DATA_WIDTH-1:0] operand2;
    output reg [DATA_WIDTH-1:0] offset;
    output reg [3:0] opcode;
    output reg sel1, sel3, w_r;

    //REGISTER FILE: CU internal register file of 4 registers.  This is a over simplication of a real solution
    output reg [DATA_WIDTH-1:0] regfile_0;
    output reg [DATA_WIDTH-1:0] regfile_1;
    output reg [DATA_WIDTH-1:0] regfile_2;
    output reg [DATA_WIDTH-1:0] regfile_3;
    output reg [INSTR_WIDTH-1:0]instruction;
    
    //STATES
    parameter RESET = 4'b0000;
    parameter DECODE = 4'b0001;
    parameter EXECUTE = 4'b0010;
    parameter MEM_ACCESS = 4'b0100;
    parameter WRITE_BACK = 4'b1000;
        
    reg [3:0] state = RESET;
    
    
    always @(posedge clk) begin
        instruction = instr;
        case (state)
            RESET : begin //#0
                if (instruction[19:18] == 2'b00)  begin
                    state = RESET; 
                    end else begin
                    state = DECODE; //#1
                    end
                //-----------------------------
                //Write initial values to regfile
                regfile_0<= 8'd0;
                regfile_1<= 8'd1;
                regfile_2<= 8'd2;
                regfile_3<= 8'd3;

                //Set output reset defaults
                operand1 <= #(DATA_WIDTH)'d0;
                operand2 <= #(DATA_WIDTH)'d0;
                offset <= #(DATA_WIDTH)'d0;
                opcode <= 4'b1111;
                sel1 <= 0;
                sel3 <= 0;
                w_r <= 0;
                //-----------------------------
            end

            DECODE : begin //#1
                state = EXECUTE; //#2
                if (instruction[19:18] == 2'b1) begin //std_op
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[13:12]) //X3
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[13:12]]; //X3
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                   sel1 <= 1;
                    sel3 <= 0;
                    w_r <= 0;
                end else if (instruction[19:18] == 2'b10) begin //loadR 
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[17:16]) //z
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[17:16]]; //z
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 0;
                end else if (instruction[19:18] == 2'b11) begin //storeR 
                   /******************************************** 
                   *
                   * FILL IN CORRECT CODE HERE
                   *
                   ********************************************/ 
                  case(instruction[15:14]) //X1
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                	//operand1 <= regfile[instruction[17:16]];
                  case(instruction[17:16]) //X2
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
					//operand2 <= regfile[instruction[15:14]];
                  	offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 1;
                end
            end
            EXECUTE: begin //#2
                state = MEM_ACCESS; //#3
                if (instruction[19:18] == 2'b01) begin //std_op
                    state = WRITE_BACK;
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[13:12]) //X3
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[13:12]]; //X3
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 1;
                    sel3 <= 0;
                    w_r <= 0;

                end else if (instruction[19:18] == 2'b10) begin //loadR  
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[17:16]) //z
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[17:16]]; //z
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 0;
                end else if (instruction[19:18] == 2'b11) begin //storeR
                   /******************************************** 
                   *
                   * FILL IN CORRECT CODE HERE
                   *
                   ********************************************/ 
                  case(instruction[15:14]) //X1
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                	//operand1 <= regfile[instruction[17:16]];
                  case(instruction[17:16]) //X2
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
					//operand2 <= regfile[instruction[15:14]];
                  	offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 1;
                end
            end
            MEM_ACCESS: begin //#3
                state = WRITE_BACK; //#4
                if (instruction[19:18] == 2'b10) begin //loadR
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[17:16]) //z
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[17:16]]; //z
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 0;
                end else if (instruction[19:18] == 2'b11) begin //storeR 
                   /******************************************** 
                   *
                   * FILL IN CORRECT CODE HERE
                   * Take note of what the next state should be according to
                   * the FSM
                   *
                   ********************************************/ 
                	state = DECODE;
                  case(instruction[15:14]) //X1
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                  	//operand1 <= regfile[instruction[17:16]];
                  case(instruction[17:16]) //X2
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
					//operand2 <= regfile[instruction[15:14]];
                  	offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 1;
                end
            end
            WRITE_BACK: begin //#4
                state = DECODE; //#1
                if (instruction[19:18] == 2'b01) begin //std_op
                  case(instruction[17:16]) //X1
                    2'b00 : regfile_0 <= result2;
                    2'b01 : regfile_1 <= result2;
                    2'b10 : regfile_2 <= result2;
                    2'b11 : regfile_3 <= result2;
                  endcase
                    //regfile[instruction[17:16]] <= result2; //X1
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[13:12]) //X3
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[13:12]]; //X3
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 1;
                    sel3 <= 0;
                    w_r <= 0;
                end else if (instruction[19:18] == 2'b11) begin //storeR 
                   /******************************************** 
                   *
                   * FILL IN CORRECT CODE HERE
                   *
                   ********************************************/
                  case(instruction[15:14]) //
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                	//operand1 <= regfile[instruction[17:16]];
                  case(instruction[17:16]) //X2
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
					//operand2 <= regfile[instruction[15:14]];
                  	offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 1;
                    
                end else if (instruction[19:18] == 2'b10) begin //loadR  
                  case(instruction[17:16]) //X1
                    2'b00 : regfile_0 <= result2;
                    2'b01 : regfile_1 <= result2;
                    2'b10 : regfile_2 <= result2;
                    2'b11 : regfile_3 <= result2;
                  endcase
                    //regfile[instruction[17:16]] <= result2; //From data mem
                  case(instruction[15:14]) //X2
                    2'b00 : operand1 <= regfile_0;
                    2'b01 : operand1 <= regfile_1;
                    2'b10 : operand1 <= regfile_2;
                    2'b11 : operand1 <= regfile_3;
                  endcase
                    //operand1 <= regfile[instruction[15:14]]; //X2
                  case(instruction[17:16]) //z
                    2'b00 : operand2 <= regfile_0;
                    2'b01 : operand2 <= regfile_1;
                    2'b10 : operand2 <= regfile_2;
                    2'b11 : operand2 <= regfile_3;
                  endcase
                    //operand2 <= regfile[instruction[17:16]]; //z
                    offset <= instruction[11:4];
                    opcode <= instruction[3:0];
                    sel1 <= 0; //pass data_out
                    sel3 <= 1; //pass offset
                    w_r <= 0;
                end
            end

            default: // Fault Recovery
            state = RESET; //#0
        endcase
    end
endmodule

`timescale 1ns / 1ps

module reg_mem (addr, data_in, wen, clk, data_out);

    parameter DATA_WIDTH = 8; //8 bit wide data
    parameter ADDR_BITS = 5; //32 Addresses

    input [ADDR_BITS-1:0] addr;
    input [DATA_WIDTH-1:0] data_in;
    input wen;
    input clk;
    output [DATA_WIDTH-1:0] data_out;

    reg [DATA_WIDTH-1:0] data_out;

    //8 memory locations each storing a 4bits wide value
    reg [DATA_WIDTH-1:0] mem_array [(2**ADDR_BITS)-1:0];

    always @(posedge clk) begin

        if (wen) begin //Write
            mem_array [addr] <= data_in;
            data_out <= #(DATA_WIDTH)'b0;
        end

        else begin //Read
            data_out <= mem_array[addr];
        end
    end

endmodule