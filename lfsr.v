module lfsr(
    input clk,
    input rst_n,
    output [3:0] lfsr_out
);
    reg [3:0] lfsr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 4'b0001; // Initial value
        end else begin
            lfsr_reg <= {lfsr_reg[2:0], lfsr_reg[3] ^ lfsr_reg[2]};
        end
    end
    
    assign lfsr_out = lfsr_reg;

endmodule