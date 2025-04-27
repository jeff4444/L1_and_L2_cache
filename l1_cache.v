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
    output reg cpu_hit,
    
    // L2 Cache interface
    output reg [ADDR_WIDTH-1:0] l2_cache_addr,
    output reg [DATA_WIDTH-1:0] l2_cache_data_out, // Data to be written to l2 cache
    input wire [DATA_WIDTH-1:0] l2_cache_data_in, // Data read from l2 cache
    output reg l2_cache_read,
    output reg l2_cache_write,
    input wire l2_cache_ready,
    input wire l2_cache_hit,
);
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS = NUM_BLOCKS / NUM_WAYS;
    localparam INDEX_WIDTH = $clog2(NUM_SETS);
    localparam BYTE_OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET_WIDTH;

    // cache line structure
    reg [TAG_WIDTH-1:0] tags[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [DATA_WIDTH-1:0] data[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [NUM_WAYS-1:0] valid[NUM_SETS-1:0];

    // cache controller state
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00;
    localparam COMPARE_TAG = 2'b01;
    localparam WRITE_BACK = 2'b10;
    localparam ALLOCATE = 2'b11;

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

    // state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (cpu_read || cpu_write) begin
                    next_state = COMPARE_TAG;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPARE_TAG: begin
                if (hit) begin
                    next_state = IDLE;
                end else if (l2_cache_hit) begin
                    next_state = IDLE;
                end else begin
                    next_state = ALLOCATE;
                end
            end
            ALLOCATE: begin
                if (l2_cache_ready) begin
                    next_state = IDLE;
                end else begin
                    next_state = ALLOCATE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // state actions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_ready <= 1'b0;
            cpu_hit <= 1'b0;
            l2_cache_read <= 1'b0;
            l2_cache_write <= 1'b0;
            l2_cache_addr <= 0;
            l2_cache_data_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cpu_ready <= 1'b0;
                    cpu_hit <= 1'b0;
                    l2_cache_read <= 1'b0;
                    l2_cache_write <= 1'b0;
                end
                COMPARE_TAG: begin
                    hit = 1'b0;
                    for (i = 0; i < NUM_WAYS; i = i + 1) begin
                        if (valid[index][i] && (tags[index][i] == tag)) begin
                            hit = 1'b1;
                            cpu_hit <= 1'b1;
                            cpu_data_out <= data[index][i];
                        end
                    end
                    if (hit) begin
                        cpu_ready <= 1'b1;
                    end else begin
                        l2_cache_addr <= cpu_addr;
                        l2_cache_read <= 1'b1;
                    end
                end
                ALLOCATE: begin
                    updated = 1'b0;
                    if (l2_cache_ready) begin
                        for (i = 0; i < NUM_WAYS; i = i + 1) begin
                            if (!valid[index][i] && !updated) begin
                                tags[index][i] <= tag;
                                data[index][i] <= l2_cache_data_in;
                                valid[index][i] <= 1'b1;
                                updated = 1'b1;
                            end
                        end
                        if (!updated) begin
                            // Evict a block (first block)
                            tags[index][0] <= tag;
                            data[index][0] <= l2_cache_data_in;
                            valid[index][0] <= 1'b1;
                        end
                        cpu_ready <= 1'b1;
                        cpu_hit <= 1'b0; // Not a hit since we had to fetch from L2
                    end
                end
            endcase
        end
    end
    
endmodule