// =============================================================
// Module: uart_rx
// Description: UART receiver. Detects a start bit on rx_line,
//              samples 8 data bits at the middle of each bit
//              period, and latches the received byte.
// FSM: IDLE -> START -> DATA (x8) -> STOP -> IDLE
//
// Note: unlike uart_tx, this module does NOT use an external
// baud tick. It runs its own free-running counter starting
// from the moment it detects the falling edge of rx_line,
// since the receiver has no shared clock with the transmitter
// (UART is an asynchronous protocol).
// =============================================================
module uart_rx #(
    parameter DIVISOR = 5208    // must match CLK_FREQ/BAUD_RATE used by TX side
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire        rx_line,
    output reg  [7:0]  rx_data,
    output reg          rx_done    // 1-cycle pulse when a byte has been received
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [12:0] counter;
    reg [2:0]  bit_index;
    reg [7:0]  rx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            counter   <= 0;
            bit_index <= 0;
            rx_done   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    rx_done <= 0;
                    if (rx_line == 1'b0) begin   // falling edge -> possible start bit
                        counter <= 0;
                        state   <= START;
                    end
                end

                START: begin
                    // wait half a bit period to land in the middle of the start bit
                    if (counter == (DIVISOR/2 - 1)) begin
                        counter <= 0;
                        state   <= DATA;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                DATA: begin
                    // wait a full bit period between samples, sampling at the midpoint
                    if (counter == (DIVISOR - 1)) begin
                        counter   <= 0;
                        rx_shift  <= {rx_line, rx_shift[7:1]};
                        bit_index <= bit_index + 1;
                        if (bit_index == 7) begin
                            state <= STOP;
                        end
                    end else begin
                        counter <= counter + 1;
                    end
                end

                STOP: begin
                    if (counter == (DIVISOR - 1)) begin
                        rx_data <= rx_shift;
                        rx_done <= 1;
                        state   <= IDLE;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            endcase
        end
    end

endmodule
