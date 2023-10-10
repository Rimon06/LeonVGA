`default_nettype none


module top(
  input clk12MHz,
  // Perifericos dentro de la placa icefun
  input [3:0] key,
  output [7:0] led,
  output [3:0] lcol,
  
  // Conexion con memoria flash!
  output [2:0] vga_red, 
  output [2:0] vga_green,
  output [1:0] vga_blue,
  output       vga_hsync,
  output       vga_vsync);

    // --- inicializador ---
  reg rst=1;
  reg [9:0] Espera=8'b0; // La espera es de 256 ciclos de reloj para que la memoria BRAM esté funcional
  always @(posedge clk12MHz) begin // (TODO) pueden ser menos ciclos....
    if (Espera == 9'h1FF) 
      rst <= 0;
    else  Espera <= Espera+1;
  end

  reg [3:0] sel_demo;
  wire [31:0] framecnt;
  
  VGA pantalla__UUT (
    .clk(clk12MHz),
    .rst(rst),
    .i_sel_demo(sel_demo),
    .o_red(vga_red),
    .o_green(vga_green),
    .o_blue(vga_blue),
    .o_hsync(vga_hsync),
    .o_vsync(vga_vsync),
    .o_framecnt(framecnt)
  );

  always @(posedge clk12MHz) begin
    if (rst) begin
      sel_demo <= 0;
    end else begin
      if (key0_up)
        sel_demo <= sel_demo + 1;
      else if (key1_up)
        sel_demo <= sel_demo - 1;
    end 
  end

  wire key0_up, key1_up;
  debouncer_tic key0_tic(
    .clk(clk12MHz),
    .d(!key[0]),
    .tic_p(key0_up)
  );

  debouncer_tic key1_tic(
    .clk(clk12MHz),
    .d(!key[1]),
    .tic_p(key1_up)
  );

  reg [7:0] leds1,leds2,leds3,leds4;
  always @(posedge clk12MHz) begin 
    if (rst) begin
      {leds4,leds3,leds2,leds1} <= 32'h00000000;
    end else begin
      {leds4,leds3,leds2,leds1} <= framecnt;
    end
  
  end

  // -- Controlador de Matrices led ...
  ControladorMatrizLed LEDS8_4(
    .clk12Mhz(clk12MHz),
    .rst(rst),//&(!leds_en)), 
    .leds1(leds1),    
    .leds2(leds2),
    .leds3(leds3),
    .leds4(leds4),
    .leds(led), 
    .lcol(lcol)
  );
  

endmodule
