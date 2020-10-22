// SPDX-License-Identifier: Apache-2.0
// Copyright 2019-2020 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//********************************************************************************
// $Id$
//
// Function: SweRVolf SoC-level controller
// Comments:
//
//********************************************************************************

`default_nettype none

module swervolf_syscon
  (input wire i_clk,
   input wire 	     i_rst,
   output reg 	     o_timer_irq,
   output wire 	     o_sw_irq3,
   output wire 	     o_sw_irq4,
   input wire 	     i_ram_init_done,
   input wire 	     i_ram_init_error,
   output reg [31:0] o_nmi_vec,
   output wire 	     o_nmi_int,

   input wire [5:0]  i_wb_adr,
   input wire [31:0] i_wb_dat,
   input wire [3:0]  i_wb_sel,
   input wire 	     i_wb_we,
   input wire 	     i_wb_cyc,
   input wire 	     i_wb_stb,
   output reg [31:0] o_wb_rdt,
   output reg 	     o_wb_ack,
   
   output wire [ 7          :0] AN,
   output wire [ 7          :0] Digits_Bits);

   reg [63:0] 	      mtime;
   reg [63:0] 	      mtimecmp;

   reg 		 sw_irq3;
   reg 		 sw_irq3_edge;
   reg 		 sw_irq3_pol;
   reg 		 sw_irq3_timer;
   reg 		 sw_irq4;
   reg 		 sw_irq4_edge;
   reg 		 sw_irq4_pol;
   reg 		 sw_irq4_timer;

   reg 		 irq_timer_en;
   reg [31:0] 	 irq_timer_cnt;

   reg 		 nmi_int;
   reg 		 nmi_int_r;

`ifdef SIMPRINT
   reg [1023:0]  signature_file;
   integer 	f = 0;
   initial begin
      if ($value$plusargs("signature=%s", signature_file)) begin
	 $display("Writing signature to %0s", signature_file);
	 f = $fopen(signature_file, "w");
      end
   end
`endif

`ifndef VERSION_DIRTY
 `define VERSION_DIRTY 1
`endif
`ifndef VERSION_MAJOR
 `define VERSION_MAJOR 255
`endif
`ifndef VERSION_MINOR
 `define VERSION_MINOR 255
`endif
`ifndef VERSION_REV
 `define VERSION_REV 255
