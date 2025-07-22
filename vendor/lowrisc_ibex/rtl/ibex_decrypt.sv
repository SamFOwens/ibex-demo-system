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

  logic dec_finished;
  logic [31:0] simon_a_data_i = dec_finished ? se_result_o : operand_a_i;
  
  logic [1:0] internal_se_alu_imd_val_we; // Keeps track of whether the ALU is done with its operation

  se_imd_val_we_o = {~dec_finished, ~enc_finished} | internal_se_alu_imd_val_we; // Keeps track of whether either Keyexpand is done or the appropriate decrypt + alu op combo is done (I think this works when dec and enc_finished are implemented)

  logic data_valid_i;
  
  data_valid_i = 1'b1;

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

//
// lint options for Verilator
//
/* verilator lint_off DECLFILENAME */

//------------------ SIMON DEFINES -------------------------------
`define true  1'b1
`define false 1'b0

//
// SIMON_CORE: This is a test driver module used by tb_simon_core.cpp
//
module simon_core #(
   parameter int unsigned SIMON_KEY_W,            // SIMON key size (in bits), 64 and 128-bits are supported
   parameter int unsigned SIMON_DATA_W,           // SIMON data size (in bits), 32, 64, and 128-bits are supported
   parameter bit [6:0] SIMON_ROUNDS,              // SIMON rounds to execute during encryption/decryption
   parameter bit [6:0] SIMON_ROUNDS_PER_CYCLE     // SIMON rounds to execute each cycle, leading to pipelined implementations
) (
    input  logic        clk,                      // system clock signal
    input  logic        rst,                      // system reset signal, asserted high
    input  simon_op_e   op_i,                     // INPUT: crypto operation to execute
    input  logic        key_valid_i,              // INPUT: assert this signal to transfer a key value to the SIMON core
    input  logic [7:0]  key_i [0:(SIMON_KEY_W/8)-1], // INPUT: SIMON key to expand
    input  logic        data_valid_i,             // INPUT: assert this signal to transfer a data value to the SIMON core
    input  logic [SIMON_DATA_W-1:0] data_i,       // INPUT: SIMON data input
    output logic        data_valid_o,             // OUTPUT: this signal is asserted to indicate that an output valid is available
    output logic [SIMON_DATA_W-1:0] data_o,       // OUTPUT: SIMON core data output
    output logic        ready_o                   // OUTPUT: asserted when the SIMON core is ready for a new request

);
  logic [(SIMON_DATA_W/2)-1:0] keytab[0:SIMON_ROUNDS - 1];
  logic keytab_valid_o, enc_valid_o, dec_valid_o;
  logic keyexpand_ready_o, enc_ready_o, dec_ready_o;
  logic [SIMON_DATA_W-1:0] enc_data_o;
  logic [SIMON_DATA_W-1:0] dec_data_o;


  simon_core_encryptor #(
  .SIMON_DATA_W           (SIMON_DATA_W),
  .SIMON_ROUNDS           (SIMON_ROUNDS),
  .SIMON_ROUNDS_PER_CYCLE (SIMON_ROUNDS_PER_CYCLE)
  ) encryptor_inst (
   .clk               (clk),
   .rst               (rst),
   .data_valid_i      (data_valid_i),
   .data_i            (data_i),
   .keytab_i          (keytab),
   .data_valid_o      (enc_valid_o),
   .data_o            (enc_data_o),
   .ready_o           (enc_ready_o)
  );

  simon_core_decryptor #(
  .SIMON_DATA_W           (SIMON_DATA_W),
  .SIMON_ROUNDS           (SIMON_ROUNDS),
  .SIMON_ROUNDS_PER_CYCLE (SIMON_ROUNDS_PER_CYCLE)
  ) decryptor_inst (
   .clk               (clk),
   .rst               (rst),
   .data_valid_i      (data_valid_i),
   .data_i            (data_i),
   .keytab_i          (keytab),
   .data_valid_o      (dec_valid_o),
   .data_o            (dec_data_o),
   .ready_o           (dec_ready_o)
  );

  assign data_valid_o = enc_valid_o | dec_valid_o;
  assign ready_o = enc_ready_o & dec_ready_o;

  always_comb begin
    unique case (op_i)
      SIMON_IDLE,
      SIMON_KEYEXPAND:    data_o = 0;
      SIMON_ENCRYPT:      data_o = enc_data_o;
      SIMON_DECRYPT:      data_o = dec_data_o;
      default:            data_o = 0;
    endcase
  end

endmodule;

