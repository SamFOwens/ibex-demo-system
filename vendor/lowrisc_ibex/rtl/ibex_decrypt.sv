module ibex_decrypt (
	
  // SE ALU Signals
  
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
  //input  simon_op_e   op_i,                     // INPUT: crypto operation to execute
  //input  logic        key_valid_i,              // INPUT: assert this signal to transfer a key value to the SIMON core
  //input  logic [7:0]  key_i [0:(SIMON_KEY_W/8)-1], // INPUT: SIMON key to expand
  //input  logic        data_valid_i,             // INPUT: assert this signal to transfer a data value to the SIMON core
  //input  logic [SIMON_DATA_W-1:0] data_i,       // INPUT: SIMON data input
  output logic        data_valid_o,             // OUTPUT: this signal is asserted to indicate that an output valid is available
  output logic [SIMON_DATA_W-1:0] data_o,       // OUTPUT: SIMON core data output
  //output logic        ready_o                   // OUTPUT: asserted when the SIMON core is ready for a new request
);
  import ibex_pkg::*;

  // Overall Signals

  logic dec_finished, enc_finished;
  logic [31:0] simon_a_data;
  logic [31:0] se_alu_operand_b_i;
  logic [31:0] simon_a_out;
  logic [31:0] simon_b_out;
  logic [31:0] alu_out;
  logic [1:0]  internal_se_alu_imd_val_we; // Keeps track of whether the ALU is done with its operation
  
  assign se_alu_operand_b_i = is_immediate ? operand_b_i :
  assign simon_a_data_i = dec_finished ? se_result_o : operand_a_i;

 // assign se_imd_val_we_o = {~dec_finished, ~enc_finished} | internal_se_alu_imd_val_we; // Keeps track of whether either Keyexpand is done or the appropriate decrypt + alu op combo is done (I think this works when dec and enc_finished are implemented)
  
  // latch intermediate dec and enc values, and alu output when ready (simon_a_out, simon_b_out, alu_out)
  se_imd_val_d_o = '{simon_a_out, simon_b_out};

  logic data_valid_i;
  
  data_valid_i = 1'b1;
  
  logic [1:0] wrapper_state;
  
  // State Machine Managing Decryption/ALU/Encryption
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin 				// Reset
      wrapper_state = 2'b00;
    end else if (wrapper_state = 2'b00) begin   // First cycle
      se_imd_val_we_o = 2'b11;
      wrapper_state = 2'b01;
    end else if (wrapper_state == 2'b01) begin  // Decryption
      if (dec_finished) begin
      	wrapper_state = 2'b10;
      end
    end else if (wrapper_state == 2'b10) begin  // ALU operation
      if (se_imd_val_we_o == 2'b00) begin
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
    .operand_b_i           (operand_b_i),
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
    .op_i		   (),                      // INPUT: crypto operation to execute
    //.key_valid_i	   (),          	    // INPUT: assert this signal to transfer a key value to the SIMON core
    //.key_i		   (), 		       	    // INPUT: SIMON key to expand
    .data_valid_i	   (data_valid_i),      	            // INPUT: assert this signal to transfer a data value to the SIMON core
    .data_i		   (simon_a_data_i),    		    // INPUT: SIMON data input
    .data_valid_o	   (),       	            // OUTPUT: this signal is asserted to indicate that an output valid is available
    .data_o		   (),    		    // OUTPUT: SIMON core data output
    .ready_o   		   ()
  );
  
  simon_core #(
    .SIMON_KEY_W(64),
    .SIMON_DATA_W(32),
    .SIMON_ROUNDS(7'b0000001),
    .SIMON_ROUNDS_PER_CYCLE(7'b0000001);
  ) simon_two_i (
    .clk		   (clk_i),                      // system clock signal
    .rst		   (~rst_ni),                      // system reset signal, asserted high
    .op_i		   (),                      // INPUT: crypto operation to execute
    //.key_valid_i	   (),          	    // INPUT: assert this signal to transfer a key value to the SIMON core
    //.key_i		   (), 		       	    // INPUT: SIMON key to expand
    .data_valid_i	   (data_valid_i),      	            // INPUT: assert this signal to transfer a data value to the SIMON core
    .data_i		   (operand_b_i),    		    // INPUT: SIMON data input
    .data_valid_o	   (),       	            // OUTPUT: this signal is asserted to indicate that an output valid is available
    .data_o		   (),    		    // OUTPUT: SIMON core data output
    .ready_o   		   ()
  );
  
endmodule
