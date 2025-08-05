module ibex_decrypt (
	
  // SE ALU Signals
  input logic use_se_alu,
  input  ibex_pkg::alu_op_e operator_i,
  input  logic [31:0]       operand_a_i,
  input  logic [31:0]       operand_b_i,

  input  logic              instr_first_cycle_i,

  input  logic [32:0]       multdiv_operand_a_i,
  input  logic [32:0]       multdiv_operand_b_i,

  input  logic              multdiv_sel_i,

  input  logic [31:0]       imd_val_q_i[2],
  output logic [31:0]       se_imd_val_d_o[2],
  output logic [1:0]        se_imd_val_we_o, // This little guy will keep pipeline from moving on

  output logic [31:0]       se_adder_result_o,
  output logic [33:0]       se_adder_result_ext_o,

  output logic [31:0]       se_result_o,
  output logic              se_comparison_result_o,
  output logic              se_is_equal_result_o,
  
  input logic		    op_b_is_imm, // tells module if operand_b is an immediate value
  
  // Simon Core Signals 
  
  input  logic        clk_i,                      // system clock signal
  input  logic        rst_ni,                      // system reset signal, asserted high
);
  import ibex_pkg::*;
  
  // Overall Signals

  logic dec_finished, enc_finished;
  logic [31:0] simon_a_data, simon_b_data;
  simon_op_e   op_a, op_b;
  logic simon_a_ready, simon_b_ready;
  logic simon_a_done, simon_b_done;
  logic data_valid_a, data_valid_b;
  logic [31:0] se_alu_operand_b;
  logic [31:0] simon_a_out, simon_b_out, alu_out;
  logic [1:0]  internal_se_alu_imd_val_we; // Keeps track of whether the ALU is done with its operation
  
  // latch intermediate dec and enc values, and alu output when ready (simon_a_out, simon_b_out, alu_out)
  se_imd_val_d_o = '{simon_a_out, simon_b_out};
  
  logic [1:0] wrapper_state;
  
  // State Machine Managing Decryption/ALU/Encryption
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin 				// Reset
      wrapper_state = 2'b00;
    end else if (wrapper_state = 2'b00) begin   // First cycle
      if (use_se_alu) begin
        se_imd_val_we_o = 2'b11;
        if (simon_a_ready && simon_b_ready) begin
          simon_a_data = operand_a_i;
          wrapper_state = 2'b01;
          op_a = SIMON_ENCRYPT;
          data_valid_a = 1'b1;
          if (~op_b_is_imm) begin
      	    simon_b_data = operand_b_i;
      	    op_b = SIMON_DECRYPT;
      	    data_valid_b = 1'b1;
      	  end
        end
      end
    end else if (wrapper_state == 2'b01) begin  // Decryption
      data_valid_a = 1'b0;
      data_valid_b = 1'b0;
      if (simon_a_out_ready) begin
        simon_a_done = 1'b1;
      end
      if (simon_b_out_ready) begin
        simon_b_done = 1'b1;
      end
      if (simon_a_done && (op_b_is_imm || simon_b_done)) begin
      	wrapper_state = 2'b10;
      	simon_a_done = 1'b0;
      	simon_b_done = 1'b0;
      	if (~op_b_is_imm) begin
      	  se_alu_operand_b = simon_b_out;
      	end else begin
      	  se_alu_operand_b = operand_b_i;
      	end
      end
    end else if (wrapper_state == 2'b10) begin  // ALU operation
      if (internal_se_alu_imd_val_we == 2'b00) begin
      	wrapper_state = 2'b11;
      end
    end else if (wrapper_state == 2'b11) begin  // Ecryption
      if (enc_finished) begin
      	wrapper_state = 2'b00;
      	se_imd_val_we_o = 2'b00;
      end
    end else 
    end
  end

  // ALU Instantiation

  ibex_se_alu #(
    .RV32B(RV32B)
  ) se_alu_i (
    .operator_i            (operator_i),
    .operand_a_i           (operand_a_i),
    .operand_b_i           (se_alu_operand_b),
    .instr_first_cycle_i   (instr_first_cycle_i),
    .imd_val_q_i           (imd_val_q_i),
    .se_imd_val_we_o       (internal_se_alu_imd_val_we),
    .se_imd_val_d_o        (se_imd_val_d_o),
    .multdiv_operand_a_i   (multdiv_operand_a_i),
    .multdiv_operand_b_i   (multdiv_operand_b_i),
    .multdiv_sel_i         (multdiv_sel_i),
    .se_adder_result_o     (se_adder_result_o),
    .se_adder_result_ext_o (se_adder_result_ext_o),
    .se_result_o           (se_result_o),
    .se_comparison_result_o(se_comparison_result_o),
    .se_is_equal_result_o  (se_is_equal_result_o)
  );
  
  // Simon Core Instantiation

  simon_core #(
    .SIMON_KEY_W(64),
    .SIMON_DATA_W(32),
    .SIMON_ROUNDS(7'b0000001),
    .SIMON_ROUNDS_PER_CYCLE(7'b0000001);
  ) simon_one_i (
    .clk		   (clk_i),                      // system clock signal
    .rst		   (~rst_ni),                      // system reset signal, asserted high
    .op_i		   (op_a),                      // INPUT: crypto operation to execute
    .data_valid_i	   (data_valid_a),      	            // INPUT: assert this signal to transfer a data value to the SIMON core
    .data_i		   (simon_a_data),    		    // INPUT: SIMON data input
    .data_valid_o	   (simon_a_out_ready),       	            // OUTPUT: this signal is asserted to indicate that an output valid is available
    .data_o		   (simon_a_out),    		    // OUTPUT: SIMON core data output
    .ready_o   		   (simon_a_ready)
  );
  
  simon_core #(
    .SIMON_KEY_W(64),
    .SIMON_DATA_W(32),
    .SIMON_ROUNDS(7'b0100000),
    .SIMON_ROUNDS_PER_CYCLE(7'b0000001);
  ) simon_two_i (
    .clk		   (clk_i),                      // system clock signal
    .rst		   (~rst_ni),                      // system reset signal, asserted high
    .op_i		   (op_b),                      // INPUT: crypto operation to execute
    .data_valid_i	   (data_valid_b),      	            // INPUT: assert this signal to transfer a data value to the SIMON core
    .data_i		   (simon_b_data),    		    // INPUT: SIMON data input
    .data_valid_o	   (simon_b_out_ready),       	            // OUTPUT: this signal is asserted to indicate that an output valid is available
    .data_o		   (simon_b_out),    		    // OUTPUT: SIMON core data output
    .ready_o   		   (simon_b_ready)
  );
  
endmodule
