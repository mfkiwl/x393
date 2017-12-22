/*!
 * <b>Module:</b> mclt_bayer_fold
 * @file mclt_bayer_fold.v
 * @date 2017-12-21  
 * @author eyesis
 *     
 * @brief Generate addresses and windows to fold MCLT Bayer data
 *
 * @copyright Copyright (c) 2017 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 *
 * <b>License </b>
 *
 * mclt_bayer_fold.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mclt_bayer_fold.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 */
`timescale 1ns/1ps

module  mclt_bayer_fold#(
    parameter SHIFT_WIDTH =      7, // bits in shift (7 bits - fractional)
    parameter PIX_ADDR_WIDTH =   9, // number of pixel address width
//    parameter EXT_PIX_LATENCY =  2, // external pixel buffer a->d latency
    parameter ADDR_DLY =        4'h2, // extra delay of pixel address to match window delay
    parameter COORD_WIDTH =     10, // bits in full coordinate 10 for 18K RAM
    parameter PIXEL_WIDTH =     16, // input pixel width (unsigned) 
    parameter WND_WIDTH =       18, // input pixel width (unsigned) 
    parameter OUT_WIDTH =       25, // bits in dtt output
    parameter DTT_IN_WIDTH =    25, // bits in DTT input
    parameter TRANSPOSE_WIDTH = 25, // width of the transpose memory (intermediate results)    
    parameter OUT_RSHIFT =       2, // overall right shift of the result from input, aligned by MSB (>=3 will never cause saturation)
    parameter OUT_RSHIFT2 =      0, // overall right shift for the second (vertical) pass
    parameter DSP_B_WIDTH =     18, // signed, output from sin/cos ROM
    parameter DSP_A_WIDTH =     25,
    parameter DSP_P_WIDTH =     48,
    parameter DEAD_CYCLES =     14  // start next block immedaitely, or with longer pause
)(
    input                             clk,          //!< system clock, posedge
    input                             rst,          //!< sync reset
    input                             start,        //!< start convertion of the next 256 samples
    input                       [1:0] tile_size,    //!< o: 16x16, 1 - 18x18, 2 - 20x20, 3 - 22x22 (max for 9-bit addr)
    input                             inv_checker,  //!< 0 - includes main diagonal (symmetrical DTT), 1 - antisymmetrical DTT
    input                       [7:0] top_left,     //!< index of the 16x16 top left corner
    input                       [1:0] valid_rows,   //!< 3 for green, 1 or 2 for R/B - which of the even/odd checker rows contain pixels
    input           [SHIFT_WIDTH-1:0] x_shft,       //!< tile pixel X fractional shift (valid @ start) 
    input           [SHIFT_WIDTH-1:0] y_shft,       //!< tile pixel Y fractional shift (valid @ start)
    
    output       [PIX_ADDR_WIDTH-1:0] pix_addr,     //!< external pixel buffer address
    output                            pix_re,       //!< pixel read enable (sync with  mpixel_a)
    output                            pix_page,     //!< copy pixel page (should be externally combined with first color)
    output signed     [WND_WIDTH-1:0] window,       //!< msb==0, always positive
    output                      [1:0] signs,        //!< bit 0: sign to add to dtt-cc input, bit 1: sign to add to dtt-cs input
    output                     [14:0] phases,        //!< other signals
    output reg                        var_first  
);
    reg                         [6:0] in_cntr;      // input phase counter
    reg                        [14:0] run_r;        // run phase
    reg                         [1:0] tile_size_r;  // 0: 16x16, 1 - 18x18, 2 - 20x20, 3 - 22x22 (max for 9-bit addr)
    reg                               inv_checker_r;// 0 - includes main diagonal (symmetrical DTT), 1 - antisymmetrical DTT
    reg                         [7:0] top_left_r0;  // index of the 16x16 top left corner
    reg                         [7:0] top_left_r;   // index of the 16x16 top left corner
    reg                         [1:0] valid_rows_r0;// 3 for green, 1 or 2 for R/B - which of the even/odd checker rows contain pixels
    reg                         [1:0] valid_rows_r ;// correct latency for window rom
    reg             [SHIFT_WIDTH-1:0] x_shft_r0;    // tile pixel X fractional shift (valid @ start) 
    reg             [SHIFT_WIDTH-1:0] y_shft_r0;    // tile pixel Y fractional shift (valid @ start)
    reg             [SHIFT_WIDTH-1:0] x_shft_r;     // matching delay 
    reg             [SHIFT_WIDTH-1:0] y_shft_r;     // matching delay
    wire                       [17:0] fold_rom_out;

    // does not have enough bits for pixel address (9) and window address(8), restoring MSB of pixel address from both MSBc
    wire                        [7:0] wnd_a_w =   fold_rom_out[7:0];
    wire         [PIX_ADDR_WIDTH-1:0] pix_a_w =   {~fold_rom_out[15] & fold_rom_out[7],fold_rom_out[15:8]};
    reg          [PIX_ADDR_WIDTH-1:0] pix_a_r;
    wire                       [ 1:0] sgn_w =     fold_rom_out[16 +: 2];
    reg                               blank_r;    // blank window (latency 1 from fold_rom_out)
//    wire                              blank_d;    //  delayed to matchwindow rom regrst
    wire                              pre_page =  in_cntr == 2; // valid 1 cycle before fold_rom_out
    
    wire                              var_first_d; // adding subtracting first variant of 2 folds    
    
    assign phases = run_r;
    
//    wire           [ 3:0] bayer_1hot = { mpix_a_w[4] &  mpix_a_w[0],  
//                                        mpix_a_w[4] & ~mpix_a_w[0],
//                                        ~mpix_a_w[4] &  mpix_a_w[0],
//                                        ~mpix_a_w[4] & ~mpix_a_w[0]};
                                        
//    wire                          mpix_use = |(bayer_d & bayer_1hot); //not disabled by bayer, valid with mpix_a_w
//    wire                          mpix_use_d; // delayed
//    reg                           mpix_use_r; // delayed

   
    always @ (posedge clk) begin
        if (rst) run_r <= 0;
        else     run_r <= {run_r[13:0], start | (run_r[0] & ~(&in_cntr[6:0]))};
        
        if (!run_r[0]) in_cntr <= 0;
        else           in_cntr <= in_cntr + 1;
        
        if (start) begin
            tile_size_r <=   tile_size;
            inv_checker_r<=  inv_checker;
            top_left_r0 <=   top_left;
            valid_rows_r0 <= valid_rows;
            x_shft_r0 <=     x_shft;
            y_shft_r0 <=     y_shft;
        end
        
        if (in_cntr == 1) top_left_r <=top_left_r0;
        
        if (in_cntr == 1) begin
            x_shft_r <= x_shft_r0;
            y_shft_r <= y_shft_r0;
        end
            

        if (run_r[2]) pix_a_r <= pix_a_w + {1'b0, top_left_r};
        

        if (in_cntr == 2) valid_rows_r <= valid_rows_r0;
        
        blank_r <= ~(wnd_a_w[0] ? valid_rows_r[1]: valid_rows_r[0]);  
        
        if (run_r[10]) begin
            var_first <= var_first_d;
        end
         
    end

     ram18tp_var_w_var_r #(
        .REGISTERS_A(1),
        .REGISTERS_B(1),
        .LOG2WIDTH_A(4),
        .LOG2WIDTH_B(4)
`ifdef PRELOAD_BRAMS
    `include "mclt_bayer_fold_rom.vh"
`endif
    ) i_mclt_fold_rom (
    
        .clk_a     (clk),          // input
        .addr_a    ({tile_size_r,inv_checker_r, in_cntr[0],in_cntr[6:1]}),    // input[9:0] 
        .en_a      (run_r[0]),     // input
        .regen_a   (run_r[1]),     // input
        .we_a      (1'b0),         // input
        .data_out_a(fold_rom_out), // output[17:0] 
        .data_in_a (18'b0),        // input[17:0]
        // port B may be used for other mclt16x16 
        .clk_b     (1'b0),         // input
        .addr_b    (10'b0),        // input[9:0] 
        .en_b      (1'b0),         // input
        .regen_b   (1'b0),         // input
        .we_b      (1'b0),         // input
        .data_out_b(),             // output[17:0] 
        .data_in_b (18'b0)         // input[17:0] 
    );

// Matching window latency with pixel data latency
    dly_var #(
        .WIDTH(11),
        .DLY_WIDTH(4)
    ) dly_pixel_addr_i (
        .clk  (clk),      // input
        .rst  (rst),      // input
        .dly  (4'h2),     // input[3:0] Delay for external memory latency = 2, reduce for higher 
        .din  ({pre_page, run_r[3], pix_a_r}), // input[0:0] 
        .dout ({pix_page,   pix_re, pix_addr}) // output[0:0] 
    );

/*
    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_blank_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h0),          // TODO: put correct value! 
        
        
         
        .din  (blank_r),  // input[0:0] 
        .dout (blank_d)   // output[0:0] 
    );
*/
// Latency = 6
    mclt_wnd_mul #(
        .SHIFT_WIDTH (SHIFT_WIDTH),
        .COORD_WIDTH (COORD_WIDTH),
        .OUT_WIDTH   (WND_WIDTH)
    ) mclt_wnd_i (
        .clk       (clk), // input
        .en        (run_r[2]), // input
        .x_in      (wnd_a_w[3:0]), // input[3:0] 
        .y_in      (wnd_a_w[7:4]), // input[3:0] 
        .x_shft    (x_shft_r),     // input[7:0] 
        .y_shft    (y_shft_r),     // input[7:0]
        .zero_in   (blank_r),      // input 2 cycles after inputs! 
        .wnd_out   (window)        // output[17:0] valid with in_busy[8]
    );

    dly_var #(
        .WIDTH(2),
        .DLY_WIDTH(4)
    ) dly_signs_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h5),        // TODO: put correct value! 
        .din  (sgn_w),  // input[0:0] 
        .dout (signs)   // output[0:0] 
    );

    dly_var #(
        .WIDTH(1),
        .DLY_WIDTH(4)
    ) dly_var_first_i (
        .clk  (clk),           // input
        .rst  (rst),           // input
        .dly  (4'h9),          // input[3:0] 
        .din  (run_r[0] && (in_cntr[0] == 0)),  // input[0:0] 
        .dout (var_first_d)    // output[0:0] 
    );

    
//
endmodule
