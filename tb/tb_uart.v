// =============================================================
// Testbench: tb_uart
// Description: Self-checking loopback testbench.
//   - Instantiates baud_rate_gen, uart_tx, uart_rx
//   - Connects tx_line directly to rx_line (loopback)
//   - Drives tx_start with a single test byte
//   - Automatically compares rx_data against tx_data and
//     prints PASS/FAIL to the simulation console
// =============================================================
`timescale 1ns/1ps

module tb_uart;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;
    reg [7:0] test_bytes [0:3];
    integer i;


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

    task send_and_check(input [7:0] data);
    begin
        tx_data = data;
        tx_start <= ~tx_start;
        #20 tx_start <= ~tx_start;        

        #5
        wait(tx_busy == 0);

        if (rx_data == data) begin
            $display("PASS: Sent = %b, Received = %b", data, rx_data);
        end else begin
            $fatal(1, "FAIL: Sent = %b, Received = %b", data, rx_data);
        end 

    end
endtask

    // ---- Reset + stimulus ----
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        test_bytes[0] = 8'h00;    // all 0
        test_bytes[1] = 8'hFF;    // all 1
        test_bytes[2] = 8'hA5;    // 10100101 
        test_bytes[3] = 8'h55;    // 01010101 

        clk      = 0;
        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'h00;
        #100;
        rst_n = 1;

        for(i=0; i<4 ; i=i+1)begin
            send_and_check(test_bytes[i]);
        end
        
        $display("All tests finished.");
        $finish; 
    end

    initial begin //if data stuck, it will end by fatal
        #5_000_000;   
        $fatal(1, "FAIL: testbench timed out - something is stuck");

    end

endmodule
