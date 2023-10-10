
module debouncer_tic(
  input clk,
  input d,
  output state,
  output tic_n,
  output tic_p
  );//################################################################################################

  //-- Sincronizacion. Evitar problema de la metaestabilidad
  reg d2, r_in;

  always @(posedge clk) begin
    {r_in,d2}  <= {d2,d};
  end

  //-- Debouncer Circuit
  //   It produces a stable output when the input signal is bouncing
  reg btn_prev = 0;
  reg btn_out_r = 0;
  reg [9:0] counter = 0;

  always @(posedge clk) begin
    // If btn_prev and btn_in are differents
    if (btn_prev ^ r_in) begin
      counter <= 0; // Reset the counter
      btn_prev <= r_in; // Capture the button status
    end
    else if (counter[9] == 1'b0)
      //-- If no timeout, increase the counter
      counter <= counter + 1;    
    else
      //-- Set the output to the stable value
      btn_out_r <= btn_prev;
  end

  //-- Generar tic en flanco de subida del boton
  reg old;
  always @(posedge clk)     old <= btn_out_r;
  
  assign tic_n = !old & btn_out_r;

  assign tic_p = old & !btn_out_r;

  //-- El estado del pulsador se saca por state
  assign state = btn_out_r;

endmodule //######################################################################################

module ascciTo8x8(
  input [7:0] character,
  output reg [63:0] letra
  );
  `include "./../../SPI/4x8font.vh"

  always @(*) begin
    case (character)
      "a","A": letra <= _cA;
      "b","B": letra <= _cB;
      "c","C": letra <= _cC;
      "d","D": letra <= _cD;
      "e","E": letra <= _cE;
      "f","F": letra <= _cF;
      "g","G": letra <= _cG;
      "h","H": letra <= _cH;
      "i","I": letra <= _cI;
      "j","J": letra <= _cJ;
      "k","K": letra <= _cK;
      "l","L": letra <= _cL;
      "m","M": letra <= _cM;
      "n","N": letra <= _cN;
      "o","O": letra <= _cO;
      "p","P": letra <= _cP;
      "q","Q": letra <= _cQ;
      "r","R": letra <= _cR;
      "s","S": letra <= _cS;
      "t","T": letra <= _cT;
      "u","U": letra <= _cU;
      "v","V": letra <= _cV;
      "w","W": letra <= _cW;
      "x","X": letra <= _cX;
      "y","Y": letra <= _cY;
      "z","Z": letra <= _cZ;

      "0": letra <= _c0;
      "1": letra <= _c1;
      "2": letra <= _c2;
      "3": letra <= _c3;
      "4": letra <= _c4;
      "5": letra <= _c5;
      "6": letra <= _c6;
      "7": letra <= _c7;
      "8": letra <= _c8;
      "9": letra <= _c9;
      
      " ": letra <= _cSP; // space
      "!": letra <= _cEX;
      "?": letra <= _cQQ;
      ":": letra <= _cCO;
      ";": letra <= _cSC;
      ".": letra <= _cFS;

      "+": letra <= _cPLUS; // plus + 
      "-": letra <= _cMINUS;
      "/": letra <= _cDIVIDE; // divide / 
      "*": letra <= _cMULTIPLY; // multiply x
      "=": letra <= _cEQUALS; // equals = 

     "\\": letra <= _cFWDSLASH; // fwd slash \
      "[": letra <= _cOPENSQ; // open sq [
      "]": letra <= _cCLOSESQ; // close sq ]
      "(": letra <= _cOPENBR; // open br (
      ")": letra <= _cCLOSEBR; // close br )

      default:
        letra <= _cSP; 
    endcase
  end
endmodule