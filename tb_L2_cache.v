// tb_L2_cache.v — plain Verilog-2005
module tb_L2_cache;
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 4;
  parameter BLOCK_SIZE = 4;
  localparam FLAT_WIDTH = DATA_WIDTH*BLOCK_SIZE;

  reg                     clk = 0;
  reg                     rst_n;
  reg  [ADDR_WIDTH-1:0]   l1_addr;
  // flat instead of reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]
  reg  [FLAT_WIDTH-1:0]   l1_data_in_flat;
  wire [FLAT_WIDTH-1:0]   l1_data_out_flat;
  wire                    l1_valid, l1_ready, l1_hit;
  reg                     l1_read, l1_write;

  // memory interface flattened
  reg  [FLAT_WIDTH-1:0]   mem_data_block_flat;
  reg                     mem_ready;
  wire [ADDR_WIDTH-1:0]   mem_addr;
  wire [FLAT_WIDTH-1:0]   mem_data_out_flat;
  wire                    mem_read, mem_write;

  // DUT instantiation with flat ports
  L2_cache #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .CACHE_SIZE(16),        // small for TB
    .BLOCK_SIZE(BLOCK_SIZE),
    .NUM_WAYS(2)
  ) dut (
    .clk                  (clk),
    .rst_n                (rst_n),
    .l1_cache_addr        (l1_addr),
    .l1_cache_data_in     (l1_data_in_flat),
    .l1_block_data_out    (l1_data_out_flat),
    .l1_block_valid       (l1_valid),
    .l1_cache_read        (l1_read),
    .l1_cache_write       (l1_write),
    .l1_cache_ready       (l1_ready),
    .l1_cache_hit         (l1_hit),
    .mem_data_block       (mem_data_block_flat),
    .mem_ready            (mem_ready),
    .mem_addr             (mem_addr),
    .mem_data_out         (mem_data_out_flat),
    .mem_read             (mem_read),
    .mem_write            (mem_write)
  );

  // clock
  always #5 clk = ~clk;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb_L2_cache);

    // reset
    rst_n = 0; l1_read = 0; l1_write = 0; mem_ready = 0;
    #12 rst_n = 1;

    // --- read miss ---
    @(posedge clk);
      l1_addr           = 4'hA;
      l1_read           = 1;
      // SV literal replaced by std replication
      mem_data_block_flat = {BLOCK_SIZE{8'hFF}};
    @(posedge clk);
      mem_ready         = 1;
    @(posedge clk);
      $display("Read miss: valid=%b ready=%b hit=%b data[0]=%h",
               l1_valid, l1_ready, l1_hit, l1_data_out_flat[DATA_WIDTH-1:0]);
      mem_ready         = 0;
      l1_read           = 0;

    // --- read hit ---
    @(posedge clk);
      l1_read = 1;
    @(posedge clk);
      $display("Read  hit: valid=%b ready=%b hit=%b data[0]=%h",
               l1_valid, l1_ready, l1_hit, l1_data_out_flat[DATA_WIDTH-1:0]);
      l1_read = 0;

    // --- write miss ---
    @(posedge clk);
      l1_addr         = 4'hB;
      l1_data_in_flat = {BLOCK_SIZE{8'hBB}};
      l1_write        = 1;
    @(posedge clk);
      $display("Write miss: valid=%b ready=%b hit=%b mem_write=%b",
               l1_valid, l1_ready, l1_hit, mem_write);
      l1_write        = 0;

    // --- write hit ---
    @(posedge clk);
      l1_addr         = 4'hB;
      l1_data_in_flat = {BLOCK_SIZE{8'hCC}};
      l1_write        = 1;
    @(posedge clk);
      $display("Write hit:  valid=%b ready=%b hit=%b mem_write=%b",
               l1_valid, l1_ready, l1_hit, mem_write);
      l1_write = 0;

    #20 $finish;
  end
endmodule
