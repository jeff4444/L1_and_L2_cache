module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
) (
    input wire clk,
    input wire rst_n,
    
    // L2 Cache interface
    input wire [ADDR_WIDTH-1:0] l2_cache_addr,
    input wire [DATA_WIDTH-1:0] l2_cache_data_in,
    output reg [DATA_WIDTH-1:0] l2_cache_data_out,
    input wire l2_cache_read,
    input wire l2_cache_write,
    output reg l2_cache_ready,
);
    
endmodule