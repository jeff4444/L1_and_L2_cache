
// Simple testbench remains unchanged
module L2_cache_tb;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter CACHE_SIZE = 32;
    parameter BLOCK_SIZE = 4;
    parameter NUM_WAYS   = 2;

    reg                           clk = 0;
    reg                           rst_n;
    reg  [ADDR_WIDTH-1:0]         l1_addr;
    reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_data_in;
    wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_data_out;
    wire                          l1_valid, l1_ready, l1_hit;
    reg                           l1_read, l1_write;
    reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_block;
    reg                           mem_ready;
    wire [ADDR_WIDTH-1:0]         mem_addr;
    wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out;
    wire                          mem_read, mem_write;

    // Instantiate DUT
    L2_cache #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_SIZE(CACHE_SIZE), .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_WAYS(NUM_WAYS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .l1_cache_addr(l1_addr),
        .l1_cache_data_in(l1_data_in),
        .l1_block_data_out(l1_data_out),
        .l1_block_valid(l1_valid),
        .l1_cache_read(l1_read),
        .l1_cache_write(l1_write),
        .l1_cache_ready(l1_ready),
        .l1_cache_hit(l1_hit),
        .mem_data_block(mem_data_block),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_read(mem_read),
        .mem_write(mem_write)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Reset
        rst_n = 0; mem_ready = 0;
        l1_read = 0; l1_write = 0;
        #12; rst_n = 1;

        // Read miss -> fetch block
        @(posedge clk);
        l1_addr = 4'hA;
        l1_read = 1;
        mem_data_block = '{default: 8'hFF};
        @(posedge clk);
        mem_ready = 1;
        @(posedge clk);
        $display("Read miss: valid=%b ready=%b hit=%b data_out=%h", l1_valid, l1_ready, l1_hit, l1_data_out[0]);
        mem_ready = 0;
        l1_read = 0;

        // Read hit
        @(posedge clk);
        l1_read = 1;
        @(posedge clk);
        $display("Read hit: valid=%b ready=%b hit=%b data_out=%h", l1_valid, l1_ready, l1_hit, l1_data_out[0]);
        l1_read = 0;

        // Write miss -> write-allocate
        @(posedge clk);
        l1_addr = 4'hB;
        l1_data_in = '{default: 8'hBB};
        l1_write = 1;
        @(posedge clk);
        $display("Write miss: valid=%b ready=%b hit=%b mem_write=%b", l1_valid, l1_ready, l1_hit, mem_write);
        l1_write = 0;

        // Write hit
        @(posedge clk);
        l1_addr = 4'hB;
        l1_data_in = '{default: 8'hCC};
        l1_write = 1;
        @(posedge clk);
        $display("Write hit: valid=%b ready=%b hit=%b mem_write=%b", l1_valid, l1_ready, l1_hit, mem_write);
        l1_write = 0;

        $finish;
    end
endmodule
