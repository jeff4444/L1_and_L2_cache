module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter BLOCK_SIZE = 16
)(
    input wire clk,
    input wire rst_n,
    
    // L2 Cache interface
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_in,
    output reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_out,
    input wire read,
    input wire write,
    output reg hit,
    output reg ready
);
    localparam BLOCK_BITS = $clog2(BLOCK_SIZE);
    localparam MEM_SIZE = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE - 1]; // Memory array

    wire [ADDR_WIDTH - 1:0] block_start;

    assign block_start = {addr[ADDR_WIDTH - 1:BLOCK_BITS], {BLOCK_BITS{1'b0}}}; // Align address to block size
    
    // Mem read operation
    always @(posedge clk) begin
        if (!rst_n) begin
            ready <= 1'b1;
            hit <= 1'b0;
            data_out <= 0;
            for (integer i = 0; i < MEM_SIZE; i = i + 1) begin
                mem[i] <= i;
            end
        end else if (read) begin
            for (integer i = 0; i < BLOCK_SIZE; i = i + 1) begin
                data_out[i] <= mem[block_start + i];
            end
            ready <= 1'b1;
            hit <= 1'b1;
        end else begin
            ready <= 1'b0;
            hit   <= 1'b0;
        end
    end
endmodule