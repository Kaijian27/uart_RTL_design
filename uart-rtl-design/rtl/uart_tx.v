// =============================================================
// Module: uart_tx
// Description: UART transmitter. Sends an 8-bit byte as a
//              standard UART frame: 1 start bit (low), 8 data
//              bits (LSB first), 1 stop bit (high).
// FSM: IDLE -> START -> DATA (x8) -> STOP -> IDLE
// =============================================================
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire        tick,       // baud tick from baud_rate_gen
    input  wire        tx_start,   // pulse: begin sending tx_data
    input  wire [7:0]  tx_data,    // byte to transmit
    output reg          tx_line,    // serial output line
    output reg          tx_busy     // high while a frame is in flight
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;
    reg [2:0] bit_index;
    reg [7:0] tx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx_line   <= 1'b1;
            tx_busy   <= 1'b0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_line <= 1'b1;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                START: begin
                    tx_line <= 1'b0;
                    if (tick) begin
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx_line <= tx_shift[0];
                    if (tick) begin
                        tx_shift  <= tx_shift >> 1;
                        bit_index <= bit_index + 1;
                        if (bit_index == 7) begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_line <= 1'b1;
                    if (tick) begin
                        state   <= IDLE;
                        tx_busy <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