`endif
`ifndef VERSION_SHA
 `define VERSION_SHA deadbeef
`endif

   wire [31:0] version;

   assign version[31]    = `VERSION_DIRTY;
   assign version[30:24] = 7'd0;
   assign version[23:16] = `VERSION_MAJOR;
   assign version[15: 8] = `VERSION_MINOR;
   assign version[ 7: 0] = `VERSION_REV;

   assign o_sw_irq4 = sw_irq4^sw_irq4_pol;
   assign o_sw_irq3 = sw_irq3^sw_irq3_pol;

   assign o_nmi_int = nmi_int | nmi_int_r;

   wire reg_we = i_wb_cyc & i_wb_stb & i_wb_we & !o_wb_ack;

   //00 = ver
   //04 = sha
   //08 = simprint
   //09 = simexit
   //0A = RAM status
   //0B = sw_irq
   //10 = gpio
   //20 = timer/timecmp
   //40 = SPI
   always @(posedge i_clk) begin
      o_wb_ack <= i_wb_cyc & !o_wb_ack;

      if (sw_irq3_edge)
	sw_irq3 <= 1'b0;
      if (sw_irq4_edge)
	sw_irq4 <= 1'b0;

      if (irq_timer_en)
	irq_timer_cnt <= irq_timer_cnt - 1;

      nmi_int   <= 1'b0;
      nmi_int_r <= nmi_int;

      if (irq_timer_cnt == 32'd1) begin
	 irq_timer_en <= 1'b0;
	 if (sw_irq3_timer)
	   sw_irq3 <= 1'b1;
	 if (sw_irq4_timer)
	   sw_irq4 <= 1'b1;
	 if (!(sw_irq3_timer | sw_irq4_timer))
	   nmi_int <= 1'b1;
      end

      if (reg_we)
	case (i_wb_adr[5:2])
	  2: begin //0x08-0x0B
`ifdef SIMPRINT
	     if (i_wb_sel[0]) begin
		$fwrite(f, "%c", i_wb_dat[7:0]);
		$write("%c", i_wb_dat[7:0]);
	     end
	     if (i_wb_sel[1]) begin
		$display("\nFinito");
		$finish;
	     end
`endif
	     if (i_wb_sel[3]) begin
		sw_irq4       <= i_wb_dat[31];
		sw_irq4_edge  <= i_wb_dat[30];
		sw_irq4_pol   <= i_wb_dat[29];
		sw_irq4_timer <= i_wb_dat[28];
		sw_irq3       <= i_wb_dat[27];
		sw_irq3_edge  <= i_wb_dat[26];
		sw_irq3_pol   <= i_wb_dat[25];
		sw_irq3_timer <= i_wb_dat[24];
	     end
	  end
	  3: begin //0x0C-0x0F
	     if (i_wb_sel[0]) o_nmi_vec[7:0]   <= i_wb_dat[7:0];
	     if (i_wb_sel[1]) o_nmi_vec[15:8]  <= i_wb_dat[15:8];
	     if (i_wb_sel[2]) o_nmi_vec[23:16] <= i_wb_dat[23:16];
	     if (i_wb_sel[3]) o_nmi_vec[31:24] <= i_wb_dat[31:24];
	  end
	  10 : begin //0x28-0x2B
	     if (i_wb_sel[0]) mtimecmp[7:0]   <= i_wb_dat[7:0];
	     if (i_wb_sel[1]) mtimecmp[15:8]  <= i_wb_dat[15:8];
	     if (i_wb_sel[2]) mtimecmp[23:16] <= i_wb_dat[23:16];
	     if (i_wb_sel[3]) mtimecmp[31:24] <= i_wb_dat[31:24];
	  end
	  11 : begin //0x2C-0x2F
	     if (i_wb_sel[0]) mtimecmp[39:32] <= i_wb_dat[7:0];
	     if (i_wb_sel[1]) mtimecmp[47:40] <= i_wb_dat[15:8];
	     if (i_wb_sel[2]) mtimecmp[55:48] <= i_wb_dat[23:16];
	     if (i_wb_sel[3]) mtimecmp[63:56] <= i_wb_dat[31:24];
	  end
	  12 : begin //0x30-3f
	     if (i_wb_sel[0]) irq_timer_cnt[7:0]   <= i_wb_dat[7:0]  ;
	     if (i_wb_sel[1]) irq_timer_cnt[15:8]  <= i_wb_dat[15:8] ;
	     if (i_wb_sel[2]) irq_timer_cnt[23:16] <= i_wb_dat[23:16];
	     if (i_wb_sel[3]) irq_timer_cnt[31:24] <= i_wb_dat[31:24];
	  end
	  13 : begin
	     if (i_wb_sel[0])
	       irq_timer_en <= i_wb_dat[0];
	  end
	  14 : begin
	  	 if (i_wb_sel[0]) Enables_Reg[7:0]  <= i_wb_dat[7:0];
	  end
	  15 : begin
         if (i_wb_sel[0]) Digits_Reg[7:0]   <= i_wb_dat[7:0];
         if (i_wb_sel[1]) Digits_Reg[15:8]  <= i_wb_dat[15:8];
         if (i_wb_sel[2]) Digits_Reg[23:16] <= i_wb_dat[23:16];
         if (i_wb_sel[3]) Digits_Reg[31:24] <= i_wb_dat[31:24];
	  end
	endcase

      case (i_wb_adr[5:2])
	//0x00-0x03
	0 : o_wb_rdt <= version;
	//0x04-0x07
	1 : o_wb_rdt <= 32'h`VERSION_SHA;
	//0x08-0x0C
	2 : begin
	   //0xB
	   o_wb_rdt[31:28] <= {sw_irq4, sw_irq4_edge, sw_irq4_pol, sw_irq4_timer};
	   o_wb_rdt[27:24] <= {sw_irq3, sw_irq3_edge, sw_irq3_pol, sw_irq3_timer};
	   //0xA
	   o_wb_rdt[23:18] <= 6'd0;
	   o_wb_rdt[17:16] <= {i_ram_init_error, i_ram_init_done};
	   //0x8-0x9
	   o_wb_rdt[15:0]  <= 16'd0;
	end
	//0xC-0xF
	3 : o_wb_rdt <= o_nmi_vec;
	//0x20-0x23
	8 : o_wb_rdt <= mtime[31:0];
	//0x24-0x27
	9 : o_wb_rdt <= mtime[63:32];
	//0x28-0x2B
	10 : o_wb_rdt <= mtimecmp[31:0];
	//0x2C-0x2F
	11 : o_wb_rdt <= mtimecmp[63:32];
	//0x30-0x33
	12 : o_wb_rdt <= irq_timer_cnt;
	//0x34-0x37
	13 : o_wb_rdt <= {31'd0, irq_timer_en};
      endcase

      mtime <= mtime + 64'd1;
      o_timer_irq <= (mtime >= mtimecmp);

      if (i_rst) begin
	 mtime <= 64'd0;
	 mtimecmp <= 64'd0;
	 o_wb_ack <= 1'b0;
      end
   end



	// Eight-Digit 7 Segment Displays

	  reg  [ 7:0]  Enables_Reg;
	  reg  [31:0]  Digits_Reg;

	  SevSegDisplays_Controller SegDispl_Ctr(
	    .clk               (i_clk),    
	    .rst_n             (i_rst),
	    .Enables_Reg       (Enables_Reg), 
	    .Digits_Reg        (Digits_Reg), 
	    .AN                (AN),
	    .Digits_Bits       (Digits_Bits)
	  );

endmodule




parameter COUNT_MAX = 20;

module SevSegDisplays_Controller(
                     input wire           clk,
                     input wire           rst_n,
                     input wire    [ 7:0] Enables_Reg,
                     input wire    [31:0] Digits_Reg,
                     output wire   [ 7:0] AN,
                     output wire   [ 7:0] Digits_Bits);

  wire [(COUNT_MAX-1):0] countSelection;
  wire [ 3:0] DecNumber;
  wire overflow_o_count;

    // SevenSegDecoder SevSegDec(.data(DecNumber), .seg(Digits_Bits));
    SevenSegDecoder SevSegDec(
        .data(DecNumber), 
        .seg(Digits_Bits),
        .SEL(countSelection[(COUNT_MAX-1):(COUNT_MAX-3)])
    );

  counter #(COUNT_MAX)  counter20(clk, ~rst_n, 1'b0, 1'b1, 1'b0, 1'b0, 16'b0, countSelection, overflow_o_count);

  wire [ 7:0] [7:0] enable;

  assign enable[0] = (Enables_Reg | 8'hfe);
  assign enable[1] = (Enables_Reg | 8'hfd);
  assign enable[2] = (Enables_Reg | 8'hfb);
  assign enable[3] = (Enables_Reg | 8'hf7);
  assign enable[4] = (Enables_Reg | 8'hef);
  assign enable[5] = (Enables_Reg | 8'hdf);
  assign enable[6] = (Enables_Reg | 8'hbf);
  assign enable[7] = (Enables_Reg | 8'h7f);

  SevSegMux
  #(
    .DATA_WIDTH(8),
    .N_IN(8)
  )
  Select_Enables
  (
    .IN_DATA(enable),
    .OUT_DATA(AN),
    .SEL(countSelection[(COUNT_MAX-1):(COUNT_MAX-3)])
  );


  wire [ 7:0] [3:0] digits_concat;

// replaced with BCD values
  // assign digits_concat[0] = Digits_Reg[3:0];
  // assign digits_concat[1] = Digits_Reg[7:4];
  // assign digits_concat[2] = Digits_Reg[11:8];
  // assign digits_concat[3] = Digits_Reg[15:12];
  // assign digits_concat[4] = Digits_Reg[19:16];
  // assign digits_concat[5] = Digits_Reg[23:20];
  // assign digits_concat[6] = Digits_Reg[27:24];
  // assign digits_concat[7] = Digits_Reg[31:28];
  
    wire [31:0] bcd_reg;
    BCD bcd(Digits_Reg,bcd_reg);
    
  assign digits_concat[0] = bcd_reg[3:0];
  assign digits_concat[1] = bcd_reg[7:4];
  assign digits_concat[2] = bcd_reg[11:8];
  assign digits_concat[3] = bcd_reg[15:12];
  assign digits_concat[4] = bcd_reg[19:16];
  assign digits_concat[5] = bcd_reg[23:20];
  assign digits_concat[6] = bcd_reg[27:24];
  assign digits_concat[7] = bcd_reg[31:28];

  SevSegMux
  #(
    .DATA_WIDTH(4),
    .N_IN(8)
  )
  Select_Digits
  (
    .IN_DATA(digits_concat),
    .OUT_DATA(DecNumber),
    .SEL(countSelection[(COUNT_MAX-1):(COUNT_MAX-3)])
  );

endmodule

// Binary coded decimal, convert hex to int10 digits
module BCD
#(
    parameter DIG=3
)
(
    input wire [31:0] Digits_Reg, 
    output wire [31:0] bcd_reg
);
    assign bcd_reg[31:(DIG*4)] = Digits_Reg[31:(DIG*4)];
    generate
        for (genvar i=0; i< DIG; i=i+1) begin
            assign bcd_reg[(i*4)+:4] = (Digits_Reg[0+:(DIG*4)]/(10**i))%10;
        end
    endgenerate
endmodule

module SevenSegDecoder(input wire     [3:0] data,
                    output reg [7:0] seg,
                    input  wire [5-1:0] SEL
                    );
    wire [2:0] seg1;
    wire dp;
    assign seg1 = data[3:1];
    assign dp = data[0];
  always @(*)
    case(SEL)
        3:      // motion indicator
        // case for single segment control of digit[3]
            // data format {3'b[seg1],1'b[dp]}
            case(seg1)
                          // abc_defg_(dp)
              3'h0: seg = {7'b011_1111,dp};  // a
              3'h1: seg = {7'b101_1111,dp};
              3'h2: seg = {7'b110_1111,dp};
              3'h3: seg = {7'b111_0111,dp};
              3'h4: seg = {7'b111_1011,dp};
              3'h5: seg = {7'b111_1101,dp};
              3'h6: seg = {7'b111_1110,dp};  // g
              default: 
                    seg = {7'b111_1111,dp};  // all off
            endcase
        
        default: begin      // normal 7seg digits
            case(data)
                          // abc_defg_(dp)
              4'h0: seg = 8'b000_0001_1;
              4'h1: seg = 8'b100_1111_1;
              4'h2: seg = 8'b001_0010_1;
              4'h3: seg = 8'b000_0110_1;
              4'h4: seg = 8'b100_1100_1;
              4'h5: seg = 8'b010_0100_1;
              4'h6: seg = 8'b010_0000_1;
              4'h7: seg = 8'b000_1111_1;
              4'h8: seg = 8'b000_0000_1;
              4'h9: seg = 8'b000_1100_1;
              4'ha: seg = 8'b000_1000_1;
              4'hb: seg = 8'b110_0000_1;
              4'hc: seg = 8'b111_0010_1;
              4'hd: seg = 8'b100_0010_1;
              4'he: seg = 8'b011_0000_1;
              4'hf: seg = 8'b011_1000_1;
              default: 
                    seg = 8'b111_1111_1;
            endcase
        end
    endcase
endmodule

module SevSegMux
#(
    parameter DATA_WIDTH = 64,
    parameter N_IN       = 16,
    parameter SEL_WIDTH  = $clog2(N_IN)
)
(
    input  wire [N_IN-1:0][DATA_WIDTH-1:0]   IN_DATA,
    output wire [DATA_WIDTH-1:0]             OUT_DATA,
    input  wire [SEL_WIDTH-1:0]              SEL
);


  assign OUT_DATA = IN_DATA[SEL];

endmodule
