// =============================================================
// Testbench: tb_uart
// Description: Self-checking loopback testbench.
//   - Instantiates baud_rate_gen, uart_tx, uart_rx
//   - Connects tx_line directly to rx_line (loopback)
//   - Drives tx_start with a single test byte
//   - Automatically compares rx_data against tx_data and
//     prints PASS/FAIL to the simulation console
// =============================================================
module tb_uart;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;

    wire       baud_tick;
    wire       tx_line, tx_busy;
    wire       rx_done;
    wire [7:0] rx_data;

    // ---- Clock generation: 50 MHz (20 ns period) ----
    always #10 clk = ~clk;

    // ---- DUT instances ----
    uart_tx tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tick(baud_tick),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .tx_line(tx_line)
    );

    uart_rx rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_line(tx_line),     // loopback: TX output feeds RX input directly
        .rx_done(rx_done)
    );

    baud_rate_gen brg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tick(baud_tick)
    );

    // ---- Reset + stimulus ----
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        clk      = 0;
        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'h00;
        #100;
        rst_n = 1;

        // send one test byte
        tx_data  <= 8'b1100_1100;
        tx_start <= ~tx_start;
        #20 tx_start <= ~tx_start;

        #1100000;   // enough for 1 full UART frame (~1,041,600 ns) at 9600 baud
        $finish;
    end

    // ---- Self-checking: compare received byte against sent byte ----
    always @(posedge rx_done) begin
        if (rx_data == tx_data) begin
            $display("PASS: Sent = %b, Received = %b", tx_data, rx_data);
        end else begin
            $display("FAIL: Sent = %b, Received = %b", tx_data, rx_data);
        end
    end

endmodule
