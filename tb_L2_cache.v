`timescale 1ns/1ps

module L2_cache_tb;
 
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 11;
  parameter CACHE_SIZE = 512;
  parameter BLOCK_SIZE = 32;
  parameter NUM_WAYS   = 4;


  reg                                     clk;
  reg                                     rst_n;
  reg  [ADDR_WIDTH-1:0]                   l1_cache_addr;
  reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   l1_cache_data_in;
  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   l1_block_data_out;
  wire                                    l1_block_valid;
  reg                                     l1_cache_read;
  reg                                     l1_cache_write;
  wire                                    l1_cache_ready;
  wire                                    l1_cache_hit;

  reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   mem_data_block;
  reg                                     mem_ready;
  wire [ADDR_WIDTH-1:0]                   mem_addr;
  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]   mem_data_out;
  wire                                    mem_read;
  wire                                    mem_write;


  L2_cache #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .CACHE_SIZE (CACHE_SIZE),
    .BLOCK_SIZE (BLOCK_SIZE),
    .NUM_WAYS   (NUM_WAYS)
  ) dut (
    .clk               (clk),
    .rst_n             (rst_n),
    .l1_cache_addr     (l1_cache_addr),
    .l1_cache_data_in  (l1_cache_data_in),
    .l1_block_data_out (l1_block_data_out),
    .l1_block_valid    (l1_block_valid),
    .l1_cache_read     (l1_cache_read),
    .l1_cache_write    (l1_cache_write),
    .l1_cache_ready    (l1_cache_ready),
    .l1_cache_hit      (l1_cache_hit),
    .mem_data_block    (mem_data_block),
    .mem_ready         (mem_ready),
    .mem_addr          (mem_addr),
    .mem_data_out      (mem_data_out),
    .mem_read          (mem_read),
    .mem_write         (mem_write)
  );

 
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

 
  initial begin
    // 1) Initialize everything
    rst_n            = 0;
    l1_cache_read    = 0;
    l1_cache_write   = 0;
    l1_cache_addr    = 0;
    mem_ready        = 0;
    // zero out arrays
    integer i;
    for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
      l1_cache_data_in[i] = {DATA_WIDTH{1'b0}};
      mem_data_block[i]   = {DATA_WIDTH{1'b0}};
    end

    #20;
    rst_n = 1;        // release reset
    #10;


    @(posedge clk);
      l1_cache_addr = 11'h00A;  // arbitrary tag/index
      l1_cache_read = 1;
    @(posedge clk);
      l1_cache_read = 0;

    // DUT should assert mem_read and present mem_addr
    #10;
    if (!mem_read) $display("ERROR: expected mem_read on miss");
    // drive memory response
    for (i = 0; i < BLOCK_SIZE; i = i + 1)
      mem_data_block[i] = 32'hDEADBEEF ^ i;
    mem_ready = 1;

    @(posedge clk);
      mem_ready = 0;
    @(posedge clk);
      if (l1_block_valid && l1_cache_ready && !l1_cache_hit)
        $display("PASS: read-miss allocate");
      else
        $display("FAIL: read-miss allocate");

 
    @(posedge clk);
      l1_cache_addr = 11'h00A;
      l1_cache_read = 1;
    @(posedge clk);
      l1_cache_read = 0;
    @(posedge clk);
      if (l1_block_valid && l1_cache_ready && l1_cache_hit &&
          l1_block_data_out[0] == (32'hDEADBEEF ^ 0))
        $display("PASS: read-hit");
      else
        $display("FAIL: read-hit");

    @(posedge clk);
      l1_cache_addr     = 11'h014;
      // prepare a block of data
      for (i = 0; i < BLOCK_SIZE; i = i + 1)
        l1_cache_data_in[i] = 32'hA5A5A5A5 ^ i;
      l1_cache_write    = 1;
    @(posedge clk);
      l1_cache_write    = 0;
    @(posedge clk);
      if (mem_write && l1_cache_ready && !l1_cache_hit)
        $display("PASS: write-miss allocate");
      else
        $display("FAIL: write-miss allocate");

    @(posedge clk);
      l1_cache_addr     = 11'h014;
      for (i = 0; i < BLOCK_SIZE; i = i + 1)
        l1_cache_data_in[i] = 32'h5A5A5A5A ^ i;
      l1_cache_write    = 1;
    @(posedge clk);
      l1_cache_write    = 0;
    @(posedge clk);
      if (mem_write && l1_cache_ready && l1_cache_hit)
        $display("PASS: write-hit");
      else
        $display("FAIL: write-hit");

    #20;
    $finish;
  end

endmodule
