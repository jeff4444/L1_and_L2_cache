`timescale 1ns/1ns

module tb_L2_cache;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter CACHE_SIZE = 1024;
    parameter BLOCK_SIZE = 16;
    parameter NUM_WAYS = 4;
    parameter L1_BLOCK_SIZE = 16;

    // DUT I/O
    reg clk, rst_n;
    reg [ADDR_WIDTH-1:0] l2_cache_addr;
    reg [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_in;
    wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_out;
    reg l2_cache_read, l2_cache_write;
    wire l2_cache_ready, l2_hit;

    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out;
    reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_in;
    wire mem_read, mem_write;
    reg mem_ready, mem_hit;

    integer i;

    // Instantiate DUT
    L2_cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_SIZE(CACHE_SIZE),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_WAYS(NUM_WAYS),
        .L1_BLOCK_SIZE(L1_BLOCK_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .l2_cache_addr(l2_cache_addr),
        .l2_cache_data_in(l2_cache_data_in),
        .l2_cache_data_out(l2_cache_data_out),
        .l2_cache_read(l2_cache_read),
        .l2_cache_write(l2_cache_write),
        .l2_cache_ready(l2_cache_ready),
        .l2_hit(l2_hit),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_ready(mem_ready),
        .mem_hit(mem_hit)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Task to init input data
    task fill_data_block;
        output [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] block;
        input [31:0] base;
        integer j;
        begin
            for (j = 0; j < BLOCK_SIZE; j = j + 1)
                block[j] = base + j;
        end
    endtask

    initial begin
        $display("---- L2 Cache Testbench START ----");
        $dumpfile("tb_L2_cache.vcd");
        $dumpvars(0, tb_L2_cache);

        clk = 0;
        rst_n = 0;
        l2_cache_read = 0;
        l2_cache_write = 0;
        l2_cache_addr = 0;
        mem_ready = 0;
        mem_hit = 0;

        // Reset
        #10 rst_n = 1;

        // Fill memory data
        fill_data_block(mem_data_in, 32'h1000);
        mem_ready = 1;
        mem_hit = 1;

        // Issue read request (MISS expected)
        #10;
        l2_cache_addr = 32'h00000040; // Some random aligned block address
        l2_cache_read = 1;

        #10;
        l2_cache_read = 0;

        // Wait for allocation
        wait (l2_cache_ready);
        $display("READ RESULT: %h", l2_cache_data_out[0]);

        // Read same address again (HIT expected)
        #20;
        l2_cache_addr = 32'h00000040;
        l2_cache_read = 1;

        #10;
        l2_cache_read = 0;

        wait (l2_cache_ready);
        $display("READ-HIT RESULT: %h", l2_cache_data_out[0]);

        #40;
        $display("---- L2 Cache Testbench END ----");
        $finish;
    end

endmodule
