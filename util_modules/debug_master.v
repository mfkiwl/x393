/*******************************************************************************
 * Module: debug_master
 * Date:2015-09-03  
 * Author: andrey     
 * Description: Debug master module to send/receive serial debug data
 *
 * Copyright (c) 2015 Elphel, Inc .
 * debug_master.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  debug_master.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  debug_master #(
        parameter DEBUG_ADDR =                 'h710, //..'h713
        parameter DEBUG_MASK =                 'h7fc,
        parameter DEBUG_STATUS_REG_ADDR =      'hfc,  // address where status can be read out 
        parameter DEBUG_READ_REG_ADDR =        'hfd,  // read 32-bit received shifted data
        parameter DEBUG_SHIFT_DATA =           'h0,   // shift i/o data by 32 bits
        parameter DEBUG_LOAD =                 'h1,   // parallel load of the distributed shift registe (both ways)
        parameter DEBUG_SET_STATUS =           'h2,    // program status (mode 3?)
        parameter DEBUG_CMD_LATENCY =          2 // >0 extra registers in the debug_sl (distriburted in parallel)
)(
    input       mclk,
    input       mrst,        // @ posedge mclk - sync reset
    // programming interface
    input  [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                         cmd_stb,     // strobe (with first byte) for the command a/d

    output [7:0] status_ad,    // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output       status_rq,    // input request to send status downstream
    input        status_start, // Acknowledge of the first status packet byte (address)
    
    // debug ring 
    output       debug_do,   // data out to the debug ring @posedge mclk, LSB first
    output       debug_sl,   // 0 - idle, (1,0) - shift, (1,1) - load
    input        debug_di    // input data from the debug ring, LSB first
);
    wire    [1:0] cmd_a;
    wire   [31:0] cmd_data;
    wire          cmd_we; 
    reg    [31:0] data_sr;
    reg           tgl;
    reg    [ 5:0] cntr;
    reg           ld_r;
    reg           cmd; //command stae (0 - idle)  
    reg [DEBUG_CMD_LATENCY : 0] cmd_reg;
    
    wire          set_status_w = cmd_we && (cmd_a == DEBUG_SET_STATUS);
    wire          shift32_w =    cmd_we && (cmd_a == DEBUG_SHIFT_DATA);
    wire          load_w =       cmd_we && (cmd_a == DEBUG_LOAD);
    wire          cmd_reg_dly = cmd_reg[DEBUG_CMD_LATENCY];
    
    assign debug_sl = cmd_reg[0];
    assign debug_do = data_sr[0];
    
    always @ (posedge mclk) begin
        if (mrst) ld_r <= 0;
        else      ld_r <= load_w;

        if      (mrst)      cntr <= 0;
        else if (shift32_w) cntr <= 6'h21;
        else if (cntr[5])   cntr <= cntr + 1;
    
        if (mrst) cmd_reg <= 0;
        else      cmd_reg <= {cmd_reg[DEBUG_CMD_LATENCY - 1 : 0], load_w | ld_r | cntr[0]};
        
        if (mrst) cmd <= 0;
        else      cmd <= cmd_reg_dly & ~cmd;
        
        if      (shift32_w)           data_sr <= cmd_data;
        else if (cmd && !cmd_reg_dly) data_sr <= {debug_di, data_sr[31:1]};
        
        if (mrst) tgl <= 0;
        else      tgl <= tgl & (&cntr); // When counter == 63 - toggle tgl to initiate status send
        
    end
    
    cmd_deser #(
        .ADDR       (DEBUG_ADDR),
        .ADDR_MASK  (DEBUG_MASK),
        .NUM_CYCLES (6),
        .ADDR_WIDTH (2),
        .DATA_WIDTH (32)
    ) cmd_deser_32bit_i (
        .rst        (1'b0),     //rst),      // input
        .clk        (mclk),     // input
        .srst       (mrst),     // input
        .ad         (cmd_ad),   // input[7:0] 
        .stb        (cmd_stb),  // input
        .addr       (cmd_a),    // output[3:0] 
        .data       (cmd_data), // output[31:0] 
        .we         (cmd_we)    // output
    );

    status_generate #(
        .STATUS_REG_ADDR     (DEBUG_STATUS_REG_ADDR),
        .PAYLOAD_BITS        (1),
        .REGISTER_STATUS     (0),
        .EXTRA_WORDS         (1),
        .EXTRA_REG_ADDR      (DEBUG_READ_REG_ADDR)
    ) status_generate_i (
        .rst           (1'b0),          // rst), // input
        .clk           (mclk),          // input
        .srst          (mrst),          // input
        .we            (set_status_w),  // input
        .wd            (cmd_data[7:0]), // input[7:0] 
        .status        ({data_sr,tgl}), // input[14:0] 
        .ad            (status_ad),     // output[7:0] 
        .rq            (status_rq),     // output
        .start         (status_start)   // input
    );


endmodule
