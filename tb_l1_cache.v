`timescale 1ns/1ns

module tb_l1_cache;
  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------
  parameter ADDR_WIDTH  = 11;
  parameter DATA_WIDTH  = 8;
  parameter CACHE_SIZE  = 256;
  parameter BLOCK_SIZE  = 16;
  parameter NUM_WAYS    = 4;

  //--------------------------------------------------------------------------
  // Clock, reset, and DUT I/O
  //--------------------------------------------------------------------------
  reg                         clk;
  reg                         rst_n;

  // CPU side
  reg  [ADDR_WIDTH-1:0]       cpu_addr;
  reg  [DATA_WIDTH-1:0]       cpu_data_in;
  reg                         cpu_read;
  reg                         cpu_write;
  wire [DATA_WIDTH-1:0]       cpu_data_out;
  wire                        cpu_ready;

  // L2 data as packed array to match DUT ports
  integer w;
  wire  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_in;
  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_out;
  wire                        l2_cache_ready;
  wire                        l2_cache_hit;

  // L2 side (stimulus)
  wire [ADDR_WIDTH-1:0]       l2_cache_addr;
  wire                        l2_cache_read;
  wire                        l2_cache_write;

  //--------------------------------------------------------------------------
  // Instantiate L1 cache
  //--------------------------------------------------------------------------
  L1_cache #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .CACHE_SIZE (CACHE_SIZE),
    .BLOCK_SIZE (BLOCK_SIZE),
    .NUM_WAYS   (NUM_WAYS)
  ) dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .cpu_addr         (cpu_addr),
    .cpu_data_in      (cpu_data_in),
    .cpu_read         (cpu_read),
    .cpu_write        (cpu_write),
    .cpu_data_out     (cpu_data_out),
    .cpu_ready        (cpu_ready),
    .l1_hit           (),
    .l2_cache_addr    (l2_cache_addr),
    .l2_cache_data_out(l2_cache_data_out),
    .l2_cache_data_in (l2_cache_data_in),
    .l2_cache_read    (l2_cache_read),
    .l2_cache_write   (l2_cache_write),
    .l2_cache_ready   (l2_cache_ready),
    .l2_cache_hit     (l2_cache_hit)
  );

  // Instantiate memory model
  memory #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .BLOCK_SIZE (BLOCK_SIZE)
  ) mem_inst (
    .clk    (clk),
    .rst_n  (rst_n),
    .read   (l2_cache_read),
    .write  (l2_cache_write),
    .addr   (l2_cache_addr),
    .data_in(l2_cache_data_out),
    .data_out(l2_cache_data_in),
    .hit    (l2_cache_hit),
    .ready  (l2_cache_ready)
  );

  //--------------------------------------------------------------------------
  // Clock generator: 100 MHz
  //--------------------------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk;

  //--------------------------------------------------------------------------
  // Reset pulse
  //--------------------------------------------------------------------------
  initial begin
    rst_n = 0;
    #20;
    rst_n = 1;
  end

  //--------------------------------------------------------------------------
  // Simple task to issue a read from the CPU
  //--------------------------------------------------------------------------
  task cpu_request(input [ADDR_WIDTH-1:0] addr);
  begin
    cpu_addr = addr;
    cpu_read = 1;
    @(posedge clk);
    cpu_read = 0;
  end
  endtask

  //--------------------------------------------------------------------------
  // Test sequence
  //--------------------------------------------------------------------------
  initial begin
    // Initialize stimulus
    cpu_addr         = 0;
    cpu_read         = 0;
    cpu_write        = 0;
    cpu_data_in      = 0;

    // Wait until reset is released
    @(posedge rst_n);
    $display("%0t [TEST] Reset released", $time);


    // -----------------------------------------------------------------
    // Test for index 0
    // -----------------------------------------------------------------


    // 1) COMPULSORY MISS @ addr = 0
    cpu_request(11'h001);
    // Wait for the cache to assert a request to L2
    wait (l2_cache_read == 1);
    // Wait for memory to respond
    wait (l2_cache_ready == 1);
    // Wait for the cache to finish
    wait (cpu_ready == 1);
    $display("%0t [TEST] Miss @0 -> data_out = %h (expected 001)", $time, cpu_data_out);

    // 2) HIT on the nearby address
    cpu_request(11'h000);
    @(posedge clk);
    @(posedge clk);
    if (cpu_ready && cpu_data_out == 8'h00)
      $display("%0t [TEST] Hit after allocate @0 PASS", $time);
    else
      $display("%0t [TEST] Hit after allocate @0 FAIL: ready=%b, data_out=%h",
                $time, cpu_ready, cpu_data_out);
    
    // 3) HIT on the nearby address
    cpu_request(11'h002);
    @(posedge clk);
    @(posedge clk);
    if (cpu_ready && cpu_data_out == 8'h02)
      $display("%0t [TEST] Hit after allocate @0 PASS", $time);
    else
      $display("%0t [TEST] Hit after allocate @0 FAIL: ready=%b, data_out=%h",
                $time, cpu_ready, cpu_data_out);
    // 4) HIT on the nearby address
    cpu_request(11'h005);
    @(posedge clk);
    @(posedge clk);
    if (cpu_ready && cpu_data_out == 8'h05)
      $display("%0t [TEST] Hit after allocate @0 PASS", $time);
    else
      $display("%0t [TEST] Hit after allocate @0 FAIL: ready=%b, data_out=%h",
                $time, cpu_ready, cpu_data_out);


    // -----------------------------------------------------------------
    // Test for index 1
    // -----------------------------------------------------------------


    // 1) COMPULSORY MISS @ addr = 0x010 (index=1 if BLOCK_SIZE=16)
    cpu_request(11'h010);
    wait (l2_cache_read == 1);
    // Wait for memory to respond
    wait (l2_cache_ready == 1);
    wait (cpu_ready == 1);
    $display("%0t [TEST] Miss @0x010 -> data_out = %h (expected 010)", $time, cpu_data_out);

    // 2) HIT 
    cpu_request(11'h014);
    @(posedge clk);
    @(posedge clk);
    if (cpu_ready && cpu_data_out == 8'h14)
      $display("%0t [TEST] Hit after allocate @0x010 PASS", $time);
    else
      $display("%0t [TEST] Hit after allocate @0x010 FAIL: ready=%b, data_out=%h",
                $time, cpu_ready, cpu_data_out);
              
    // 3) HIT
    cpu_request(11'h01A);
    @(posedge clk);
    @(posedge clk);
    if (cpu_ready && cpu_data_out == 8'h1A)
      $display("%0t [TEST] Hit after allocate @0x010 PASS", $time);
    else
      $display("%0t [TEST] Hit after allocate @0x010 FAIL: ready=%b, data_out=%h",
                $time, cpu_ready, cpu_data_out);


    // ----------------------------------------------------------------
    // Test for eviction of index 0
    // ----------------------------------------------------------------
    cpu_request(11'h101);
    wait (l2_cache_read == 1);
    // Wait for memory to respond
    wait (l2_cache_ready == 1);
    wait (cpu_ready == 1);
    $display("%0t [TEST] Miss @0x100 -> data_out = %h (expected 01)", $time, cpu_data_out);

    // All done
    #50;
    $finish;
  end

  //--------------------------------------------------------------------------
  // dump signals
  //--------------------------------------------------------------------------
  initial begin
    $dumpfile("tb_l1_cache.vcd");
    $dumpvars(0, tb_l1_cache);
  end

endmodule