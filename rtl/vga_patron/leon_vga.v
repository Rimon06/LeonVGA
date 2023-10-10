/*
https://github.com/narendiran1996/vga_controller/blob/main/vga_timing_specs.csv
http://martin.hinner.info/vga/timing.html
http://www.tinyvga.com/vga-timing/640x480@60Hz
*/
`define CLK_25MHZ
`default_nettype none
`define MY_VGA_DEFAULT_PARAMS parameter \
  /* VGA_640_480_60Hz   */    \
  VPOL            = 0,        \
  HPOL            = 0,        \
  FRAME_RATE      = 60,       \
  /* horizontal timing frame*/\
  HACTIVE         = 640,      \
  HFP             =  16,      \
  HSYNCLEN        =  96,      \
  HBP             =  48,      \
  /* vertical timing frame */ \
  VACTIVE         = 480,      \
  VFP             =  10,      \
  VSYNCLEN        =   2,      \
  VBP             =  33      


module VGA #(`MY_VGA_DEFAULT_PARAMS,TILESIZE = 8
  )(
  input clk,
  input rst,
  input [3:0] i_sel_demo,
  // salidas
  output [2:0] o_red,
  output [2:0] o_green,
  output [1:0] o_blue,
  output o_hsync,
  output o_vsync,
  output [31:0] o_framecnt
  );

  localparam HTILES       = HACTIVE/TILESIZE;
  localparam VTILES       = VACTIVE/TILESIZE;
  localparam BIT_USE      = $clog2(TILESIZE); // 3 para 8
  localparam FBUFFER_SIZE = HTILES*VTILES;


  wire px_clk; // 25MHz ~

  
  `ifdef CLK_25MHZ
  /**
  * PLL configuration
  *
  * This Verilog header file was generated automatically
  * using the icepll tool from the IceStorm project.
  * It is intended for use with FPGA primitives SB_PLL40_CORE,
  * SB_PLL40_PAD, SB_PLL40_2_PAD, SB_PLL40_2F_CORE or SB_PLL40_2F_PAD.
  * Use at your own risk.
  *
  * Given input frequency:        12.000 MHz
  * Requested output frequency:   25.100 MHz
  * Achieved output frequency:    25.125 MHz
  */
    SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .DIVR(4'b0000),   // DIVR =  0
      .DIVF(7'b1000010),  // DIVF = 66
      .DIVQ(3'b101),    // DIVQ =  5
      .FILTER_RANGE(3'b001) // FILTER_RANGE = 1
      //.PLLOUT_SELECT("GENCLK"),
    ) PLL(
      .REFERENCECLK(clk),
      .PLLOUTCORE(px_clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
      );
  `else
  // PLL etc etc
  assign px_clk = clk;
  `endif

  //-- Contador horizontal y vertical y Generador de sincronismo
  wire hsync, vsync, blank;
  wire [9:0] hcnt, vcnt;
  sync_vga sync_gen (
    .px_clk(px_clk),
    .rst(rst),
    .o_hcnt(hcnt),
    .o_vcnt(vcnt),
    .o_hsync(hsync),
    .o_vsync(vsync),
    .o_blank(blank));

  //-- Registros de colores de fondo y texto
  reg [7:0] color_bkn = {3'b111,3'b111,2'b11}; // color fondo
  reg [7:0] color_txt = {3'b000,3'b000,2'b00}; // color texto

  //-- Codificador de indice a direccion
  wire [$clog2(FBUFFER_SIZE)-1:0] address;

  wire [$clog2(HTILES)-1: 0] index_x = hcnt >> BIT_USE; // Usara hcnt[9:3]
  wire [$clog2(VTILES)-1: 0] index_y = vcnt >> BIT_USE;
  // assign index = hcnt[9:BIT_USE]+HTILES*vcnt[8:BIT_USE];
  assign address = index_x + HTILES*index_y;

  // Se creara un framebuffer de 5120 bytes, pero realmente se usaran exactamente HTILES*VTILES=4800
  //reg [7:0] framebuffer  [0:FBUFFER_SIZE-1];
  //Escritura
  /*
  wire [7:0] data_in = 8'hAA;
  wire rd = 0;
  always @(posedge clk) begin // Se usa el reloj del sistema, pues aqui es la interfaz para escritura
    if (rd)
      framebuffer[0] <= data_in;
  end
  */
  // lectura
  //reg [7:0] character;
  reg hsync_q,vsync_q,blank_q;
  reg [BIT_USE-1:0] px_x,px_y; // para TILESIZE=8, [2:0] (3 bis)
  always @(posedge px_clk) begin
    //character     <= framebuffer[address];
    hsync_q <= hsync;
    vsync_q <= vsync;
    px_x    <= hcnt[BIT_USE-1:0]; 
    px_y    <= vcnt[BIT_USE-1:0];
    blank_q <= blank;
  end
  /*
  wire [63:0] letra;
  asciiTo8x8 Gen_patron( // (TODO)
   .character(txt),
   .letra(letra)); // organizado en 

  reg [7:0] px_fila;
  reg px_bit;
  reg [7:0] px_color;
  always @(*) begin
    case(px_y): 
    0: px_fila = letra[ 7: 0];
    1: px_fila = letra[15: 8];
    2: px_fila = letra[23:16];
    3: px_fila = letra[31:24];
    4: px_fila = letra[39:32];
    5: px_fila = letra[47:40];
    6: px_fila = letra[55:48];
    7: px_fila = letra[63:56];
    endcase
    case(px_x)
    0: px_bit = px_fila[0];
    1: px_bit = px_fila[1];
    2: px_bit = px_fila[2];
    3: px_bit = px_fila[3];
    4: px_bit = px_fila[4];
    5: px_bit = px_fila[5];
    6: px_bit = px_fila[6];
    7: px_bit = px_fila[7];
    endcase

    px_color = px_bit? color_txt : color_bkn;
  end

  wire [2:0] red, green;
  wire [1:0] blue;
  assign {red,green,blue} = blank_q ? 8'b0 : px_color;
  */

  // (TODO) Agregar paleta de colores

  // ############################ ############################ ############################
  // ############################ #########  DEMOS  ########## ############################
  // ############################ ############################ ############################

  localparam VTOTAL    = VACTIVE + VFP + VSYNCLEN + VBP;
  
  reg [31:0] frame_cnt;
  always @(posedge px_clk) begin
    if (rst) begin
      frame_cnt <= 0;      
    end else if (vcnt == VTOTAL-1) begin
      frame_cnt <= frame_cnt + 1;
    end
  end
  assign o_framecnt = frame_cnt;

  // ****************** Demo 1: Lineas RGB ****************************************************************
  reg [2:0]cnt_red, cnt_green;
  reg [1:0]cnt_blue;
  reg [6:0] cnt1 = 0;
  always @(posedge px_clk) begin
    if (rst || blank) begin
      {cnt_blue,cnt_green,cnt_red} <= 8'b0;
      cnt1 <= 0;
    end else begin
      cnt1 <= cnt1 + 1;
      if (cnt1==39) begin
        cnt_blue  <= cnt_blue + 1;
      end
      if (cnt1 == 79) begin
        cnt_red   <= cnt_red + 1;
        cnt_green <= cnt_green + 1;
        cnt_blue  <= cnt_blue + 1;
        cnt1 <= 0;
      end  
    end
  end

  reg [7:0] cnt_colour_demo;
  always @(posedge px_clk) begin
    if (rst || blank) begin
      cnt_colour_demo <= 0;
    end else if (hcnt[0]==1'b1) begin
      cnt_colour_demo <= cnt_colour_demo + 1;
    end
  end

  wire [7:0] demo_1 = {cnt_red,3'b0,2'b0};
  wire [7:0] demo_2 = {3'b0,cnt_green,2'b0};
  wire [7:0] demo_3 = {3'b0,3'b0,cnt_blue};
  wire [7:0] demo_4 = {cnt_red,3'b0,cnt_blue};
  wire [7:0] demo_5 = {3'b0,cnt_green,cnt_blue};
  wire [7:0] demo_6 = {cnt_red,cnt_green,2'b0};
  wire [7:0] demo_7 = {cnt_red,cnt_green,cnt_blue};
  wire [7:0] demo_8 = cnt_colour_demo;

  //-- Seleccion del color
  reg [7:0] sel_color, sel_color_q;
  reg [3:0] isel1,isel2;
  always @(posedge px_clk) begin
    if (rst) 
      {isel2,isel1} <= 0;
    else 
      {isel2,isel1} <= {isel1,i_sel_demo};
  end
  
  always @(*) begin
    case (isel2)
      0: sel_color = demo_1;
      1: sel_color = demo_2;
      2: sel_color = demo_3;
      3: sel_color = demo_4;
      4: sel_color = demo_5;
      5: sel_color = demo_6;
      6: sel_color = demo_7;
      7: sel_color = demo_8;
      8: sel_color = demo_9;
      9: sel_color = demo_10;
      default :
         sel_color = 0;
    endcase
  end

  // ****************** Demo 2: hypnotic concentric cycles ****************************************************
    wire signed [9:0] dx = $signed(hcnt) - HACTIVE/2;
    wire signed [9:0] dy = $signed(vcnt) - VACTIVE/2;
    wire signed [23:0] R2 = dx*dx + dy*dy - $signed(frame_cnt << 6);
    wire [3:0] color_4 = R2[14:11];
     
    // ordered dithering to simulate 16 colors from the generated 4 colors
    reg [1:0] threshold;
    always @(*) begin
      case({hcnt[0],vcnt[0]})
        2'b00: threshold = 0;
        2'b01: threshold = 2;
        2'b10: threshold = 3;
        2'b11: threshold = 1;
      endcase
    end
     wire [1:0] cc = ((color_4[1:0] <= threshold) | (&color_4[3:2])) ? color_4[3:2] : color_4[3:2]+1;
     wire [7:0] demo_9 = {{3{cc[1]}},{3{cc[0]}},2'b0};

  // ******************* Demo 3: "Alian Art" XOR/Modulo pattern (two layers) **********************************
    wire [3:0] b1 = ((vcnt[4:1] - frame_cnt[3:0]) ^ hcnt[4:1]);
    wire [3:0] b2 = ((vcnt[3:0] - (frame_cnt[4:1]))^ hcnt[3:0]);
    reg [3:0] b1_q, b2_q;
    always @(posedge px_clk)
      {b1_q,b2_q} <= {b1,b2};
    wire [7:0] demo_10 = {b1_q % 4'd9 == 1,2'H3,b2_q%4'd13 == 1,4'hF};


  SB_IO #(
    .PIN_TYPE(6'b0101_00) // 0101: latched output  00: no input
  ) user_IO[9:0] (         // Yes, in Verilog you can declare 4 pins in 1 decl
    .PACKAGE_PIN({ o_red[2:0],o_green[2:0],o_blue[1:0],  o_vsync, o_hsync}),
    .D_OUT_0({ blank?8'b0:sel_color[7:0],  vsync_q, hsync_q}),
    .OUTPUT_CLK({10{px_clk}})
  );

endmodule

// Entrega hsync, vsync y blank en base al valor actual del contador 
module sync_vga #(`MY_VGA_DEFAULT_PARAMS) (
  input px_clk,
  input rst,
  output reg [9:0] o_hcnt = 0,
  output reg [9:0] o_vcnt = 0,
  output o_hsync,
  output o_vsync,
  output o_blank
  );

  localparam VTOTAL    = VACTIVE + VFP + VSYNCLEN + VBP;
  localparam HTOTAL    = HACTIVE + HFP + HSYNCLEN + HBP;

  assign o_vsync  = (~VPOL) ^ ((o_vcnt >= (VACTIVE + VFP -1)) && (o_vcnt < (VACTIVE + VFP + VSYNCLEN)));
  assign o_hsync  = (~HPOL) ^ ((o_hcnt >= (HACTIVE + HFP -1)) && (o_vcnt < (HACTIVE + HFP + HSYNCLEN)));
  assign o_blank  = (o_hcnt >= HACTIVE) || (o_vcnt >= VACTIVE);

  wire hcycle = ((o_hcnt == (HTOTAL -1)) || rst);
  wire vcycle = (o_vcnt == (VTOTAL -1)) || rst;

  always @(posedge px_clk) begin
    if (hcycle) begin
      o_hcnt <= 0;
      if (vcycle) o_vcnt <= 0;
      else        o_vcnt <= o_vcnt + 1;
    end else begin
      o_hcnt <= o_hcnt + 1;
    end
  end
endmodule


module asciiTo8x8( 
  input  [ 7: 0] character,
  output [63: 0] letra
  );
  
  assign letra = {16{4'hA}};
endmodule
