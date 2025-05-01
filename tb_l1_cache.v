module tb_l1_cache;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam CACHE_SIZE = 1024;
    localparam BLOCK_SIZE = 16;
    localparam NUM_WAYS = 4;

    reg clk;
    reg rst_n;

    // CPU interface
    reg [ADDR_WIDTH-1:0] cpu_addr;
    reg [DATA_WIDTH-1:0] cpu_data_in;
    wire [DATA_WIDTH-1:0] cpu_data_out;
    reg cpu_read;
    reg cpu_write;
    wire cpu_ready;
    wire cpu_hit;

    // L2 Cache interface
    wire [ADDR_WIDTH-1:0] l2_cache_addr;
    wire [DATA_WIDTH-1:0] l2_cache_data_out; // Data to be written to l2 cache
    reg [DATA_WIDTH-1:0] l2_cache_data_in; // Data read from l2 cache
    wire l2_cache_read;
    wire l2_cache_write;
    wire l2_cache_ready;
    wire l2_cache_hit;

    // Instantiate the L1 cache
    L1_cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CACHE_SIZE(CACHE_SIZE),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_WAYS(NUM_WAYS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        .cpu_read(cpu_read),
        .cpu_write(cpu_write),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .l2_cache_addr(l2_cache_addr),
        .l2_cache_data_out(l2_cache_data_out), // Data to be written to l2 cache
        .l2_cache_data_in(l2_cache_data_in), // Data read from l2 cache
        .l2_cache_read(l2_cache_read),
        .l2_cache_write(l2_cache_write),
        .l2_cache_ready(l2_cache_ready),
        .l2_cache_hit(l2_cache_hit)
    );

    // connect to L1 cache to memory
    memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE)
    ) mem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(l2_cache_addr),
        .data_in(l2_cache_data_out),
        .data_out(l2_cache_data_in),
        .read(l2_cache_read),
        .write(l2_cache_write),
        .ready(l2_cache_ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 time units clock period
    end

    // Testbench stimulus
    initial begin
    end
endmodule