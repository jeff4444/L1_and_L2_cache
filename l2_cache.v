module L2_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16
) (
    input wire clk,
    input wire rst_n,
    
    // L1 Cache interface
    input wire [ADDR_WIDTH-1:0] l1_cache_addr,
    input wire [DATA_WIDTH-1:0] l1_cache_data_in,
    output reg [DATA_WIDTH-1:0] l1_cache_data_out,
    input wire l1_cache_read,
    input wire l1_cache_write,
    output reg l1_cache_ready,
    
    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_data_out, // Data to be written to memory
    input wire [DATA_WIDTH-1:0] mem_data_in, // Data read from memory
    output reg mem_read,
    output reg mem_write,
    input wire mem_ready
);
    
endmodule