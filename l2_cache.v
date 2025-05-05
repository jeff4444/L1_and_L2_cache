module L2_cache #(
    parameter DATA_WIDTH       = 32,
    parameter ADDR_WIDTH       = 32,
    parameter CACHE_SIZE       = 1024,
    parameter BLOCK_SIZE       = 16,
    parameter NUM_WAYS         = 4,
    parameter L1_BLOCK_SIZE    = 16
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // CPU interface
    input  wire [ADDR_WIDTH-1:0]         l2_cache_addr,
    input  wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_in,
    output reg  [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_out,
    input  wire                          l2_cache_read,
    input  wire                          l2_cache_write,
    output reg                           l2_cache_ready,
    output wire                          l2_hit,

    // L2 Cache interface
    output reg  [ADDR_WIDTH-1:0]         mem_addr,
    output reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out, // Data to be written to l2 cache
    input  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_in,  // Data read from l2 cache
    output reg                           mem_read,
    output reg                           mem_write,
    input  wire                          mem_ready,
    input  wire                          mem_hit
);

    // derived parameters
    localparam NUM_BLOCKS        = CACHE_SIZE  / BLOCK_SIZE;
    localparam NUM_SETS          = NUM_BLOCKS  / NUM_WAYS;
    localparam INDEX_WIDTH       = $clog2(NUM_SETS);
    localparam BYTE_OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH         = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET_WIDTH;
    localparam L1_BLOCK_WIDTH    = $clog2(L1_BLOCK_SIZE);

    // cache storage
    reg [TAG_WIDTH-1:0]                          tags  [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]         data  [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg                                           valid [0:NUM_SETS-1][0:NUM_WAYS-1];

    // FSM states
    reg  [1:0] state, next_state;
    localparam IDLE        = 2'b00;
    localparam COMPARE_TAG = 2'b01;
    localparam WRITE_BACK  = 2'b10;
    localparam ALLOCATE    = 2'b11;

    // decompose address
    wire [INDEX_WIDTH-1:0] index = l2_cache_addr[INDEX_WIDTH+BYTE_OFFSET_WIDTH-1:BYTE_OFFSET_WIDTH];
    wire [TAG_WIDTH-1:0]   tag   = l2_cache_addr[ADDR_WIDTH-1:INDEX_WIDTH+BYTE_OFFSET_WIDTH];

    // hit detection
    reg found;
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_found;
    integer i;
    always @(*) begin
        found = 1'b0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && tags[index][i] == tag) begin
                found      = 1'b1;
                data_found = data[index][i];
            end
        end
    end

    // replacement way selection
    reg                                updated;
    reg [$clog2(NUM_WAYS)-1:0]         updated_way;
    always @(*) begin
        updated     = 1'b0;
        updated_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] && !updated) begin
                updated     = 1'b1;
                updated_way = i;
            end
        end
    end

    // compute start of L1-sized sub-block
    reg [BYTE_OFFSET_WIDTH-1:0] start_addr;
    always @(l2_cache_addr) begin
        if (BLOCK_SIZE > L1_BLOCK_SIZE)
            start_addr = {l2_cache_addr[BYTE_OFFSET_WIDTH-1:L1_BLOCK_WIDTH], {L1_BLOCK_WIDTH{1'b0}}};
        else
            start_addr = '0;
    end


    assign l2_hit = found || mem_hit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i = 0; i < NUM_SETS; i = i + 1)
                for (integer j = 0; j < NUM_WAYS; j = j + 1)
                    valid[i][j] <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // next-state & output logic
    always @(*) begin
        // defaults
        next_state        = state;
        l2_cache_ready    = 1'b0;
        mem_read          = 1'b0;
        mem_write         = 1'b0;
        mem_addr          = {ADDR_WIDTH{1'b0}};
        mem_data_out      = '0;
        l2_cache_data_out = '0;

        case (state)
            IDLE: begin
                if (l2_cache_read || l2_cache_write)
                    next_state = COMPARE_TAG;
            end

            COMPARE_TAG: begin
                if (found) begin
                    l2_cache_ready    = 1'b1;
                    l2_cache_data_out = data_found;
                    next_state        = IDLE;
                end else begin
                    mem_addr    = {tag, index, {BYTE_OFFSET_WIDTH{1'b0}}};
                    mem_read    = 1'b1;
                    next_state  = ALLOCATE;
                end
            end

            ALLOCATE: begin
                if (mem_hit) begin
                    if (updated) begin
                        valid[index][updated_way] = 1'b1;
                        tags[index][updated_way]  = tag;
                        data[index][updated_way]  = mem_data_in;
                    end else begin
                        valid[index][0] = 1'b1;
                        tags[index][0]  = tag;
                        data[index][0]  = mem_data_in;
                    end
                    // return L1-sized slice
                    for (i = 0; i < L1_BLOCK_SIZE; i = i + 1)
                        l2_cache_data_out[i] = mem_data_in[start_addr + i];
                    l2_cache_ready = 1'b1;
                    next_state     = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
