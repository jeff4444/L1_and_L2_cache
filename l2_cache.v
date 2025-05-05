module L2_cache #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 32,
    parameter CACHE_SIZE     = 1024,
    parameter BLOCK_SIZE     = 16,
    parameter NUM_WAYS       = 4
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // L1 interface
    input  wire [ADDR_WIDTH-1:0]         l1_cache_addr,
    input  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_cache_data_in,
    output reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_block_data_out,
    output reg                           l1_block_valid,
    input  wire                          l1_cache_read,
    input  wire                          l1_cache_write,
    output reg                           l1_cache_ready,
    output reg                           l1_cache_hit,

    // Memory interface
    input  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_block,
    input  wire                          mem_ready,
    output reg  [ADDR_WIDTH-1:0]         mem_addr,
    output reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out,
    output reg                          mem_read,
    output reg                          mem_write
);

    // derived parameters
    localparam NUM_BLOCKS   = CACHE_SIZE  / BLOCK_SIZE;
    localparam NUM_SETS     = NUM_BLOCKS  / NUM_WAYS;
    localparam INDEX_WIDTH  = $clog2(NUM_SETS);
    localparam OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;

    // storage arrays
    reg [TAG_WIDTH-1:0]                          tags      [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]         data_mem  [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg                                          valid     [0:NUM_SETS-1][0:NUM_WAYS-1];

    // FSM states
    reg [1:0] curr_state, next_state;
    localparam IDLE        = 2'b00;
    localparam COMPARE_TAG = 2'b01;
    localparam ALLOCATE    = 2'b11;

    // address split
    wire [INDEX_WIDTH-1:0] index = l1_cache_addr[INDEX_WIDTH+OFFSET_WIDTH-1:OFFSET_WIDTH];
    wire [TAG_WIDTH-1:0]   tag   = l1_cache_addr[ADDR_WIDTH-1:INDEX_WIDTH+OFFSET_WIDTH];

    // hit detection
    reg                            found;
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_found;
    integer                        i;
    always @(*) begin
        found = 1'b0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && tags[index][i] == tag) begin
                found       = 1'b1;
                data_found  = data_mem[index][i];
            end
        end
    end

    // choose a free way
    reg                            chosen;
    reg [$clog2(NUM_WAYS)-1:0]     chosen_way;
    always @(*) begin
        chosen      = 1'b0;
        chosen_way  = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] && !chosen) begin
                chosen      = 1'b1;
                chosen_way  = i;
            end
        end
    end

    // state register with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            for (i = 0; i < NUM_SETS; i = i + 1)
                for (integer j = 0; j < NUM_WAYS; j = j + 1)
                    valid[i][j] <= 1'b0;
        end else begin
            curr_state <= next_state;
        end
    end

    // next-state + output logic
    always @(*) begin
        // defaults
        next_state        = curr_state;
        mem_read          = 1'b0;
        mem_write         = 1'b0;
        mem_addr          = {ADDR_WIDTH{1'b0}};
        mem_data_out      = '0;
        l1_cache_ready    = 1'b0;
        l1_block_valid    = 1'b0;
        l1_cache_hit      = 1'b0;
        l1_block_data_out = '0;

        case (curr_state)
            IDLE: begin
                if (l1_cache_read || l1_cache_write)
                    next_state = COMPARE_TAG;
            end

            COMPARE_TAG: begin
                if (found) begin
                    // hit
                    l1_cache_hit      = 1'b1;
                    l1_cache_ready    = 1'b1;
                    l1_block_valid    = l1_cache_read;
                    if (l1_cache_read)
                        l1_block_data_out = data_found;
                    next_state        = IDLE;
                end else begin
                    // miss: send request
                    mem_addr   = {tag, index, {OFFSET_WIDTH{1'b0}}};
                    mem_read   = 1'b1;
                    mem_write  = l1_cache_write;
                    next_state = ALLOCATE;
                end
            end

            ALLOCATE: begin
                if (!mem_ready) begin
                    // hold request until ready
                    mem_read  = 1'b1;
                    mem_write = 1'b0;
                end else begin
                    // memory responded: install block
                    if (chosen) begin
                        tags[index][chosen_way]     = tag;
                        data_mem[index][chosen_way] = mem_data_block;
                        valid[index][chosen_way]     = 1'b1;
                    end else begin
                        tags[index][0]         = tag;
                        data_mem[index][0]     = mem_data_block;
                        valid[index][0]        = mem_data_block;
                    end
                    // drive L1 outputs
                    l1_block_data_out = mem_data_block;
                    l1_block_valid    = 1'b1;
                    l1_cache_ready    = 1'b1;
                    next_state        = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
