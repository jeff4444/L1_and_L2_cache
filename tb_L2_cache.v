// `timescale 1ns/1ps

// module tb_L2_cache;
//   initial $display("TIMESCALE OK at time %0t",$time);
//   parameter DATA_WIDTH = 32;
//   parameter ADDR_WIDTH = 11;
//   parameter BLOCK_SIZE = 32;
//   parameter NUM_WAYS   = 4;

//   reg                                     clk;
//   reg                                     rst_n;
//   reg  [ADDR_WIDTH-1:0]                   l1_cache_addr;
//   reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   l1_cache_data_in;
//   wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   l1_block_data_out;
//   wire                                    l1_block_valid;
//   reg                                     l1_cache_read;
//   reg                                     l1_cache_write;
//   wire                                    l1_cache_ready;
//   wire                                    l1_cache_hit;

//   reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   mem_data_block;
//   reg                                     mem_ready;
//   wire [ADDR_WIDTH-1:0]                   mem_addr;
//   wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   mem_data_out;
//   wire                                    mem_read;
//   wire                                    mem_write;
//   integer                                 i;

//   // instantiate the updated DUT (no L1_BLOCK_SIZE parameter)
//   L2_cache #(
//     .DATA_WIDTH (DATA_WIDTH),
//     .ADDR_WIDTH (ADDR_WIDTH),
//     .CACHE_SIZE (512),
//     .BLOCK_SIZE (BLOCK_SIZE),
//     .NUM_WAYS   (NUM_WAYS)
//   ) dut (
//     .clk               (clk),
//     .rst_n             (rst_n),

//     // L1 interface
//     .l1_cache_addr     (l1_cache_addr),
//     .l1_cache_data_in  (l1_cache_data_in),
//     .l1_block_data_out (l1_block_data_out),
//     .l1_block_valid    (l1_block_valid),
//     .l1_cache_read     (l1_cache_read),
//     .l1_cache_write    (l1_cache_write),
//     .l1_cache_ready    (l1_cache_ready),
//     .l1_cache_hit      (l1_cache_hit),

//     // Memory interface
//     .mem_data_block    (mem_data_block),
//     .mem_ready         (mem_ready),
//     .mem_addr          (mem_addr),
//     .mem_data_out      (mem_data_out),
//     .mem_read          (mem_read),
//     .mem_write         (mem_write)
//   );

//   // start message
//   initial begin
//     $display(">>> SIM STARTED at time %0t <<<", $time);
//   end

//   // clock generator
//   initial begin
//     clk = 0;
//     forever #5 clk = ~clk;
//   end

//   // stimulus
//   initial begin
//     rst_n = 0;
//     l1_cache_read  = 0;
//     l1_cache_write = 0;
//     l1_cache_addr  = 0;
//     mem_ready      = 0;
//     // zero arrays
//     for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
//       l1_cache_data_in[i] = {DATA_WIDTH{1'b0}};
//       mem_data_block[i]   = {DATA_WIDTH{1'b0}};
//     end
//     #20 rst_n = 1;
//     #10;

//     //--- READ MISS ---
//     @(posedge clk);
//       l1_cache_addr = 11'h00A;
//       l1_cache_read = 1;
//     @(posedge clk);
//       l1_cache_read = 0;
//       #1;
//       if (!mem_read) $display("ERROR: expected mem_read on miss");

//     // drive memory response
//     for (i = 0; i < BLOCK_SIZE; i = i + 1)
//       mem_data_block[i] = 32'hDEADBEEF ^ i;
//     mem_ready = 1;
//     @(posedge clk);
//       mem_ready = 0;
//       #1;
//       if (l1_block_valid && l1_cache_ready && !l1_cache_hit)
//         $display("PASS: read-miss allocate");
//       else
//         $display("FAIL: read-miss allocate");

//     //--- READ HIT ---
//     @(posedge clk);
//       l1_cache_addr = 11'h00A;
//       l1_cache_read = 1;
//     @(posedge clk);
//       l1_cache_read = 0;
//       #1;
//       if (l1_block_valid && l1_cache_ready && l1_cache_hit &&
//           l1_block_data_out[0] == (32'hDEADBEEF ^ 0))
//         $display("PASS: read-hit");
//       else
//         $display("FAIL: read-hit");

