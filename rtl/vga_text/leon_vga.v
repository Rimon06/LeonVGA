/*
https://github.com/narendiran1996/vga_controller/blob/main/vga_timing_specs.csv
http://martin.hinner.info/vga/timing.html
http://www.tinyvga.com/vga-timing/640x480@60Hz
detalles con los colores:
  https://en.wikipedia.org/wiki/List_of_8-bit_computer_hardware_graphics#8-bit_RGB_palettes
  * Niveles de colores RGB de 3-3-2 a 8-8-8
    3'b000 -> 8'h00  |  2'b00  8'h00
    3'b001 -> 8'h24  |  2'b01  8'h55
    3'b010 -> 8'h49  |  2'b10  8'hAA
    3'b011 -> 8'h6D  |  2'b11  8'hFF
    3'b100 -> 8'h92
    3'b101 -> 8'hB6
    3'b110 -> 8'hDB
    3'b111 -> 8'hFF
*/
`default_nettype none
`define CLK_25MHZ

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

module VGA #(`MY_VGA_DEFAULT_PARAMS, TILESIZE = 8
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
  localparam VTOTAL    = VACTIVE + VFP + VSYNCLEN + VBP;
  localparam HTOTAL    = HACTIVE + HFP + HSYNCLEN + HBP;

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
      .FILTER_RANGE(3'b001), // FILTER_RANGE = 1
      .PLLOUT_SELECT("GENCLK")
    ) PLL(
      .REFERENCECLK(clk),
      .PLLOUTCORE(px_clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
      );
  `else
    // PLL para pruebasPLL etc etc
    assign px_clk = clk;
  `endif

  //-- Contador horizontal y vertical y Generador de sincronismo
  wire hsync, vsync, blank;
  wire [9:0] hcnt, vcnt;
  sync_vga #(VPOL,HPOL,FRAME_RATE,HACTIVE,HFP,HSYNCLEN,HBP,VACTIVE,VFP,VSYNCLEN,VBP) 
    sync_gen (
    .px_clk(px_clk),
    .rst(rst),
    .o_hcnt(hcnt),
    .o_vcnt(vcnt),
    .o_hsync(hsync),
    .o_vsync(vsync),
    .o_blank(blank));

  //-- Contador de Frames
  reg [31:0] frame_cnt;
  always @(posedge px_clk) begin
    if (rst) begin
      frame_cnt <= 0;      
    end else if (vcnt == VTOTAL-1) begin
      frame_cnt <= frame_cnt + 1;
    end
  end

  assign o_framecnt = frame_cnt;
  


  //-- Codificador de indice a direccion
  wire [$clog2(FBUFFER_SIZE)-1:0] address;

  wire [$clog2(HTILES)-1: 0] index_x = hcnt >> BIT_USE; // Usara hcnt[9:3]
  wire [$clog2(VTILES)-1: 0] index_y = vcnt >> BIT_USE;
  // assign index = hcnt[9:BIT_USE]+HTILES*vcnt[8:BIT_USE];
  assign address = index_x + HTILES*index_y;

  //-- framebuffer de 5120 bytes, (Se usaran exactamente HTILES*VTILES=4800 + 18 (16 de paleta de colores + color de letra y banckground)
  reg [7:0] framebuffer  [0:FBUFFER_SIZE+18-1];
  integer i,j;
  initial begin
    for (i=0;i<FBUFFER_SIZE;i=i+1) begin
      framebuffer[i] = 8'hFF - i[7:0];
    end
    framebuffer[FBUFFER_SIZE-1] =8'hFF;
    framebuffer[59*80] = 8'hFF;
    framebuffer[79] = 8'hFF;

    for(i=0; i<18; i=i+1) begin
      framebuffer[FBUFFER_SIZE + 1] = { 8'b111_111_11, 8'b000_000_00,\
         8'b101_101_10, 8'b101_101_00, 8'b101_000_10, 8'b101_000_00, \
         8'b101_101_10, 8'b000_101_00, 8'b001_001_10, 8'b010_010_01, \
         8'b111_111_11, 8'b111_111_00, 8'b111_000_11, 8'b111_000_00, \
         8'b000_111_11, 8'b000_111_00, 8'b000_000_11, 8'b000_000_00} >> 8*i; 
    end

  end
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
  // -- Segmentacion
  reg [7:0] character;
  reg hsync_q,vsync_q,blank_q;
  reg [BIT_USE-1:0] px_x,px_y; // para TILESIZE=8, [2:0] (3 bis)
  reg [17:0] WrPalReg;
  always @(posedge px_clk) begin
    character <= framebuffer[address];
    hsync_q <= hsync;
    vsync_q <= vsync;
    px_x    <= hcnt[BIT_USE-1:0]; 
    px_y    <= vcnt[BIT_USE-1:0];
    blank_q <= blank;
    if (hcnt == HTOTAL) begin
      WrPalReg <= 1;
    end else if (px_x == 3'd7) begin
      WrPalReg <= {WrPalReg[16:0],1'b0};
    end

  end

  wire write_palette = (index_x==HTILES+1) && (px_y[2:0] == 3'b0);
  //-- Registros de colores de fondo y texto
  reg [7:0] color_bkn = {3'b111,3'b111,2'b11}; // color fondo
  reg [7:0] color_txt = {3'b000,3'b000,2'b00}; // color texto
  //-- Paleta de 16 colores 
  (* ram_style = "distributed" *) reg [7:0] Palette [15:0];
  always @(posedge px_clk) begin
    if (rst) begin
      Palette[ 0] <= 8'b000_000_00; // #000000 (negro)
      Palette[ 1] <= 8'b000_000_11; // #0000FF (azul)
      Palette[ 2] <= 8'b000_111_00; // #00FF00 (verde)
      Palette[ 3] <= 8'b000_111_11; // #00FFFF (cian)
      Palette[ 4] <= 8'b111_000_00; // #FF0000 (rojo)
      Palette[ 5] <= 8'b111_000_11; // #FF00FF (magenta)
      Palette[ 6] <= 8'b111_111_00; // #FFFF00 (amarillo)
      Palette[ 7] <= 8'b111_111_11; // #FFFFFF (blanco)

      Palette[ 8] <= 8'b010_010_01; // #494955 (gris oscuro)
      Palette[ 9] <= 8'b001_001_10; // #2424AA (Azul oscuro)
      Palette[10] <= 8'b000_101_00; // #00B600 (verde oscuro)
      Palette[11] <= 8'b101_101_10; // #00B6AA (cian oscuro)

      Palette[12] <= 8'b101_000_00; // #B60000 (rojo oscuro)
      Palette[13] <= 8'b101_000_10; // #B600AA (magenta oscuro)
      Palette[14] <= 8'b101_101_00; // #B6B600 (amarillo oscuro)
      Palette[15] <= 8'b101_101_10; // #B6B6AA (Gris claro)
      color_txt   <= 8'b000_000_00; // (blanco)
      color_bkn   <= 8'b111_111_11; // (negro)
    end else begin
    if (px_x)
  // (TODO) Agregar las entradas de la paleta de colores
      for(i=0;i<16;i=i+1) begin
        if (WrPalReg[i])
          Palette[i] <= character;
        end
      if (WrPalReg[16]) color_bkn <= character;
      if (WrPalReg[17]) color_txt <= character;
      
    end
  end


  
  //-- Generador de patrones 8x8
  wire [63:0] letra;
  asciiTo8x8 Gen_patron( 
   .character(character),
   .letra(letra)); 

  reg [7:0] px_fila;
  reg px_bit;
  reg [7:0] px_color, px_txt,px_palette;

  wire valid_palette = (character[7:4] == 4'b0);
  always @(*) begin
    case(px_y[2:0]) 
      7: px_fila = letra[ 7: 0];
      6: px_fila = letra[15: 8];
      5: px_fila = letra[23:16];
      4: px_fila = letra[31:24];
      3: px_fila = letra[39:32];
      2: px_fila = letra[47:40];
      1: px_fila = letra[55:48];
      0: px_fila = letra[63:56];
    endcase

    px_bit = px_fila >> px_x ;
  

    px_txt = valid_palette? Palette[character[3:0]] : (px_bit? color_txt : color_bkn);
    px_color = character;//
    if ((px_x==3'h0 || px_x==3'h7) && (px_y==3'h0 || px_y==3'h7))
      px_color = 8'b0;
  end

  wire [7:0] demo_BRAM1 = character;
  wire [7:0] demo_BRAM2 = px_color;
  wire [7:0] demo_TEXT = px_txt;
  
  // ############################ ############################ ############################
  // ############################ #########  DEMOS  ########## ############################
  // ############################ ############################ ############################

  

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
  //-- Demos sencillas con los colores RGB
  wire [7:0] demo_1 = {cnt_red,3'b0,2'b0};
  wire [7:0] demo_2 = {3'b0,cnt_green,2'b0};
  wire [7:0] demo_3 = {3'b0,3'b0,cnt_blue};
  wire [7:0] demo_4 = {cnt_red,3'b0,cnt_blue};
  wire [7:0] demo_5 = {3'b0,cnt_green,cnt_blue};
  wire [7:0] demo_6 = {cnt_red,cnt_green,2'b0};
  wire [7:0] demo_7 = {cnt_red,cnt_green,cnt_blue};
  wire [7:0] demo_8 = cnt_colour_demo;
  wire [7:0] demo_9 = frame_cnt[22:15];
  
  //-- Seleccion del color
  reg [3:0] isel1,isel2;
  reg [7:0] sel_color;
  always @(posedge px_clk) begin
    if (rst) 
      {isel2,isel1} <= 0;
    else 
      {isel2,isel1} <= {isel1,i_sel_demo};
  end
  
  always @(*) begin
    case (isel2)
      0: sel_color = demo_TEXT;
      1: sel_color = demo_1;
      2: sel_color = demo_2;
      3: sel_color = demo_3;
      4: sel_color = demo_4;
      5: sel_color = demo_5;
      6: sel_color = demo_6;
      7: sel_color = demo_7;
      8: sel_color = demo_8;
      9: sel_color = demo_9;
      14:sel_color = demo_BRAM1;
      15:sel_color = demo_BRAM2; 
      default :
         sel_color = 0;
    endcase
  end


  SB_IO #(
    .PIN_TYPE(6'b0101_00) // 0101: latched output / 00: no input
  ) user_IO[9:0] (         // Yes, in Verilog you can declare 4 pins in 1 decl
    .PACKAGE_PIN( {o_red[2:0],o_green[2:0],o_blue[1:0],  o_vsync, o_hsync}),
    .D_OUT_0({blank?8'b0:sel_color[7:0], vsync_q, hsync_q}),
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
  assign o_hsync  = (~HPOL) ^ ((o_hcnt >= (HACTIVE + HFP -1)) && (o_hcnt < (HACTIVE + HFP + HSYNCLEN)));
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
  reg [63:0] letra;
  `include "font8x8.vh"
  always @(*) begin
    case (character)
      16: letra = _cRISCV;
      17: letra = _cRISCV_;

      " ": letra = _cSPACE; // space
      "!": letra = _cEXCL;
     "\"": letra = _cQUOT;
      "#": letra = _cNUMBER;
      "$": letra = _cDOLLAR;
      "%": letra = _cPERCNT;
      "&": letra = _cAMP;
      "'": letra = _cAPOS;
      "(": letra = _cLBR;
      ")": letra = _cRBR;
      "*": letra = _cAST;
      "+": letra = _cPLUS;
      ",": letra = _cCOMMA;
      "-": letra = _cMINUS;
      ".": letra = _cDOT;
      "/": letra = _cSLASH;

      "0": letra = _c0;
      "1": letra = _c1;
      "2": letra = _c2;
      "3": letra = _c3;
      "4": letra = _c4;
      "5": letra = _c5;
      "6": letra = _c6;
      "7": letra = _c7;
      "8": letra = _c8;
      "9": letra = _c9;

      ":": letra = _cCOLON;
      ";": letra = _cSEMIC;
      "<": letra = _cLT;
      "=": letra = _cEQ;
      ">": letra = _cGT;
      "?": letra = _cQUEST;
      "@": letra = _cAT;

      "A": letra = _cA;
      "B": letra = _cB;
      "C": letra = _cC;
      "D": letra = _cD;
      "E": letra = _cE;
      "F": letra = _cF;
      "G": letra = _cG;
      "H": letra = _cH;
      "I": letra = _cI;
      "J": letra = _cJ;
      "K": letra = _cK;
      "L": letra = _cL;
      "M": letra = _cM;
      "N": letra = _cN;
      "O": letra = _cO;
      "P": letra = _cP;
      "Q": letra = _cQ;
      "R": letra = _cR;
      "S": letra = _cS;
      "T": letra = _cT;
      "U": letra = _cU;
      "V": letra = _cV;
      "W": letra = _cW;
      "X": letra = _cX;
      "Y": letra = _cY;
      "Z": letra = _cZ;

      "[": letra = _cLSQBR;
     "\\": letra = _cBKSLASH;
      "]": letra = _cRSQBR;
      "^": letra = _cHAT;
      "_": letra = _cLOWBAR;
      "`": letra = _cGRAVE;

      "a": letra = _cA_;
      "b": letra = _cB_;
      "c": letra = _cC_;
      "d": letra = _cD_;
      "e": letra = _cE_;
      "f": letra = _cF_;
      "g": letra = _cG_;
      "h": letra = _cH_;
      "i": letra = _cI_;
      "j": letra = _cJ_;
      "k": letra = _cK_;
      "l": letra = _cL_;
      "m": letra = _cM_;
      "n": letra = _cN_;
      "o": letra = _cO_;
      "p": letra = _cP_;
      "q": letra = _cQ_;
      "r": letra = _cR_;
      "s": letra = _cS_;
      "t": letra = _cT_;
      "u": letra = _cU_;
      "v": letra = _cV_;
      "w": letra = _cW_;
      "x": letra = _cX_;
      "y": letra = _cY_;
      "z": letra = _cZ_;

      "{": letra = _cLCUBR;
      "|": letra = _cVBAR ;
      "}": letra = _cRCUBR;
      "~": letra = _cTILDE;
      default:
        letra = _cSPACE; 
    endcase

  end
endmodule
