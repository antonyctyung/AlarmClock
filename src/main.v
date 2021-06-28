`timescale 1ns / 1ps
`include "SoundGen.v"
`include "debouncer.v"
`include "DigitalClock.v"

module AlarmTimer(
    input clk1Hz,
    input alarmEnable,
    input reset,
    input [5:0] alarmSecond,
    input [5:0] alarmMinute,
    input [5:0] clockSecond,
    input [5:0] clockMinute,
    output reg soundEnable
);

reg [5:0] counter; 

assign startSound = ((alarmMinute == clockMinute) && (alarmSecond == clockSecond))? 1:0;

always @(posedge clk1Hz, posedge startSound, posedge reset)
begin
    if (counter > 58 || reset)
        begin
            counter = 0;
            soundEnable = 0;
        end
    else if (startSound && !soundEnable && alarmEnable) 
        soundEnable = 1;
    else if (soundEnable)
        counter = counter+1;
end

endmodule

module SwitchingTimeDisplayDriver4Digit
(
    input clk400Hz,
    input reset,
    input [5:0] second,
    input [5:0] minute,
    output [1:16] CAN
);
    wire CA,CB,CC,CD,CE,CF,CG,DP;
    wire [7:0] AN;                     // Seven segment display enable

    wire [1:0] select;
    wire [ 1:28] minSec7SegCode;

    counter2bit  c2b(!reset,clk400Hz,1,select);
    dec2to4      dec(select,1,AN[7:4]);
    sixBitBinaryToTwoDisplayDecoder secdec(second, minSec7SegCode[ 8:14],minSec7SegCode[ 1: 7]);
    sixBitBinaryToTwoDisplayDecoder mindec(minute, minSec7SegCode[22:28],minSec7SegCode[15:21]);
    sevenBits4x1Mux mux(select, minSec7SegCode,{CA,CB,CC,CD,CE,CF,CG});
    assign AN[3:0] = 4'hF;              // disable upper 4 7-seg display
    assign DP = 1;                      // disable decimal point
    assign CAN = {CA,CB,CC,CD,CE,CF,CG,DP,AN[7:0]};

endmodule

module CANrot
(
    input [1:16] CAN0,  //{CA:CG,DP,AN}
    input [1:16] CAN1,  
    input clk400Hz,
    output [1:16] Q
);

reg [2:0] counter = 0;

always @(posedge clk400Hz)
    counter = counter + 1;

assign Q = (counter[2])? CAN1 : CAN0 ;

endmodule

module T_Flip_Flop(T, Clk, Q, QBar);
    input T;
    input Clk;
    output Q;
    output QBar;
	reg Q;
	always@(posedge Clk)
	    begin
		    if (T)
			    Q<=~Q;
            else	
			    Q<=Q;
	    end
    assign QBar = ~Q;
endmodule


module AlarmClock(
    input BTNC, BTNL, BTNR, BTNU, BTND,
    input CLK100MHZ,
    input [15:0] SW,
    output CA,CB,CC,CD,CE,CF,CG,DP,
    output [7:0] AN,
    output AUD_PWM, AUD_SD,
    output [0:0] LED
);
    assign reset = BTNR;
    assign load  = BTNL;
    assign alarmTimeSetBTN = BTND;
    assign stop  = BTNC;
    assign alarmEnableBTN = BTNU;

    reg [5:0] alarmSecond = 0;
    reg [5:0] alarmMinute = 0;
    wire [5:0] clockSecond;
    wire [5:0] clockMinute;
    wire [1:16] clockCAN; //{CA:CG,DP,AN}
    wire [1:16] alarmCAN; //{CA:CG,DP,AN}

    clockGen     cgn(CLK100MHZ, reset, clk400Hz, clk1Hz);
    DigitalClock dck(CLK100MHZ,load,reset,SW,clockCAN[1],clockCAN[2],clockCAN[3],clockCAN[4],clockCAN[5],clockCAN[6],clockCAN[7],clockCAN[8],clockCAN[9:16],clockSecond[5:0],clockMinute[5:0]);
    SoundGen sgn(CLK100MHZ, reset, soundEnable, AUD_PWM, AUD_SD);
    AlarmTimer atm(clk1Hz, alarmEnable, |{stop,reset}, alarmSecond[5:0], alarmMinute[5:0], clockSecond[5:0], clockMinute[5:0], soundEnable);

    debouncer db1(CLK100MHZ, alarmEnableBTN, alarmEnableDB);
    T_Flip_Flop tff(alarmEnableDB, alarmEnableDB, alarmEnable, dummy);

    always @(posedge CLK100MHZ)
    begin
        if (alarmTimeSetBTN)
        begin
            alarmMinute = SW[15:8];
            alarmSecond = SW[7:0];
        end
    end

    assign LED[0] = alarmEnable;

    SwitchingTimeDisplayDriver4Digit std(clk400Hz, reset, alarmSecond[5:0], alarmMinute[5:0], alarmCAN[1:16]);
    CANrot crot(clockCAN[1:16], alarmCAN[1:16], clk400Hz, {CA,CB,CC,CD,CE,CF,CG,DP,AN[7:0]});
    
endmodule


