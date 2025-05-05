`timescale 1ns/1ps

module tb_L2_cache;
  // small parameters for fast sim
  parameter DATA_WIDTH  = 8;
  parameter ADDR_WIDTH  = 4;
  parameter CACHE_SIZE  = 32;
  parameter BLOCK_SIZE  = 8;
  parameter NUM_WAYS    = 2;

  // clock & reset
  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  initial begin
    #1  rst_n = 0;
    #20 rst_n = 1;
  end

  // flat vectors to match the DUT
  reg  [ADDR_WIDTH-1:0]             l1_cache_addr;
  reg  [(BLOCK_SIZE*DATA_WIDTH)-1:0] l1_cache_data_in_flat;
  wire [(BLOCK_SIZE*DATA_WIDTH)-1:0] l1_block_data_out_flat;
  reg                              l1_cache_read, l1_cache_write;
  wire                             l1_cache_ready, l1_cache_hit;
  reg  [(BLOCK_SIZE*DATA_WIDTH)-1:0] mem_data_block_flat;
  reg                              mem_ready;
  wire [ADDR_WIDTH-1:0]            mem_addr;
  wire [(BLOCK_SIZE*DATA_WIDTH)-1:0] mem_data_out_flat;
  wire                             mem_read, mem_write;

  // instantiate DUT
  L2_cache #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .CACHE_SIZE  (CACHE_SIZE),
    .BLOCK_SIZE  (BLOCK_SIZE),
    .NUM_WAYS    (NUM_WAYS)
  ) dut (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .l1_cache_addr          (l1_cache_addr),
    .l1_cache_data_in_flat  (l1_cache_data_in_flat),
    .l1_block_data_out_flat (l1_block_data_out_flat),
    .l1_cache_read          (l1_cache_read),
    .l1_cache_write         (l1_cache_write),
    .l1_cache_ready         (l1_cache_ready),
    .l1_cache_hit           (l1_cache_hit),
    .mem_data_block_flat    (mem_data_block_flat),
    .mem_ready              (mem_ready),
    .mem_addr               (mem_addr),
    .mem_data_out_flat      (mem_data_out_flat),
    .mem_read               (mem_read),
    .mem_write              (mem_write)
  );

  // helper to wait for ready
  task wait_ready; 
    begin
      @(posedge clk);
      while (!l1_cache_ready) @(posedge clk);
    end
  endtask

  initial begin
    // 1) Read miss @ addr=4
    l1_cache_addr         = 4;
    l1_cache_data_in_flat = { BLOCK_SIZE { {DATA_WIDTH{1'b0}} } };
    l1_cache_read         = 1;
    l1_cache_write        = 0;
    mem_ready             = 0;
    @(posedge clk);
    l1_cache_read = 0;

    if (!mem_read) $display("ERROR: expected mem_read on miss");
    repeat (3) @(posedge clk);
    mem_data_block_flat = { BLOCK_SIZE { 8'hAA } };
    mem_ready           = 1;
    @(posedge clk);
    mem_ready           = 0;

    wait_ready();
    if (l1_block_data_out_flat !== { BLOCK_SIZE { 8'hAA } })
      $display("FAIL: read-miss data mismatch");

    // 2) Read hit @ same addr
    l1_cache_addr = 4;
    l1_cache_read = 1;
    @(posedge clk);
    l1_cache_read = 0;
    wait_ready();
    if (!l1_cache_hit) $display("FAIL: expected hit on read-hit");
    if (l1_block_data_out_flat !== { BLOCK_SIZE { 8'hAA } })
      $display("FAIL: read-hit data mismatch");

    // 3) Write miss @ addr=8
    l1_cache_addr         = 8;
    l1_cache_data_in_flat = { BLOCK_SIZE { 8'h55 } };
    l1_cache_write        = 1;
    @(posedge clk);
    l1_cache_write = 0;
    wait_ready();
    if (!mem_write) $display("ERROR: expected mem_write on write-miss");
    if (mem_data_out_flat !== { BLOCK_SIZE{8'h55} })
      $display("FAIL: write-miss data mismatch");

    // 4) Write hit @ addr=8
    l1_cache_addr         = 8;
    l1_cache_data_in_flat = { BLOCK_SIZE { 8'h77 } };
    l1_cache_write        = 1;
    @(posedge clk);
    l1_cache_write = 0;
    wait_ready();
    if (!l1_cache_hit) $display("FAIL: expected hit on write-hit");
    if (l1_block_data_out_flat !== { BLOCK_SIZE{8'h77} })
      $display("FAIL: write-hit data mismatch");

    $display(">>> All tests done.");
    $finish;
  end

endmodule
