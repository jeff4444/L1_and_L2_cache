`timescale 1ns/1ps

module tb_L2_cache;

  // Reduced parameters for quick sim
  parameter DATA_WIDTH  = 8;
  parameter ADDR_WIDTH  = 4;
  parameter CACHE_SIZE  = 32;
  parameter BLOCK_SIZE  = 8;
  parameter NUM_WAYS    = 2;

  // Clock & reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;  // 100 MHz

  // DUT I/O
  reg  [ADDR_WIDTH-1:0]          l1_cache_addr;
  reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_cache_data_in;
  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_block_data_out;
  wire                            l1_block_valid;
  reg                             l1_cache_read, l1_cache_write;
  wire                            l1_cache_ready, l1_cache_hit;

  reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_block;
  reg                             mem_ready;
  wire [ADDR_WIDTH-1:0]           mem_addr;
  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out;
  wire                            mem_read, mem_write;

  // Instantiate DUT
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

  // Test sequence
  initial begin
    // 1) Reset
    #1  rst_n = 0;
    #20 rst_n = 1;

    // Helper to wait until ready
    task wait_ready;
      begin
        @(posedge clk);
        while (!l1_cache_ready) @(posedge clk);
      end
    endtask

    // 2) Read miss @ addr=4
    l1_cache_addr    = 4;
    l1_cache_read    = 1;
    l1_cache_write   = 0;
    mem_ready        = 0;
    mem_data_block   = '{default:8'hAA};  // fill block with 0xAA
    @(posedge clk);
    l1_cache_read = 0;

    // DUT should assert mem_read
    #1;
    if (!mem_read) $display("ERROR: expected mem_read on miss");
    // after 3 cycles memory responds
    repeat (3) @(posedge clk);
    mem_ready = 1; // present data
    @(posedge clk);
    mem_ready = 0;

    // Should get a valid block back
    wait_ready();
    if (l1_block_data_out !== '{default:8'hAA})
      $display("FAIL: read-miss data mismatch");

    // 3) Read hit @ same addr=4
    l1_cache_addr  = 4;
    l1_cache_read  = 1;
    @(posedge clk);
    l1_cache_read = 0;
    wait_ready();
    if (!l1_cache_hit) $display("FAIL: expected hit on second read");
    if (l1_block_data_out !== '{default:8'hAA})
      $display("FAIL: read-hit data mismatch");

    // 4) Write miss @ addr=8
    l1_cache_addr   = 8;
    l1_cache_data_in= '{default:8'h55};
    l1_cache_write  = 1;
    @(posedge clk);
    l1_cache_write = 0;
    wait_ready();
    if (!mem_write) $display("ERROR: expected mem_write on write-miss");
    if (mem_data_out !== '{default:8'h55})
      $display("FAIL: write-miss mem_data_out wrong");
    if (!l1_cache_hit)
      $display("PASS: write-miss treated as allocate (hit flag OK)");

    // 5) Write hit @ addr=8
    l1_cache_addr    = 8;
    l1_cache_data_in = '{default:8'h77};
    l1_cache_write   = 1;
    @(posedge clk);
    l1_cache_write = 0;
    wait_ready();
    if (!l1_cache_hit) $display("FAIL: expected hit on write-hit");
    if (l1_block_data_out !== '{default:8'h77})
      $display("FAIL: write-hit data mismatch");

    $display("Testbench completed");
    $finish;
  end

  // Optional: monitor some signals
  initial begin
    $monitor("t=%0t | state=%b | rd=%b wr=%b hit=%b ready=%b | addr=%0d | mem_rd=%b mem_wr=%b",
             $time, dut.curr_state, l1_cache_read, l1_cache_write,
             l1_cache_hit, l1_cache_ready, l1_cache_addr,
             mem_read, mem_write);
  end

endmodule
