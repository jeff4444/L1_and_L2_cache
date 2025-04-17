module L1_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16,
    parameter NUM_WAYS = 4,
)(
    input wire clk,
    input wire rst_n,
    
    // CPU interface
    input wire [ADDR_WIDTH-1:0] cpu_addr,
    input wire [DATA_WIDTH-1:0] cpu_data_in,
    output reg [DATA_WIDTH-1:0] cpu_data_out,
    input wire cpu_read,
    input wire cpu_write,
    output reg cpu_ready,
    
    // L2 Cache interface
    output reg [ADDR_WIDTH-1:0] l2_cache_addr,
    output reg [DATA_WIDTH-1:0] l2_cache_data_out, // Data to be written to l2 cache
    input wire [DATA_WIDTH-1:0] l2_cache_data_in, // Data read from l2 cache
    output reg l2_cache_read,
    output reg l2_cache_write,
    input wire l2_cache_ready
);
    
endmodule