module simon_core_encryptor #(
   parameter int unsigned SIMON_DATA_W,
   parameter bit [6:0] SIMON_ROUNDS,
   parameter bit [6:0] SIMON_ROUNDS_PER_CYCLE
) (
   input  logic        clk,
   input  logic        rst,
   input  logic        data_valid_i,
   input  logic [SIMON_DATA_W-1:0] data_i,
   input  logic [(SIMON_DATA_W/2)-1:0] keytab_i[0:SIMON_ROUNDS - 1],
   output logic        data_valid_o,
   output logic [SIMON_DATA_W-1:0] data_o,
   output logic        ready_o
);
  typedef logic [$clog2(SIMON_ROUNDS_PER_CYCLE+1)-1:0] xy_idx_t;

  logic [(SIMON_DATA_W/2)-1:0] y_words[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic [(SIMON_DATA_W/2)-1:0] x_words[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic [(SIMON_DATA_W/2)-1:0] y_ff;
  logic [(SIMON_DATA_W/2)-1:0] x_ff;
  logic [(SIMON_DATA_W/2)-1:0] temp[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic ready_q;
  logic [SIMON_DATA_W-1:0] data_q;
  logic [6:0] roundCount_q;
  logic data_valid_q;

  assign data_valid_o  = data_valid_q;
  assign data_o = data_q;
  assign ready_o = ready_q;

  genvar i;
  generate
    assign x_words[0] = x_ff;
    assign y_words[0] = y_ff;

    for(i=0; i < SIMON_ROUNDS_PER_CYCLE; i++) begin : gencipher
      // Shift, AND, XOR ops
      // assign temp[i] = ((((x_words[i] << 1) | (x_words[i]
      //                       >> (`WORD_SIZE - 1))) & ((x_words[i] << 8) | (x_words[i]
      //                       >> (`WORD_SIZE - 8))))  ^ y_words[i] ^ ((x_words[i] << 2)
      //                       | (x_words[i] >> (`WORD_SIZE - 2))));
      assign temp[i] = (({x_words[i][(SIMON_DATA_W/2)-2:0], x_words[i][(SIMON_DATA_W/2)-1]}
                         & {x_words[i][(SIMON_DATA_W/2)-9:0], x_words[i][(SIMON_DATA_W/2)-1:(SIMON_DATA_W/2)-8]})
                        ^ y_words[i]
                        ^ {x_words[i][(SIMON_DATA_W/2)-3:0], x_words[i][(SIMON_DATA_W/2)-1:(SIMON_DATA_W/2)-2]});
      // Feistel Cross
      assign y_words[i + 1] = x_words[i];
      // XOR with round key
      assign x_words[i + 1] = temp[i] ^ keytab_i[roundCount_q + i];
    end
  endgenerate

  always_ff @(posedge clk) begin

    // STATE: handle reset
    if (rst) begin
      ready_q <= `true;
      data_valid_q  <= `false;
      roundCount_q <= 0;
      y_ff <= 0;
      x_ff <= 0;
      data_q <= 0;
    end

    // STATE: new request, so latch input
    else if (ready_q && data_valid_i) begin
      ready_q <= `false;
      x_ff <= data_i[SIMON_DATA_W-1:(SIMON_DATA_W/2)];
      y_ff <= data_i[(SIMON_DATA_W/2)-1:0];
      roundCount_q <= 0;
    end

    // STATE: ongoing key expansion and not the last iteration
    else if (!ready_q && !data_valid_q) begin

      // SUBSTATE: not the last iteration, still have work to do -- perform an intermediate latch now
      /* verilator lint_off UNSIGNED */
      if ((((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) == 0) && roundCount_q < SIMON_ROUNDS - SIMON_ROUNDS_PER_CYCLE)
          || (((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) != 0) && roundCount_q < SIMON_ROUNDS - (SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE))) begin
      /* verilator lint_on UNSIGNED */
        roundCount_q <= roundCount_q + SIMON_ROUNDS_PER_CYCLE;
        y_ff <= y_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)];
        x_ff <= x_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)];
      end

      // SUBSTATE: finishing up the short tail; latch from tail and set output to valid
      else if ((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) != 0) begin
        data_valid_q <= `true;
        data_q <= {x_words[xy_idx_t'(SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE)], y_words[xy_idx_t'(SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE)]};
        // cleanup internal state
        roundCount_q <= 0;
        y_ff <= 0;
        x_ff <= 0;
      end

      // SUBSTATE: finishing up with no perfect-multiple tail; latch from body and set output to valid
      else if ((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) == 0) begin
        data_valid_q <= `true;
        data_q <= {x_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)], y_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)]};
        // cleanup internal state
        roundCount_q <= 0;
        y_ff <= 0;
        x_ff <= 0;
      end

    end

    // STATE: output has been delivered and we can reset everything
    else if (!ready_q && data_valid_q) begin
      // output has been latched and we can reset everything
      ready_q <= `true;
      data_valid_q  <= `false;
      roundCount_q <= 0;
      y_ff <= 0;
      x_ff <= 0;
    end

  end
endmodule

module simon_core_decryptor #(
   parameter int unsigned SIMON_DATA_W,
   parameter bit [6:0] SIMON_ROUNDS,
   parameter bit [6:0] SIMON_ROUNDS_PER_CYCLE
) (
   input  logic  clk,
   input  logic  rst,
   input  logic  data_valid_i,
   input  logic  [SIMON_DATA_W-1:0] data_i,
   input  logic  [(SIMON_DATA_W/2)-1:0] keytab_i[0:SIMON_ROUNDS - 1],
   output logic  data_valid_o,
   output logic  [SIMON_DATA_W-1:0] data_o,
   output logic  ready_o
);
  typedef logic [$clog2(SIMON_ROUNDS_PER_CYCLE+1)-1:0] xy_idx_t;

  logic [(SIMON_DATA_W/2)-1:0] y_words[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic [(SIMON_DATA_W/2)-1:0] x_words[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic [(SIMON_DATA_W/2)-1:0] y_ff;
  logic [(SIMON_DATA_W/2)-1:0] x_ff;
  logic [(SIMON_DATA_W/2)-1:0] temp[0:SIMON_ROUNDS_PER_CYCLE]  /*verilator split_var*/;
  logic ready_q;
  logic [SIMON_DATA_W-1:0] data_q;
  logic [6:0] roundCount_q;
  logic data_valid_q;

  assign data_valid_o = data_valid_q;
  assign data_o = data_q;
  assign ready_o = ready_q;

  genvar i;
  generate
    assign x_words[0] = x_ff;
    assign y_words[0] = y_ff;

    for(i=0; i < SIMON_ROUNDS_PER_CYCLE; i++) begin : gencipher
      // Shift, AND, XOR ops
      // TMA: assign temp[i] = ((((x_words[i] << 1) | (x_words[i]
      //                       >> (`WORD_SIZE - 1))) & ((x_words[i] << 8) | (x_words[i]
      //                       >> (`WORD_SIZE - 8))))  ^ y_words[i] ^ ((x_words[i] << 2)
      //                       | (x_words[i] >> (`WORD_SIZE - 2))));
      assign temp[i] = (({x_words[i][(SIMON_DATA_W/2)-2:0], x_words[i][(SIMON_DATA_W/2)-1]}
                         & {x_words[i][(SIMON_DATA_W/2)-9:0], x_words[i][(SIMON_DATA_W/2)-1:(SIMON_DATA_W/2)-8]})
                        ^ y_words[i]
                        ^ {x_words[i][(SIMON_DATA_W/2)-3:0], x_words[i][(SIMON_DATA_W/2)-1:(SIMON_DATA_W/2)-2]});
      // Feistel Cross
      assign y_words[i + 1] = x_words[i];
      // XOR with round key
      assign x_words[i + 1] = temp[i] ^ keytab_i[(SIMON_ROUNDS - i - 1) - roundCount_q];
    end
  endgenerate

  always_ff @(posedge clk) begin

    // STATE: handle reset
    if (rst) begin
      ready_q <= `true;
      data_valid_q <= `false;
      roundCount_q <= 0;
      y_ff <= 0;
      x_ff <= 0;
      data_q <= 0;
    end

    // STATE: new request, so latch input
    else if (ready_q && data_valid_i) begin
      ready_q <= `false;
      y_ff <= data_i[SIMON_DATA_W-1:(SIMON_DATA_W/2)];
      x_ff <= data_i[(SIMON_DATA_W/2)-1:0];
      roundCount_q <= 0;
    end

    // STATE: ongoing key expansion and not the last iteration
    else if (!ready_q && !data_valid_q) begin

      // SUBSTATE: not the last iteration, still have work to do -- perform an intermediate latch now
      /* verilator lint_off UNSIGNED */
      if ((((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) == 0) && roundCount_q < SIMON_ROUNDS - SIMON_ROUNDS_PER_CYCLE)
          || (((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) != 0) && roundCount_q < SIMON_ROUNDS - (SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE))) begin
      /* verilator lint_on UNSIGNED */
        roundCount_q <= roundCount_q + SIMON_ROUNDS_PER_CYCLE;
        y_ff <= y_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)];
        x_ff <= x_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)];
      end

      // SUBSTATE: finishing up the short tail; latch from tail and set output to valid
      else if ((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) != 0) begin
        // Finishing up the tail; latch from tail and set output to valid
        data_valid_q <= `true;
        data_q <= {y_words[xy_idx_t'(SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE)], x_words[xy_idx_t'(SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE)]};
        // cleanup internal state
        roundCount_q <= 0;
        y_ff <= 0;
        x_ff <= 0;
      end

      // SUBSTATE: finishing up with no perfect-multiple tail; latch from body and set output to valid
      else if ((SIMON_ROUNDS % SIMON_ROUNDS_PER_CYCLE) == 0) begin
        data_valid_q <= `true;
        data_q <= {y_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)], x_words[xy_idx_t'(SIMON_ROUNDS_PER_CYCLE)]};
        // cleanup internal state
        roundCount_q <= 0;
        y_ff <= 0;
        x_ff <= 0;
      end

    end

    // STATE: output has been delivered and we can reset everything
    else if (!ready_q && data_valid_q) begin
      ready_q <= `true;
      data_valid_q <= `false;
      roundCount_q <= 0;
      y_ff <= 0;
      x_ff <= 0;
    end

  end
endmodule
