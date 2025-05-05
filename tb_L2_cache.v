`timescale 1ns/1ps

module tb_L2_cache;

  //----------------------------------------------------------------------------
  // 1) Local parameters (match the DUT)
  //----------------------------------------------------------------------------
  localparam DATA_WIDTH  = 32;
  localparam ADDR_WIDTH  = 11;
  localparam CACHE_SIZE  = 512;
  localparam BLOCK_SIZE  = 32;
  localparam NUM_WAYS    = 4;

  //----------------------------------------------------------------------------
  // 2) Clock & reset
  //----------------------------------------------------------------------------
  logic clk, rst_n;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;        // 100 MHz
  end
  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  //----------------------------------------------------------------------------
  // 3) DUT signals (note unpacked arrays)
  //----------------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0]                l1_cache_addr;
  logic [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_cache_data_in;
  logic [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_block_data_out;
  logic                                 l1_block_valid;
  logic                                 l1_cache_read, l1_cache_write;
  logic                                 l1_cache_ready, l1_cache_hit;

  logic [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_block;
  logic                                 mem_ready;
  logic [ADDR_WIDTH-1:0]                mem_addr;
  logic [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out;
  logic                                 mem_read, mem_write;

  //----------------------------------------------------------------------------
  // 4) Instantiate DUT
  //----------------------------------------------------------------------------
  L2_cache #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .CACHE_SIZE  (CACHE_SIZE),
    .BLOCK_SIZE  (BLOCK_SIZE),
    .NUM_WAYS    (NUM_WAYS)
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

  //----------------------------------------------------------------------------
  // 5) Helper: wait until l1_cache_ready
  //----------------------------------------------------------------------------
  task automatic wait_ready();
    @(posedge clk);
    while (!l1_cache_ready)
      @(posedge clk);
  endtask

  //----------------------------------------------------------------------------
  // 6) Test sequence
  //----------------------------------------------------------------------------
  initial begin
    // Give reset time to finish
    @(posedge rst_n);

    // --- 1) Read-miss at address 0x10 ---
    l1_cache_addr    = 11'h10;
    l1_cache_read    = 1;
    l1_cache_write   = 0;
    mem_ready        = 0;
    l1_cache_data_in = '{default: '0};
    @(posedge clk);
    l1_cache_read = 0;

    // We should see mem_read asserted
    #1 if (!mem_read) $error("Expected mem_read on read-miss");

    // After a few cycles, memory responds
    repeat (4) @(posedge clk);
    mem_data_block = '{default: 32'hDEADBEEF};
    mem_ready      = 1;
    @(posedge clk);
    mem_ready      = 0;

    // Wait for cache to signal ready and data back
    wait_ready();
    if (l1_block_data_out !== '{default: 32'hDEADBEEF})
      $error("Read-miss data mismatch: got %p", l1_block_data_out);

    // --- 2) Read-hit at same address ---
    l1_cache_addr  = 11'h10;
    l1_cache_read  = 1;
    @(posedge clk);
    l1_cache_read  = 0;
    wait_ready();
    if (!l1_cache_hit) 
      $error("Expected hit on read-hit");
    if (l1_block_data_out !== '{default: 32'hDEADBEEF})
      $error("Read-hit data mismatch: got %p", l1_block_data_out);

    // --- 3) Write-miss at address 0x20 ---
    l1_cache_addr    = 11'h20;
    l1_cache_data_in = '{default: 32'h12345678};
    l1_cache_write   = 1;
    @(posedge clk);
    l1_cache_write   = 0;
    wait_ready();
    if (!mem_write) 
      $error("Expected mem_write on write-miss");
    if (mem_data_out !== '{default: 32'h12345678})
      $error("Write-miss data mismatch: got %p", mem_data_out);

    // --- 4) Write-hit at same address ---
    l1_cache_addr    = 11'h20;
    l1_cache_data_in = '{default: 32'hCAFEBABE};
    l1_cache_write   = 1;
    @(posedge clk);
    l1_cache_write   = 0;
    wait_ready();
    if (!l1_cache_hit) 
      $error("Expected hit on write-hit");
    if (l1_block_data_out !== '{default: 32'hCAFEBABE})
      $error("Write-hit data mismatch: got %p", l1_block_data_out);

    $display("=== All tests passed! ===");
    $finish;
  end

endmodule
