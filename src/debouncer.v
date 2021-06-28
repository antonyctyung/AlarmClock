module debouncer(
        input clk,
        input sw,
        output db
    );
    
    // 10 ms tick generation
    reg [20:0] counter;
    always @(posedge clk)
        counter = (counter == 999999)? 0 : counter + 1;
    wire m_tick;
    assign m_tick = ~|counter;

    // state alias
    localparam [2:0] 
        zero    = 3'b000,
        wait1_1 = 3'b001,
        wait1_2 = 3'b010,
        wait1_3 = 3'b011,
        one     = 3'b100,
        wait0_1 = 3'b101,
        wait0_2 = 3'b110,
        wait0_3 = 3'b111;
    
    // state registers
    reg [2:0] state_reg;
    reg [2:0] state_next;

    // output
    assign db = state_reg[2];

    // state progression
    always @(posedge clk)
        state_reg <= state_next;
    
    // state behavior
    always @*
        begin
            state_next = state_reg;
            case (state_reg)
                zero:
                    if (sw)
                        state_next = wait1_1;
                wait1_1:
                    if (!sw)
                        state_next = zero;
                    else if (m_tick)
                        state_next = wait1_2;
                wait1_2:
                    if (!sw)
                        state_next = zero;
                    else if (m_tick)
                        state_next = wait1_3;
                wait1_3:
                    if (!sw)
                        state_next = zero;
                    else if (m_tick)
                        state_next = one;
                one:
                    if (!sw)
                        state_next = wait0_1;
                wait0_1:
                    if (sw)
                        state_next = one;
                    else if (m_tick)
                        state_next = wait0_2;
                wait0_2:
                    if (sw)
                        state_next = one;
                    else if (m_tick)
                        state_next = wait0_3;
                wait0_3:
                    if (sw)
                        state_next = one;
                    else if (m_tick)
                        state_next = zero;
                default:
                    state_next = zero;
            endcase
        end
endmodule