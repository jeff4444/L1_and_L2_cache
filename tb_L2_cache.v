`timescale 1ns/1ps

module tb_L2_cache;
  // Parameters must match the DUT
  localparam DATA_WIDTH      = 32;
  localparam ADDR_WIDTH      = 11;
  localparam CACHE_SIZE      = 512;
  localparam BLOCK_SIZE      = 32;
  localparam NUM_WAYS        = 4;
  localparam words_per_block = BLOCK_SIZE/(DATA_WIDTH/8);       // 8
  localparam block_num      = CACHE_SIZE/BLOCK_SIZE;           // 16
  localparam offset_width    = $clog2(BLOCK_SIZE);              // 5

  // Clock & reset
  reg clk = 0;
  always #5 clk = ~clk;  // 10 ns period

  reg rst_n;

  // L1⇄L2 interface
  reg  [ADDR_WIDTH-1:0] l1_cache_addr;
  reg  [DATA_WIDTH-1:0] l1_cache_data_in;
  wire [DATA_WIDTH*words_per_block-1:0] l1_block_data_out;
  wire                          l1_block_valid;
  reg                           l1_cache_read;
  reg                           l1_cache_write;
  wire                          l1_cache_ready;
  wire                          l1_cache_hit;

  // L2⇄Mem interface
  wire [ADDR_WIDTH-1:0]         mem_addr;
  wire                          mem_read;
  reg                           mem_ready;
  reg  [DATA_WIDTH*words_per_block-1:0] mem_data_block;
  wire                          mem_write;
  wire [DATA_WIDTH-1:0]         mem_data_out;

  // Instantiate the DUT
  L2_cache #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .CACHE_SIZE(CACHE_SIZE),
    .BLOCK_SIZE(BLOCK_SIZE),
    .NUM_WAYS(NUM_WAYS)
  ) uut (
    .clk(clk),
    .rst_n(rst_n),
    .l1_cache_addr(l1_cache_addr),
    .l1_cache_data_in(l1_cache_data_in),
    .l1_block_data_out(l1_block_data_out),
    .l1_block_valid(l1_block_valid),
    .l1_cache_read(l1_cache_read),
    .l1_cache_write(l1_cache_write),
    .l1_cache_ready(l1_cache_ready),
    .l1_cache_hit(l1_cache_hit),
    .mem_addr(mem_addr),
    .mem_read(mem_read),
    .mem_ready(mem_ready),
    .mem_data_block(mem_data_block),
    .mem_write(mem_write),
    .mem_data_out(mem_data_out)
  );

  // Model of main memory blocks
  reg [DATA_WIDTH*words_per_block-1:0] mem_model [0:block_num-1];
  integer blk, w;
  initial begin
    // Fill each block with a distinctive pattern
    for (blk = 0; blk < block_num; blk = blk + 1) begin
      for (w = 0; w < words_per_block; w = w + 1) begin
        mem_model[blk][w*DATA_WIDTH +: DATA_WIDTH] = (blk << 8) | w;
      end
    end
  end

  // Drive mem_data_block & mem_ready when the DUT asserts mem_read
  always @(posedge clk) begin
    if (mem_read) begin
      // block index = mem_addr >> offset_width
      mem_data_block <= mem_model[mem_addr >> offset_width];
      mem_ready      <= 1;
    end else begin
      mem_ready      <= 0;
    end
  end

  // Test sequence
  initial begin
    // 1) Reset
    rst_n           = 0;
    l1_cache_read   = 0;
    l1_cache_write  = 0;
    mem_ready       = 0;
    #20;
    rst_n           = 1;
    #20;

    // ----- Test 1: Cold miss fetch block 3 -----
    l1_cache_addr  = 3 * BLOCK_SIZE + 12;  // some offset in block 3
    l1_cache_read  = 1;
    @(posedge clk);
    l1_cache_read  = 0;

    // Wait for block to arrive
    wait(l1_block_valid);
    #1;
    if (l1_block_data_out !== mem_model[3]) begin
      $display("FAIL: Cold miss block 3 mismatch");
    end else begin
      $display("PASS: Cold miss fetched block 3 correctly");
    end

    // ----- Test 2: Hit on block 3 -----
    @(posedge clk);
    l1_cache_read  = 1;
    l1_cache_addr  = 3 * BLOCK_SIZE + 20;  // different offset, same block
    @(posedge clk);
    l1_cache_read  = 0;

    // Hit should be immediate (no mem_read), and block valid
    #1;
    if (!l1_cache_hit || !l1_block_valid) begin
      $display("FAIL: Hit on block 3 not signaled correctly");
    end else begin
      $display("PASS: Hit on block 3 returned full block");
    end

    $display("TEST COMPLETE");
    $finish;
  end
endmodule