//     //--- WRITE MISS ---
//     @(posedge clk);
//       l1_cache_addr = 11'h014;
//       for (i = 0; i < BLOCK_SIZE; i = i + 1)
//         l1_cache_data_in[i] = 32'hA5A5A5A5 ^ i;
//       l1_cache_write = 1;
//     @(posedge clk);
//       l1_cache_write = 0;
//       #1;
//       if (mem_write && l1_cache_ready && !l1_cache_hit)
//         $display("PASS: write-miss allocate");
//       else
//         $display("FAIL: write-miss allocate");

//     //--- WRITE HIT ---
//     @(posedge clk);
//       l1_cache_addr = 11'h014;
//       for (i = 0; i < BLOCK_SIZE; i = i + 1)
//         l1_cache_data_in[i] = 32'h5A5A5A5A ^ i;
//       l1_cache_write = 1;
//     @(posedge clk);
//       l1_cache_write = 0;
//       #1;
//       if (mem_write && l1_cache_ready && l1_cache_hit)
//         $display("PASS: write-hit");
//       else
//         $display("FAIL: write-hit");

//     #20 $finish;
//   end
// endmodule


`timescale 1ns/1ps

module tb_L2_cache;
    // Parameters
    localparam DATA_WIDTH     = 32;
    localparam ADDR_WIDTH     = 32;
    localparam CACHE_SIZE     = 1024;
    localparam BLOCK_SIZE     = 16;
    localparam NUM_WAYS       = 4;
    localparam L1_BLOCK_SIZE  = 16;

    // Clock and reset
    reg clk;
    reg rst_n;

    // DUT interface signals
    reg  [ADDR_WIDTH-1:0]                       l2_cache_addr;
    reg  [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0]    l2_cache_data_in;
    wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0]    l2_cache_data_out;
    reg                                         l2_cache_read;
    reg                                         l2_cache_write;
    wire                                        l2_cache_ready;
    wire                                        l2_hit;

    // Memory interface signals
    wire [ADDR_WIDTH-1:0]                       mem_addr;
    wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]       mem_data_out;
    reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]       mem_data_in;
    wire                                        mem_read;
    wire                                        mem_write;
    reg                                         mem_ready;
    reg                                         mem_hit;

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
    initial clk = 0;
    always #5 clk = ~clk;

    // Test scenario
    initial begin
        // Initialize signals
        rst_n           = 1'b0;
        l2_cache_addr   = {ADDR_WIDTH{1'b0}};
        l2_cache_read   = 1'b0;
        l2_cache_write  = 1'b0;
        mem_ready       = 1'b0;
        mem_hit         = 1'b0;
        mem_data_in     = '{default: 0};
        l2_cache_data_in= '{default: 0};

        // Apply reset
        #20;
        rst_n = 1'b1;

        // 1) Read Miss: request block at address 0x0000_0100
        @(posedge clk);
        l2_cache_addr  = 32'h0000_0100;
        l2_cache_read  = 1'b1;

        // Wait until mem_read asserted by DUT
        wait (mem_read == 1'b1);
        // Provide memory data and signal hit
        mem_data_in = '{default: 32'hDEADBEEF};
        mem_hit     = 1'b1;
        mem_ready   = 1'b1;

        // Wait for allocate to complete
        @(posedge clk);
        mem_ready   = 1'b0;
        mem_hit     = 1'b0;

        // Check ready and data_out
        wait (l2_cache_ready == 1'b1);
        $display("[TB] Read Miss completed, data_out[0]=%h, hit=%b", l2_cache_data_out[0], l2_hit);

        // 2) Read Hit: same address again
        @(posedge clk);
        l2_cache_read  = 1'b0;
        l2_cache_addr  = 32'h0000_0100;
        l2_cache_read  = 1'b1;

        // Wait for cache hit
        wait (l2_cache_ready == 1'b1);
        $display("[TB] Read Hit completed, data_out[0]=%h, hit=%b", l2_cache_data_out[0], l2_hit);

        // Finish simulation
        #20;
        $finish;
    end
endmodule
