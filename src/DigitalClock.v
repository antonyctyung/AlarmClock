module clockGen(
    input clk,
    input reset,
    output reg clk400Hz,
    output reg clk1Hz
);
    reg [23:0] counter400Hz;
    reg [9:0] counter1Hz;
    always @ (posedge clk)
    begin
    if (reset)
        begin
        counter400Hz=0;
        clk1Hz=0;
        end
    else
        begin
        counter400Hz = counter400Hz +1;
        if (counter400Hz == 125_000)            // half period of 400 Hz i.e. 1.25ms
            begin
            clk400Hz=~clk400Hz;
            counter400Hz = 0;
            counter1Hz = counter1Hz + 1;
            end
        end
        if (counter1Hz == 400)                  // half period of 1Hz i.e. 400x1.25ms = 0.5s
            begin
            clk1Hz=~clk1Hz;   
            counter1Hz = 0;
            end
    end
endmodule

module counter2bit (Resetn, Clock, E, Q);
    input Resetn, Clock, E;
    output reg [1:0] Q;
    always @(negedge Resetn, posedge Clock)
         if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= Q + 1;
endmodule

module counter60 (D, Load, Resetn, Clock, E, Q);
    input [5:0] D;
    input Load, Resetn, Clock, E;
    output reg [5:0] Q;
    always @(posedge Load, negedge Resetn, posedge Clock)
        if (Load)
            Q <= D;
        else if (!Resetn || Q > 58)
            Q <= 0;
        else if (E)
            Q <= Q + 1;
endmodule

module SevenSegmentDecoder(d,C);                // encode binary input to display hex on 7-seg
    input [3:0] d;                              // 4-bit (sign magnitude) integer
    output reg [1:7] C;                         // to 7-segment cathode { CA, CB, ... , CG }
   always @*
   begin
      case(d)
         'h0:  C=7'b0000001;
         'h1:  C=7'b1001111;
         'h2:  C=7'b0010010;
         'h3:  C=7'b0000110;
         'h4:  C=7'b1001100;
         'h5:  C=7'b0100100;
         'h6:  C=7'b0100000;
         'h7:  C=7'b0001111;
         'h8:  C=7'b0000000;
         'h9:  C=7'b0000100;
         'hA:  C=7'b0001000;
         'hB:  C=7'b1100000;
         'hC:  C=7'b0110001;
         'hD:  C=7'b1000010;
         'hE:  C=7'b0110000;
         'hF:  C=7'b0111000;
         default: 
            C=7'b1111111;                       // default to off
      endcase
   end
endmodule

module dec2to4 (W, En, Y);
    input [1:0] W;
    input En;
    output reg [3:0] Y;
  
    always @(W, En)
    begin
        case ({En, W})
        4'b100: Y = 4'b1110;
        4'b101: Y = 4'b1101;
        4'b110: Y = 4'b1011;
        4'b111: Y = 4'b0111;
        endcase
    end
endmodule

module minuteClkGen (
    input [5:0] second,
    output clkMinute
);
    assign clkMinute = !(second[5]);               // posedge when all 0
endmodule

module sixBitBinaryToTwoDisplayDecoder(
    input [5:0] x,
    output [1:7] CUpper,
    output [1:7] CLower
);
    wire [3:0] Upper;
    wire [3:0] Lower;
    assign Upper = x/10;
    assign Lower = x%10;
    SevenSegmentDecoder ssdUpper(Upper,CUpper);
    SevenSegmentDecoder ssdLower(Lower,CLower);
endmodule

module sevenBits4x1Mux(
    input [1:0] select,
    input [1:28] D,
    output reg [1:7] C
);
    always @(select)
    begin
        case (select)
        0: C = D[ 1: 7];
        1: C = D[ 8:14];
        2: C = D[15:21];
        3: C = D[22:28];
        endcase
    end
endmodule


module DigitalClock(
    input CLK100MHZ,                    // 100MHz system clock
    input load,                         // Load
    input reset,                         // Reset (posedge)
    input [15:0] SW,                    // Switches to load min=SW[13:8] sec=SW[5:0] 
    output CA,CB,CC,CD,CE,CF,CG,DP,     // Seven segment display inputs
    output [7:0] AN,                     // Seven segment display enable
    output [5:0] secondout,
    output [5:0] minuteout
    );
    
    wire [1:0] select;                  // mux select / 7-seg enable
    wire [1:28] minSec7SegCode;         // four digits 7-seg code
    wire [5:0] second;                  // unsigned integer representation of seconds
    wire [5:0] minute;                  // unsigned integer representation of minutes
    assign secondout = second;
    assign minuteout = minute;

    clockGen     cgn(CLK100MHZ, reset, clk400Hz, clk1Hz);
    counter2bit  c2b(!reset,clk400Hz,1,select);
    dec2to4      dec(select,1,AN[3:0]);
    minuteClkGen mcg(second, clkMinute);
    counter60 sec(SW[ 5:0], load, !reset, clk1Hz   , 1, second);
    counter60 min(SW[13:8], load, !reset, clkMinute, 1, minute);
    sixBitBinaryToTwoDisplayDecoder secdec(second, minSec7SegCode[ 8:14],minSec7SegCode[ 1: 7]);
    sixBitBinaryToTwoDisplayDecoder mindec(minute, minSec7SegCode[22:28],minSec7SegCode[15:21]);
    sevenBits4x1Mux mux(select, minSec7SegCode,{CA,CB,CC,CD,CE,CF,CG});

    assign AN[7:4] = 4'hF;              // disable upper 4 7-seg display
    assign DP = 1;                      // disable decimal point
    
endmodule