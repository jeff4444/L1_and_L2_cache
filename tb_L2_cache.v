`timescale 1ns/1ps

module tb_L2_cache;
  // Override parameters to project spec
  localparam DATA_WIDTH   = 32;
  localparam ADDR_WIDTH   = 11;       // 2048 bytes addressable
  localparam CACHE_SIZE   = 512;      // L2 = 512 B
  localparam BLOCK_SIZE   = 32;       // 32 B line
  localparam NUM_WAYS     = 4;
  localparam WORDS        = (1<<ADDR_WIDTH)/(DATA_WIDTH/8);  // 512 words

  // Clock & reset
  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;  // 100 MHz

  // L1 <-> L2 interface
  reg  [ADDR_WIDTH-1:0]      l1_cache_addr;
  reg  [DATA_WIDTH-1:0]      l1_cache_data_in = 0;
  wire [DATA_WIDTH-1:0]      l1_cache_data_out;
  reg                        l1_cache_read = 0;
  reg                        l1_cache_write = 0;
  wire                       l1_cache_ready;
  wire                       l1_cache_hit;

  // L2 <-> Mem interface
  wire [ADDR_WIDTH-1:0]      mem_addr;
  wire [DATA_WIDTH-1:0]      mem_data_out; // unused for read-only test
  reg  [DATA_WIDTH-1:0]      mem_data_in;
  wire                       mem_read;
  reg                        mem_ready;

  // Instantiate UUT
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
    .l1_cache_data_out(l1_cache_data_out),
    .l1_cache_read(l1_cache_read),
    .l1_cache_write(l1_cache_write),
    .l1_cache_ready(l1_cache_ready),
    .l1_cache_hit(l1_cache_hit),
    .mem_addr(mem_addr),
    .mem_data_out(mem_data_out),
    .mem_data_in(mem_data_in),
    .mem_read(mem_read),
    .mem_ready(mem_ready)
  );

  // Model of main memory: 512 words of 32 bits
  reg [DATA_WIDTH-1:0] memory [0:WORDS-1];
  integer i;
  initial begin
    // Initialize memory with a known pattern
    for (i = 0; i < WORDS; i = i + 1)
      memory[i] = i*4 + 32'h1000;  // just an easy-to-spot pattern
  end

  // Handshake: whenever L2 asserts mem_read, immediately return mem_ready=1
  // and present the word at mem_addr>>2
  always @(posedge clk) begin
    if (mem_read) begin
      mem_data_in <= memory[mem_addr >> 2];
      mem_ready   <= 1;
    end else begin
      mem_ready   <= 0;
    end
  end

  // Test sequence
  initial begin
    // 1) Reset
    rst_n = 0;
    #20;
    rst_n = 1;
    #20;

    // --- Test 1: Cold miss ---
    l1_cache_addr  = 11'd20;     // byte address 20 => word index = 20>>2 = 5
    l1_cache_read  = 1;
    #10;
    l1_cache_read  = 0;

    // Wait for block fill + return
    wait(l1_cache_ready);
    #10;
    if (l1_cache_data_out !== memory[l1_cache_addr >> 2]) begin
      $display("ERROR: cold fetch returned %h, expected %h",
               l1_cache_data_out, memory[l1_cache_addr>>2]);
    end else begin
      $display("PASS: cold fetch got %h", l1_cache_data_out);
    end

    // --- Test 2: Hit on same address ---
    @(posedge clk);
    l1_cache_addr = 11'd20;
    l1_cache_read = 1;
    #10;
    l1_cache_read = 0;

    // Should hit in L2 immediately (no mem_read)
    if (mem_read) begin
      $display("ERROR: expected hit, but mem_read was asserted");
    end
    @(posedge clk);
    if (!l1_cache_ready || !l1_cache_hit) begin
      $display("ERROR: expected immediate hit, got ready=%b hit=%b",
               l1_cache_ready, l1_cache_hit);
    end else begin
      $display("PASS: hit returned %h", l1_cache_data_out);
    end

    $display("TEST COMPLETE");
    $finish;
  end
endmodule