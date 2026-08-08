// =============================================================
// Module: baud_rate_gen
// Description: Generates a single-cycle 'tick' pulse at the
//              configured baud rate, derived from the system
//              clock. Acts as the timing reference for uart_tx.
// =============================================================
module baud_rate_gen #(
    parameter CLK_FREQ  = 50_000_000,   // system clock frequency (Hz)
    parameter BAUD_RATE = 9600          // desired UART baud rate
)(
    input  wire clk,
    input  wire rst_n,     // active-low async reset
    output reg  tick        // 1-cycle pulse at the baud rate
);

    localparam DIVISOR = CLK_FREQ / BAUD_RATE;

    reg [$clog2(DIVISOR)-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end

endmodule
