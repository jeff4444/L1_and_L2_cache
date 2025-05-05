`timescale 1ns/1ns

module tb_top;
  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------
  parameter ADDR_WIDTH  = 11;
  parameter DATA_WIDTH  = 8;

  // L1 cache parameters
  parameter L1_CACHE_SIZE = 256;
  parameter L1_BLOCK_SIZE = 16;
  parameter L1_NUM_WAYS   = 2;
  localparam L1_NUM_BLOCKS = L1_CACHE_SIZE / L1_BLOCK_SIZE;
  localparam L1_NUM_SETS   = L1_NUM_BLOCKS / L1_NUM_WAYS;

  // L2 cache parameters
  parameter L2_CACHE_SIZE = 512;
  parameter L2_BLOCK_SIZE = 32;
  parameter L2_NUM_WAYS   = 2;
  localparam L2_NUM_BLOCKS = L2_CACHE_SIZE / L2_BLOCK_SIZE;
  localparam L2_NUM_SETS   = L2_NUM_BLOCKS / L2_NUM_WAYS;

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

  // Wires between L1 and L2
  wire [ADDR_WIDTH-1:0]     l1_l2_addr;
  wire                      l1_l2_read;
  wire                      l1_l2_write;
  wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_l2_data_in;
  wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_l2_data_out;
  wire                      l1_l2_ready;
  wire                      l1_l2_hit;

  // Wires between L2 and memory
  wire [ADDR_WIDTH-1:0]     mem_addr;
  wire                      mem_read;
  wire                      mem_write;
  wire [L2_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_in;
  wire [L2_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out;
  wire                      mem_ready;
  wire                      mem_hit;

  //--------------------------------------------------------------------------
  // Instantiate L1 cache
  //--------------------------------------------------------------------------
  L1_cache #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .CACHE_SIZE (L1_CACHE_SIZE),
    .BLOCK_SIZE (L1_BLOCK_SIZE),
    .NUM_WAYS   (L1_NUM_WAYS)
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
    .l2_cache_addr    (l1_l2_addr),
    .l2_cache_data_out(l1_l2_data_out),
    .l2_cache_data_in (l1_l2_data_in),
    .l2_cache_read    (l1_l2_read),
    .l2_cache_write   (l1_l2_write),
    .l2_cache_ready   (l1_l2_ready),
    .l2_cache_hit     (l1_l2_hit)
  );

  // Instantiate L2 cache between L1 and memory
  L2_cache #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .CACHE_SIZE (L2_CACHE_SIZE),
    .BLOCK_SIZE (L2_BLOCK_SIZE),
    .NUM_WAYS   (L2_NUM_WAYS),
    .L1_BLOCK_SIZE (L1_BLOCK_SIZE)
  ) l2_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    // Interface to L1
    .l2_cache_addr     (l1_l2_addr),
    .l2_cache_read     (l1_l2_read),
    .l2_cache_write    (l1_l2_write),
    .l2_cache_data_in  (l1_l2_data_out),
    .l2_cache_data_out (l1_l2_data_in),
    .l2_cache_ready    (l1_l2_ready),
    .l2_hit      (l1_l2_hit),
    // Interface to memory
    .mem_addr    (mem_addr),
    .mem_read    (mem_read),
    .mem_write   (mem_write),
    .mem_data_in (mem_data_out),
    .mem_data_out(mem_data_in),
    .mem_ready   (mem_ready),
    .mem_hit     (mem_hit)
  );

  // Instantiate memory model
  memory #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .BLOCK_SIZE (L2_BLOCK_SIZE)
  ) mem_inst (
    .clk    (clk),
    .rst_n  (rst_n),
    .read   (mem_read),
    .write  (mem_write),
    .addr   (mem_addr),
    .data_in(mem_data_in),
    .data_out(mem_data_out),
    .hit    (mem_hit),
    .ready  (mem_ready)
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
    $display("%0t [TEST] CPU read @0x%h", $time, addr);
    cpu_addr = addr;
    cpu_read = 1;
    @(posedge clk);
  end
  endtask

  //------------------------------------------------------------------------------
  // Pretty‑print entire cache: valid, tag, data
  //------------------------------------------------------------------------------
  task pretty_print_l1_cache;
      integer set_idx, way_idx;
      begin
          $display("\n==== L1 CACHE CONTENTS ====");
          for (set_idx = 0; set_idx < L1_NUM_SETS; set_idx = set_idx + 1) begin
              $display("Set %0d ------------------------", set_idx);
              for (way_idx = 0; way_idx < L1_NUM_WAYS; way_idx = way_idx + 1) begin
                  // valid bit
                  $write("  Way %0d | valid=%b | ", way_idx, dut.valid[set_idx][way_idx]);
                  // tag (auto‑width hex)
                  $write("tag=0x%0h | ", dut.tags[set_idx][way_idx]);
                  // data block (flattened packed array of size BLOCK_SIZE*DATA_WIDTH)
                  $display("data=0x%0h", dut.data[set_idx][way_idx]);
              end
          end
          $display("=========================\n");
      end
  endtask

  //------------------------------------------------------------------------------
  // Pretty‑print entire cache: valid, tag, data
  //------------------------------------------------------------------------------
  task pretty_print_l2_cache;
      integer set_idx, way_idx;
      begin
          $display("\n==== L2 CACHE CONTENTS ====");
          for (set_idx = 0; set_idx < L2_NUM_SETS; set_idx = set_idx + 1) begin
              $display("Set %0d ------------------------", set_idx);
              for (way_idx = 0; way_idx < L2_NUM_WAYS; way_idx = way_idx + 1) begin
                  // valid bit
                  $write("  Way %0d | valid=%b | ", way_idx, l2_inst.valid[set_idx][way_idx]);
                  // tag (auto‑width hex)
                  $write("tag=0x%0h | ", l2_inst.tags[set_idx][way_idx]);
                  // data block (flattened packed array of size BLOCK_SIZE*DATA_WIDTH)
                  $display("data=0x%0h", l2_inst.data[set_idx][way_idx]);
              end
          end
          $display("=========================\n");
      end
  endtask

  task pretty_print;
      begin
          pretty_print_l1_cache();
          pretty_print_l2_cache();
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

    // randomize input addresses
    for (integer i = 0; i < 10000; i = i + 1) begin
      cpu_addr = $urandom;
      cpu_request(cpu_addr);
      wait (cpu_ready == 1);
      `ifdef PRETTY_PRINT
        pretty_print();
        `endif
    end

    cpu_read = 0;
    // All done
    #50;
    $finish;
  end
endmodule