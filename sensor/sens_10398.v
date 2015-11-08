/*******************************************************************************
 * Module: sens_10398
 * Date:2015-10-15  
 * Author: andrey     
 * Description: Top level module for the 10398 SFE (with MT9F002 sensor)
 *
 * Copyright (c) 2015 Elphel, Inc .
 * sens_10398.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sens_10398.v is distributed in the hope that it will be useful,
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
 *******************************************************************************/
`timescale 1ns/1ps

module  sens_10398 #(
    parameter SENSIO_ADDR =        'h330,
    parameter SENSIO_ADDR_MASK =   'h7f8,
    parameter SENSIO_CTRL =        'h0,
    parameter SENSIO_STATUS =      'h1,
    parameter SENSIO_JTAG =        'h2,
//    parameter SENSIO_WIDTH =       'h3, // set line width (1.. 2^16) if 0 - use HACT
    parameter SENSIO_DELAYS =      'h4, // 'h4..'h7 - each address sets 4 delays through 4 bytes of 32-bit data
// 6 - delays, 7 - phase
    parameter SENSIO_STATUS_REG =  'h21,

    parameter SENS_JTAG_PGMEN =    8,
    parameter SENS_JTAG_PROG =     6,
    parameter SENS_JTAG_TCK =      4,
    parameter SENS_JTAG_TMS =      2,
    parameter SENS_JTAG_TDI =      0,
    
    parameter SENS_CTRL_MRST=      0,  //  1: 0
    parameter SENS_CTRL_ARST=      2,  //  3: 2
    parameter SENS_CTRL_ARO=       4,  //  5: 4
    parameter SENS_CTRL_RST_MMCM=  6,  //  7: 6
//    parameter SENS_CTRL_EXT_CLK=   8,  //  9: 8
    parameter SENS_CTRL_IGNORE_EMBED =   8,  //  9: 8
    parameter SENS_CTRL_LD_DLY=   10,  // 10

    parameter SENS_CTRL_GP0=      12,  // 13:12
    parameter SENS_CTRL_GP1=      14,  // 15:14

//    parameter SENS_CTRL_QUADRANTS =      12,  // 17:12, enable - 20
//    parameter SENS_CTRL_QUADRANTS_WIDTH = 6,
//    parameter SENS_CTRL_QUADRANTS_EN =   20,  // 17:12, enable - 20 (2 bits reserved)
    parameter IODELAY_GRP =               "IODELAY_SENSOR",
    parameter integer IDELAY_VALUE =       0,
    parameter real REFCLK_FREQUENCY =      200.0,
    parameter HIGH_PERFORMANCE_MODE =     "FALSE",
    parameter SENS_PHASE_WIDTH=            8,      // number of bits for te phase counter (depends on divisors)
//    parameter SENS_PCLK_PERIOD =           3.000,  // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter SENS_BANDWIDTH =             "OPTIMIZED",  //"OPTIMIZED", "HIGH","LOW"

    parameter CLKIN_PERIOD_SENSOR =        3.000, // input period in ns, 0..100.000 - MANDATORY, resolution down to 1 ps
    parameter CLKFBOUT_MULT_SENSOR =       3,      // 330 MHz --> 990 MHz
    parameter CLKFBOUT_PHASE_SENSOR =      0.000,  // CLOCK FEEDBACK phase in degrees (3 significant digits, -360.000...+360.000)
    parameter IPCLK_PHASE =                0.000,
    parameter IPCLK2X_PHASE =              0.000,
    parameter BUF_IPCLK =                 "BUFR",
    parameter BUF_IPCLK2X =               "BUFR",  

    parameter SENS_DIVCLK_DIVIDE =         1,            // Integer 1..106. Divides all outputs with respect to CLKIN
    parameter SENS_REF_JITTER1   =         0.010,        // Expected jitter on CLKIN1 (0.000..0.999)
    parameter SENS_REF_JITTER2   =         0.010,
    parameter SENS_SS_EN         =        "FALSE",      // Enables Spread Spectrum mode
    parameter SENS_SS_MODE       =        "CENTER_HIGH",//"CENTER_HIGH","CENTER_LOW","DOWN_HIGH","DOWN_LOW"
    parameter SENS_SS_MOD_PERIOD =         10000,        // integer 4000-40000 - SS modulation period in ns

    parameter HISPI_MSB_FIRST =            0,
    parameter HISPI_NUMLANES =             4,
    parameter HISPI_DELAY_CLK =           "FALSE",      
    parameter HISPI_MMCM =                "TRUE",
    
    parameter HISPI_CAPACITANCE =         "DONT_CARE",
    parameter HISPI_DIFF_TERM =           "TRUE",
    parameter HISPI_DQS_BIAS =            "TRUE",
    parameter HISPI_IBUF_DELAY_VALUE =    "0",
    parameter HISPI_IBUF_LOW_PWR =        "TRUE",
    parameter HISPI_IFD_DELAY_VALUE =     "AUTO",
    parameter HISPI_IOSTANDARD =          "DIFF_SSTL18_I", //"DIFF_SSTL18_II" for high current (13.4mA vs 8mA)
    
    // Other (non-HiSPi) sensor I/Os
    parameter integer PXD_DRIVE =         12,
    parameter PXD_IBUF_LOW_PWR =         "TRUE",
    parameter PXD_IOSTANDARD =           "LVCMOS18", // 1.8V single-ended
    parameter PXD_SLEW =                 "SLOW",
    parameter PXD_CAPACITANCE =          "DONT_CARE",
    parameter PXD_CLK_DIV =              10, // 220MHz -> 22MHz
    parameter PXD_CLK_DIV_BITS =          4
//    ,parameter STATUS_ALIVE_WIDTH =        4
    
)(
    input                      pclk,   // global clock input, pixel rate (220MHz for MT9F002)
    input                      prst,
    output                     prsts,  // @pclk - includes sensor reset and sensor PLL reset
    // delay control inputs
    input                      mclk,
    input                      mrst,
    input                [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
    input                      cmd_stb,     // strobe (with first byte) for the command a/d
    output               [7:0] status_ad,   // status address/data - up to 5 bytes: A - {seq,status[1:0]} - status[2:9] - status[10:17] - status[18:25]
    output                     status_rq,   // input request to send status downstream
    input                      status_start, // Acknowledge of the first status packet byte (address)
    
    input                      trigger_mode, // running in triggered mode (0 - free running mode)
    input                      trig,      // per-sensor trigger input
    
    
    // I/O pads
    input [HISPI_NUMLANES-1:0] sns_dp,
    input [HISPI_NUMLANES-1:0] sns_dn,
    input                      sns_clkp,  // was TDO on 10359
    input                      sns_clkn,  // was TDI on 10359

    output                     sens_ext_clk_p, // sns1_dp[6]
    output                     sens_ext_clk_n, // sns1_dn[6] just to reduce EMI from the clock == gp[2]
    
    inout                      sns_pgm,        // (pullup)            SENSPGM 
    output                     sns_ctl_tck,    // unused on 10398 -   TCK
    output                     sns_mrst,       // sns_dp[7]
    output                     sns_arst_tms,   // sns_dn[7] == gp[3]  TMS
    output                     sns_gp0_tdi,    // sns_dp[5] == gp[0]  TDI   (differs from 10353)
    output                     sns_gp1,        // sns_dn[5] == gp[1]

    input                      sns_flash_tdo,   // sns_dp[4]           TDO  (differs from 10353)
    input                      sns_shutter_done,// sns_dn[4]           DONE (differs from 10353)

    output              [11:0] pxd,
    output                     hact,
    output                     sof, // @pclk
    output                     eof // @pclk
    

);

    
    reg  [31:0] data_r; 
//    reg   [3:0] set_idelay;

    reg         set_idelays;    
    reg         set_iclk_phase;
    reg         set_ctrl_r;
    reg         set_status_r;
    reg         set_jtag_r;
    
    wire        ps_rdy;
    wire  [7:0] ps_out;      
    wire        locked_pxd_mmcm;
    wire        clkin_pxd_stopped_mmcm;
    wire        clkfb_pxd_stopped_mmcm;
    
    // programmed resets to the sensor 
    reg         iaro_soft  = 0;
    wire        iaro;
    reg         iarst = 0;
    reg         imrst = 0;  // active low 
    reg         rst_mmcm=1; // rst and command - en/dis 
    reg         ld_idelay=0;
    reg         ignore_embed=0; // do not process sensor data marked as "embedded"

    wire [14:0] status;
    
    wire        cmd_we;
    wire  [2:0] cmd_a;
    wire [31:0] cmd_data;
    
    wire           xfpgadone;  // state of the MRST pin ("DONE" pin on external FPGA)
    wire           xfpgatdo;   // TDO read from external FPGA
    wire           senspgmin;    

    reg            xpgmen=0;     // enable programming mode for external FPGA
    reg            xfpgaprog=0;  // PROG_B to be sent to an external FPGA
    reg            xfpgatck=0;   // TCK to be sent to external FPGA
    reg            xfpgatms=0;   // TMS to be sent to external FPGA
    reg            xfpgatdi=0;   // TDI to be sent to external FPGA
    
    reg      [1:0] gp_r;         // sensor GP0, GP1. For now just software control, later use for something else
    reg [ PXD_CLK_DIV_BITS-1:0] pxd_clk_cntr;
    reg      [1:0] prst_with_sens_mrst = 2'h3; // prst extended to include sensor reset and rst_mmcm
    wire           async_prst_with_sens_mrst =  ~imrst | rst_mmcm; // mclk domain   

    assign status = { locked_pxd_mmcm, 
                     clkin_pxd_stopped_mmcm, clkfb_pxd_stopped_mmcm, xfpgadone,
                     ps_rdy, ps_out, xfpgatdo, senspgmin};

    assign iaro = trigger_mode?  ~trig : iaro_soft;

    assign  prsts = prst_with_sens_mrst[0];  // @pclk - includes sensor reset and sensor PLL reset
    

    always @(posedge mclk) begin
        if      (mrst)     data_r <= 0;
        else if (cmd_we)   data_r <= cmd_data;
        
        if      (mrst) set_idelays <= 0;
        else           set_idelays <=  cmd_we & (cmd_a==(SENSIO_DELAYS+2));
                                             
        if      (mrst) set_iclk_phase <= 0;
        else           set_iclk_phase <=  cmd_we & (cmd_a==(SENSIO_DELAYS+3));
                                             
        if (mrst)     set_status_r <=0;
        else          set_status_r <= cmd_we && (cmd_a== SENSIO_STATUS);                             
        
        if (mrst)     set_ctrl_r <=0;
        else          set_ctrl_r <= cmd_we && (cmd_a== SENSIO_CTRL);                             
        
        if (mrst)     set_jtag_r <=0;
        else          set_jtag_r <= cmd_we && (cmd_a== SENSIO_JTAG);
        
        if      (mrst)                                      xpgmen <= 0;
        else if (set_jtag_r && data_r[SENS_JTAG_PGMEN + 1]) xpgmen <= data_r[SENS_JTAG_PGMEN]; 

        if      (mrst)                                      xfpgaprog <= 0;
        else if (set_jtag_r && data_r[SENS_JTAG_PROG + 1])  xfpgaprog <= data_r[SENS_JTAG_PROG]; 
                                     
        if      (mrst)                                      xfpgatck <= 0;
        else if (set_jtag_r && data_r[SENS_JTAG_TCK + 1])   xfpgatck <= data_r[SENS_JTAG_TCK]; 

        if      (mrst)                                      xfpgatms <= 0;
        else if (set_jtag_r && data_r[SENS_JTAG_TMS + 1])   xfpgatms <= data_r[SENS_JTAG_TMS]; 

        if      (mrst)                                      xfpgatdi <= 0;
        else if (set_jtag_r && data_r[SENS_JTAG_TDI + 1])   xfpgatdi <= data_r[SENS_JTAG_TDI];
        
        if      (mrst)                                      imrst <= 0; 
        else if (set_ctrl_r && data_r[SENS_CTRL_MRST + 1])  imrst <= data_r[SENS_CTRL_MRST]; 
         
        if      (mrst)                                      iarst <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_ARST + 1])  iarst <= data_r[SENS_CTRL_ARST]; 
         
        if      (mrst)                                      iaro_soft <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_MRST + 1])  iaro_soft <= data_r[SENS_CTRL_ARO]; 
         
        if      (mrst)                                          rst_mmcm <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_RST_MMCM + 1])  rst_mmcm <= data_r[SENS_CTRL_RST_MMCM]; 
         
        if      (mrst)                                               ignore_embed <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_IGNORE_EMBED + 1])   ignore_embed <= data_r[SENS_CTRL_IGNORE_EMBED]; 
         
        if  (mrst) ld_idelay <= 0;
        else       ld_idelay <= set_ctrl_r && data_r[SENS_CTRL_LD_DLY]; 

        if      (mrst)                                      gp_r[0] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP0 + 1])   gp_r[0] <= data_r[SENS_CTRL_GP0]; 

        if      (mrst)                                      gp_r[1] <= 0;
        else if (set_ctrl_r && data_r[SENS_CTRL_GP1 + 1])   gp_r[1] <= data_r[SENS_CTRL_GP1]; 

    end

    // generate (slow) clock for the sensor - it will be multiplied by the sensor VCO
    always @(posedge pclk) begin
        if (prst || (pxd_clk_cntr[PXD_CLK_DIV_BITS-2:0] == 0)) pxd_clk_cntr[PXD_CLK_DIV_BITS-2:0] <= (PXD_CLK_DIV / 2);
        else                                                   pxd_clk_cntr[PXD_CLK_DIV_BITS-2:0] <= pxd_clk_cntr[PXD_CLK_DIV_BITS-2:0] - 1;
        // treat MSB separately to make 50% duty cycle
        if      (prst)                                         pxd_clk_cntr[PXD_CLK_DIV_BITS-1] <=   0;
        else if (pxd_clk_cntr[PXD_CLK_DIV_BITS-2:0] == 0)      pxd_clk_cntr[PXD_CLK_DIV_BITS-1] <=  ~pxd_clk_cntr[PXD_CLK_DIV_BITS-1];
    
    end

    always @(posedge pclk or posedge async_prst_with_sens_mrst) begin
        if (async_prst_with_sens_mrst) prst_with_sens_mrst <=  2'h3;
        else if (prst)                 prst_with_sens_mrst <=  2'h3;
        else                           prst_with_sens_mrst <= prst_with_sens_mrst >> 1;
    end

    cmd_deser #(
        .ADDR        (SENSIO_ADDR),
        .ADDR_MASK   (SENSIO_ADDR_MASK),
        .NUM_CYCLES  (6),
        .ADDR_WIDTH  (3),
        .DATA_WIDTH  (32)
    ) cmd_deser_sens_io_i (
        .rst         (1'b0),     // rst), // input
        .clk         (mclk),     // input
        .srst        (mrst), // input
        .ad          (cmd_ad),   // input[7:0] 
        .stb         (cmd_stb),  // input
        .addr        (cmd_a),    // output[15:0] 
        .data        (cmd_data), // output[31:0] 
        .we          (cmd_we)    // output
    );

    status_generate #(
        .STATUS_REG_ADDR(SENSIO_STATUS_REG),
        .PAYLOAD_BITS(15) // +3) // +STATUS_ALIVE_WIDTH) // STATUS_PAYLOAD_BITS)
    ) status_generate_sens_io_i (
        .rst        (1'b0),                    // rst), // input
        .clk        (mclk),                    // input
        .srst       (mrst),                    // input
        .we         (set_status_r),            // input
        .wd         (data_r[7:0]),             // input[7:0] 
//        .status     ({status_alive,status}),   // input[25:0] 
        .status     (status),                  // input[25:0] 
        .ad         (status_ad),               // output[7:0] 
        .rq         (status_rq),               // output
        .start      (status_start)             // input
    );

    sens_hispi12l4 #(
        .IODELAY_GRP            (IODELAY_GRP),
        .IDELAY_VALUE           (IDELAY_VALUE),
        .REFCLK_FREQUENCY       (REFCLK_FREQUENCY),
        .HIGH_PERFORMANCE_MODE  (HIGH_PERFORMANCE_MODE),
        .SENS_PHASE_WIDTH       (SENS_PHASE_WIDTH),
        .SENS_BANDWIDTH         (SENS_BANDWIDTH),
        .CLKIN_PERIOD_SENSOR    (CLKIN_PERIOD_SENSOR),
        .CLKFBOUT_MULT_SENSOR   (CLKFBOUT_MULT_SENSOR),
        .CLKFBOUT_PHASE_SENSOR  (CLKFBOUT_PHASE_SENSOR),
        .IPCLK_PHASE            (IPCLK_PHASE),
        .IPCLK2X_PHASE          (IPCLK2X_PHASE),
        .BUF_IPCLK              (BUF_IPCLK),
        .BUF_IPCLK2X            (BUF_IPCLK2X),
        .SENS_DIVCLK_DIVIDE     (SENS_DIVCLK_DIVIDE),
        .SENS_REF_JITTER1       (SENS_REF_JITTER1),
        .SENS_REF_JITTER2       (SENS_REF_JITTER2),
        .SENS_SS_EN             (SENS_SS_EN),
        .SENS_SS_MODE           (SENS_SS_MODE),
        .SENS_SS_MOD_PERIOD     (SENS_SS_MOD_PERIOD),
        .HISPI_MSB_FIRST        (HISPI_MSB_FIRST),
        .HISPI_NUMLANES         (HISPI_NUMLANES),
        .HISPI_DELAY_CLK        (HISPI_DELAY_CLK),
        .HISPI_MMCM             (HISPI_MMCM),
        .HISPI_CAPACITANCE      (HISPI_CAPACITANCE),
        .HISPI_DIFF_TERM        (HISPI_DIFF_TERM),
        .HISPI_DQS_BIAS         (HISPI_DQS_BIAS),
        .HISPI_IBUF_DELAY_VALUE (HISPI_IBUF_DELAY_VALUE),
        .HISPI_IBUF_LOW_PWR     (HISPI_IBUF_LOW_PWR),
        .HISPI_IFD_DELAY_VALUE  (HISPI_IFD_DELAY_VALUE),
        .HISPI_IOSTANDARD       (HISPI_IOSTANDARD)
    ) sens_hispi12l4_i (
        .pclk                   (pclk),                   // input
        .prst                   (prsts),                  //prst),                   // input
        .sns_dp                 (sns_dp[3:0]),            // input[3:0] 
        .sns_dn                 (sns_dn[3:0]),            // input[3:0] 
        .sns_clkp               (sns_clkp),               // input
        .sns_clkn               (sns_clkn),               // input
        .pxd_out                (pxd),                    // output[11:0] reg 
        .hact_out               (hact),                   // output
        .sof                    (sof),                    // output
        .eof                    (eof),                    // output reg 
        .mclk                   (mclk),                   // input
        .mrst                   (mrst),                   // input
        .dly_data               (data_r),                 // input[31:0] 
        .set_idelay             ({4{set_idelays}}),       // input[3:0] 
        .ld_idelay              (ld_idelay),              // input
        .set_clk_phase          (set_iclk_phase),         // input
        .rst_mmcm               (rst_mmcm),               // input
        .ignore_embedded        (ignore_embed),           // input
        .ps_rdy                 (ps_rdy),                 // output
        .ps_out                 (ps_out),                 // output[7:0] 
        .locked_pxd_mmcm        (locked_pxd_mmcm),        // output
        .clkin_pxd_stopped_mmcm (clkin_pxd_stopped_mmcm), // output
        .clkfb_pxd_stopped_mmcm (clkfb_pxd_stopped_mmcm)  // output
    );
/*
    obufds #(
        .CAPACITANCE("DONT_CARE"),
        .IOSTANDARD(PXD_IOSTANDARD), // not diff, just opposite phase signals
        .SLEW("SLOW")
    ) obufds_i (
        .o   (sens_ext_clk_p),                   // output
        .ob  (sens_ext_clk_n),                  // output
        .i   (pxd_clk_cntr[PXD_CLK_DIV_BITS-1]) // input
    );
*/  
//    reg [1:0] ext_clk_r;
//    always @(posedge pclk) begin
//        ext_clk_r <= {pxd_clk_cntr[PXD_CLK_DIV_BITS-1], !pxd_clk_cntr[PXD_CLK_DIV_BITS-1]};
//    end

  
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) ext_clk_p_i (
        .O  (sens_ext_clk_p), // output
        .I  (pxd_clk_cntr[PXD_CLK_DIV_BITS-1]) //ext_clk_r[0])    // input
    );

    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) ext_clk_n_i (
        .O  (sens_ext_clk_n), // output
        .I  (iarst) // ~pxd_clk_cntr[PXD_CLK_DIV_BITS-1]) // ext_clk_r[1])    // input
    );
    
    // Probe programmable/ control PROGRAM pin
    reg [1:0] xpgmen_d;
    reg force_senspgm=0;
//    mpullup i_mrst_pullup(mrst);
    mpullup i_senspgm_pullup          (sns_pgm);
    mpullup i_sns_shutter_done_pullup (sns_shutter_done);

    always @ (posedge mclk) begin
        if      (mrst)                 force_senspgm <= 0;
        else if (xpgmen_d[1:0]==2'b10) force_senspgm <= senspgmin;
        
        if      (mrst)                 xpgmen_d <= 0;
        else                           xpgmen_d <= {xpgmen_d[0], xpgmen};
    end

    iobuf #(
        .DRIVE        (PXD_DRIVE),
        .IBUF_LOW_PWR (PXD_IBUF_LOW_PWR),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) senspgm_i (
        .O  (senspgmin),                         // output -senspgm pin state
        .IO (sns_pgm),                           // inout I/O pad
        .I  (xpgmen?(~xfpgaprog):force_senspgm), // input
        .T  (~(xpgmen || force_senspgm))         // input - disable when reading DONE
    );

    // generate ARO/TCK
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) aro_tck_i (
        .O  (sns_ctl_tck),            // output
        .I  (xpgmen? xfpgatck : iaro) // input
    );
    

    // generate ARST/TMS
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_arst_tms_i (
        .O  (sns_arst_tms),            // output
        .I  (xpgmen? xfpgatms : iarst) // input
    );

    // generate MRST
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_mrst_i (
        .O  (sns_mrst),      // output
        .  I(imrst)          // input
    );

    // generate GP0/TDI
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_gp0_tdi_i (
        .O  (sns_gp0_tdi),               // output
        .I  (xpgmen? xfpgatdi : gp_r[0]) // input
    );

    // generate GP1
    obuf #(
        .CAPACITANCE  (PXD_CAPACITANCE),
        .DRIVE        (PXD_DRIVE),
        .IOSTANDARD   (PXD_IOSTANDARD),
        .SLEW         (PXD_SLEW)
    ) sns_gp1_i (
        .O  (sns_gp1),   // output
        .I  (gp_r[1])    // input
    );
    // READ TDO (and flash)    
    ibuf_ibufg #(
        .CAPACITANCE      (PXD_CAPACITANCE),
        .IBUF_DELAY_VALUE ("0"),
        .IBUF_LOW_PWR     (PXD_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  ("AUTO"),
        .IOSTANDARD       (PXD_IOSTANDARD)
    ) sns_flash_tdo_i (
        .O(xfpgatdo),     // output
        .I(sns_flash_tdo) // input
    );

    // READ DONE (and shutter)    
    ibuf_ibufg #(
        .CAPACITANCE      (PXD_CAPACITANCE),
        .IBUF_DELAY_VALUE ("0"),
        .IBUF_LOW_PWR     (PXD_IBUF_LOW_PWR),
        .IFD_DELAY_VALUE  ("AUTO"),
        .IOSTANDARD       (PXD_IOSTANDARD)
    ) sns_shutter_done_i (
        .O(xfpgadone),     // output
        .I(sns_shutter_done) // input
    );
    
endmodule

