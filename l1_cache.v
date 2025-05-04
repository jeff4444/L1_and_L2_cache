module L1_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16,
    parameter NUM_WAYS = 4
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
    output l1_hit,
    
    // L2 Cache interface
    output reg [ADDR_WIDTH-1:0] l2_cache_addr,
    output reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_out, // Data to be written to l2 cache
    input wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_in, // Data read from l2 cache
    output reg l2_cache_read,
    output reg l2_cache_write,
    input wire l2_cache_ready,
    input wire l2_cache_hit
);
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS = NUM_BLOCKS / NUM_WAYS;
    localparam INDEX_WIDTH = $clog2(NUM_SETS);
    localparam BYTE_OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET_WIDTH;

    // cache line structure
    reg [TAG_WIDTH-1:0] tags[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg valid[NUM_SETS-1:0][NUM_WAYS-1:0];

    // decompose address into tag, index, and byte offset
    wire [INDEX_WIDTH-1:0] index;
    wire [BYTE_OFFSET_WIDTH-1:0] byte_offset;
    wire [TAG_WIDTH-1:0] tag;

    // assign index, byte_offset, and tag
    assign index = cpu_addr[INDEX_WIDTH+BYTE_OFFSET_WIDTH-1:BYTE_OFFSET_WIDTH];
    assign byte_offset = cpu_addr[BYTE_OFFSET_WIDTH-1:0];
    assign tag = cpu_addr[ADDR_WIDTH-1:INDEX_WIDTH+BYTE_OFFSET_WIDTH];

    // cache hit detection
    reg hit;
    reg updated;
    integer i;
    reg found;
    reg [DATA_WIDTH-1:0] data_found;
    reg reading_from_l2;

    assign l1_hit = hit;

    // set found and data_found
    always @(*) begin
        found = 1'b0;
        data_found = {DATA_WIDTH{1'b0}};
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && (tags[index][i] == tag)) begin
                found = 1'b1;
                data_found = data[index][i][byte_offset];
            end
        end
    end

    // set updated signal
    always @(*) begin
        updated = 1'b0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!valid[index][i]) begin
                updated = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cpu_ready <= 1'b1;
            l2_cache_read <= 1'b0;
            l2_cache_write <= 1'b0;
            l2_cache_addr <= 0;
            l2_cache_data_out <= 0;
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                for (integer j = 0; j < NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                end
            end 
            reading_from_l2 <= 1'b0;
        end else if (reading_from_l2) begin
            if (l2_cache_ready) begin
                l2_cache_read <= 1'b0;
                l2_cache_write <= 1'b0;
                l2_cache_addr <= {ADDR_WIDTH{1'b0}};
                l2_cache_data_out <= l2_cache_data_in;
                reading_from_l2 <= 1'b0;

                // Write data to L1 cache
                for (i = 0; i < NUM_WAYS; i = i + 1) begin
                    if (!valid[index][i]) begin
                        tags[index][i] <= tag;
                        data[index][i] <= l2_cache_data_in;
                        valid[index][i] <= 1'b1;
                    end
                end

                if (!updated) begin
                    tags[index][0] <= tag;
                    data[index][0] <= l2_cache_data_in;
                    valid[index][0] <= 1'b1;
                end
                cpu_ready <= 1'b1;
                cpu_data_out <= l2_cache_data_in[byte_offset];
                hit <= 1'b1;
            end
        end else if (cpu_read) begin
            if (found) begin
                cpu_ready <= 1'b1;
                hit <= 1'b1;
                cpu_data_out <= data_found;
                l2_cache_read <= 1'b0;
                l2_cache_write <= 1'b0;
            end else begin
                cpu_ready <= 1'b0;
                hit <= 1'b0;
                l2_cache_read <= 1'b1;
                l2_cache_write <= 1'b0;
                l2_cache_addr <= cpu_addr;
                reading_from_l2 <= 1'b1;
            end
        end else begin
            $display("CPU write request: addr = %h, data = %h", cpu_addr, cpu_data_in);
        end
    end

    

    
endmodule