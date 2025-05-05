module L2_cache #(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 11,
    parameter CACHE_SIZE  = 512,
    parameter BLOCK_SIZE  = 32,
    parameter NUM_WAYS    = 4
) (
    input  wire                             clk,
    input  wire                             rst_n,
    // L1 Cache interface
    input  wire [ADDR_WIDTH-1:0]            l1_cache_addr,
    input  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_cache_data_in,
    output reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l1_block_data_out,
    output reg                              l1_block_valid,
    input  wire                             l1_cache_read,
    input  wire                             l1_cache_write,
    output reg                              l1_cache_ready,
    output reg                              l1_cache_hit,
    // Memory interface
    input  wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_block,
    input  wire                             mem_ready,
    output reg  [ADDR_WIDTH-1:0]            mem_addr,
    output reg  [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out,
    output reg                             mem_read,
    output reg                             mem_write
);

  
    localparam block_num    = CACHE_SIZE / BLOCK_SIZE;
    localparam set_num      = block_num    / NUM_WAYS;
    localparam index_width  = $clog2(set_num);
    localparam offset_width = $clog2(BLOCK_SIZE);
    localparam tag_width    = ADDR_WIDTH - index_width - offset_width;

    // State encoding
    localparam IDLE           = 2'b00,
               TAG_CHECK      = 2'b01,
               WRITE_ALLOCATE = 2'b11;

    // Registers
    reg [1:0] curr_state, next_state;
    reg [tag_width-1:0]                  TAGS   [set_num-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] DATAS  [set_num-1:0][NUM_WAYS-1:0];
    reg                                  VALIDS [set_num-1:0][NUM_WAYS-1:0];

    // Address breakdown
    wire [tag_width-1:0]   tag   = l1_cache_addr[ADDR_WIDTH-1               : offset_width + index_width];
    wire [index_width-1:0] index = l1_cache_addr[offset_width + index_width-1 : offset_width];

    // Hit detection helpers
    reg                          hit;
    reg [$clog2(NUM_WAYS)-1:0]   hit_way;
    integer                      ii;

   
    always @(*) begin
        hit      = 1'b0;
        hit_way  = { $clog2(NUM_WAYS){1'b0} };
        for (ii = 0; ii < NUM_WAYS; ii = ii + 1) begin
            if (VALIDS[index][ii] && TAGS[index][ii] == tag) begin
                hit     = 1'b1;
                hit_way = ii[$clog2(NUM_WAYS)-1:0];
            end
        end
    end

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    
    always @(*) begin
        next_state = curr_state;  // default
        case (curr_state)
            IDLE: begin
                if (l1_cache_read || l1_cache_write)
                    next_state = TAG_CHECK;
            end

            TAG_CHECK: begin
                if      (hit)               next_state = IDLE;
                else if (l1_cache_write)    next_state = IDLE;      // write‐miss allocate immediately
                else                        next_state = WRITE_ALLOCATE;
            end

            WRITE_ALLOCATE: begin
                if (mem_ready)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

   
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // --- reset all outputs & invalidate lines ---
            l1_cache_ready    <= 1'b0;
            l1_cache_hit      <= 1'b0;
            l1_block_valid    <= 1'b0;
            mem_read          <= 1'b0;
            mem_write         <= 1'b0;
            mem_data_out      <= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};
            mem_addr          <= {ADDR_WIDTH{1'b0}};
            l1_block_data_out <= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};
            for (ii = 0; ii < set_num; ii = ii + 1)
                for (integer w = 0; w < NUM_WAYS; w = w + 1)
                    VALIDS[ii][w] <= 1'b0;
        end
        else begin
            // --- default de‐assert on every cycle ---
            l1_cache_ready <= 1'b0;
            l1_cache_hit   <= 1'b0;
            l1_block_valid <= 1'b0;
            mem_read       <= 1'b0;
            mem_write      <= 1'b0;

            case (curr_state)
                IDLE: begin
                    // nothing to do
                end

                TAG_CHECK: begin
                    if (hit) begin
                        // --- HIT path ---
                        l1_cache_hit     <= 1'b1;
                        VALIDS[index][hit_way] <= 1'b1;
                        if (l1_cache_read) begin
                            l1_block_data_out <= DATAS[index][hit_way];
                        end else begin
                            // write-through
                            DATAS[index][hit_way] <= l1_cache_data_in;
                            mem_addr              <= {tag, index, {offset_width{1'b0}}};
                            mem_data_out          <= l1_cache_data_in;
                            mem_write             <= 1'b1;
                            l1_block_data_out     <= l1_cache_data_in;
                        end
                        l1_block_valid <= 1'b1;
                        l1_cache_ready <= 1'b1;

                    end else begin
                        // --- MISS path ---
                        // pick first invalid way or default 0
                        reg [$clog2(NUM_WAYS)-1:0] alloc_way;
                        alloc_way = { $clog2(NUM_WAYS){1'b0} };
                        for (ii = 0; ii < NUM_WAYS; ii = ii + 1)
                            if (!VALIDS[index][ii])
                                alloc_way = ii[$clog2(NUM_WAYS)-1:0];

                        if (l1_cache_write) begin
                            // write-miss: write allocate
                            TAGS[index][alloc_way]   <= tag;
                            VALIDS[index][alloc_way] <= 1'b1;
                            DATAS[index][alloc_way]  <= l1_cache_data_in;
                            mem_addr                 <= {tag, index, {offset_width{1'b0}}};
                            mem_data_out             <= l1_cache_data_in;
                            mem_write                <= 1'b1;
                            l1_block_data_out        <= l1_cache_data_in;
                            l1_block_valid           <= 1'b1;
                            l1_cache_ready           <= 1'b1;
                        end else begin
                            // read-miss: fetch from memory
                            mem_addr  <= {tag, index, {offset_width{1'b0}}};
                            mem_read  <= 1'b1;
                        end
                    end
                end

                WRITE_ALLOCATE: begin
                    // wait until mem_ready, then install block
                    mem_read <= 1'b1;
                    if (mem_ready) begin
                        DATAS[index][hit_way]   <= mem_data_block;
                        TAGS[index][hit_way]    <= tag;
                        VALIDS[index][hit_way]  <= 1'b1;
                        l1_block_data_out       <= mem_data_block;
                        l1_block_valid          <= 1'b1;
                        l1_cache_ready          <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
