module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter BLOCK_SIZE = 16,
) (
    input wire clk,
    input wire rst_n,
    
    // L2 Cache interface
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_in,
    output reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_out,
    input wire read,
    input wire write,
    output reg ready
);
    reg [DATA_WIDTH-1:0] memory [0:(1 << ADDR_WIDTH) - 1]; // Memory array

    localparam BLOCK_BITS = $clog2(BLOCK_SIZE);

    reg [ADDR_WIDTH - 1:0] block_start = {addr[ADDR_WIDTH - 1:BLOCK_BITS], BLOCK_BITS{1'b0}};

    // Mem read operation
    always @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else if (read) begin
            for (integer i = 0; i < BLOCK_SIZE; i = i + 1) begin
                data_out[i] <= memory[block_start + i];
            end
            ready <= 1'b1;
        end else begin
            ready <= 1'b0;
        end
    end
endmodule