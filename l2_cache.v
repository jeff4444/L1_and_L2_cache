`timescale 1ns/1ps

module L2_cache #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 11,
    parameter CACHE_SIZE   = 512,
    parameter BLOCK_SIZE   = 32,
    parameter NUM_WAYS     = 4
) (
    input  wire                          clk,
    input  wire                          rst_n,

    // L1 Cache interface
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
    localparam integer BLOCK_COUNT   = CACHE_SIZE / BLOCK_SIZE;
    localparam integer SET_COUNT     = BLOCK_COUNT / NUM_WAYS;
    localparam integer INDEX_WIDTH   = $clog2(SET_COUNT);
    localparam integer OFFSET_WIDTH  = $clog2(BLOCK_SIZE);
    localparam integer TAG_WIDTH     = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;

    // FSM states
    localparam IDLE            = 2'b00;
    localparam TAG_CHECK       = 2'b01;
    localparam WRITE_ALLOCATE  = 2'b11;

    // cache storage
    reg [TAG_WIDTH-1:0]                     TAGS   [0:SET_COUNT-1][0:NUM_WAYS-1];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0]    DATAS  [0:SET_COUNT-1][0:NUM_WAYS-1];
    reg                                     VALIDS [0:SET_COUNT-1][0:NUM_WAYS-1];

    // FSM registers
    reg [1:0] curr_state, next_state;

    // loop indices
    integer i, j;

    // helper signals
    wire [TAG_WIDTH-1:0]     tag;
    wire [INDEX_WIDTH-1:0]   index;
    wire [OFFSET_WIDTH-1:0]  offset;

    assign tag    = l1_cache_addr[ADDR_WIDTH-1 -: TAG_WIDTH];
    assign index  = l1_cache_addr[OFFSET_WIDTH + INDEX_WIDTH-1 -: INDEX_WIDTH];
    assign offset = l1_cache_addr[OFFSET_WIDTH-1:0];

    // hit detection
    reg                                     found;
    reg [$clog2(NUM_WAYS)-1:0]             found_way;
    always @(*) begin
        found = 1'b0;
        found_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (VALIDS[index][i] && TAGS[index][i] == tag) begin
                found = 1'b1;
                found_way = i;
            end
        end
    end

    // choose an empty way if miss
    reg                                     have_empty;
    reg [$clog2(NUM_WAYS)-1:0]             empty_way;
    always @(*) begin
        have_empty = 1'b0;
        empty_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!VALIDS[index][i] && !have_empty) begin
                have_empty = 1'b1;
                empty_way = i;
            end
        end
    end

    // next-state logic
    always @(*) begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (l1_cache_read || l1_cache_write)
                    next_state = TAG_CHECK;
            end
            TAG_CHECK: begin
                if (found)                      next_state = IDLE;
                else if (l1_cache_write)        next_state = IDLE;
                else                             next_state = WRITE_ALLOCATE;
            end
            WRITE_ALLOCATE: begin
                if (mem_ready) next_state = IDLE;
                else            next_state = WRITE_ALLOCATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // FSM & outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state       <= IDLE;
            // clear outputs
            l1_cache_ready   <= 1'b0;
            l1_block_valid   <= 1'b0;
            l1_cache_hit     <= 1'b0;
            mem_read         <= 1'b0;
            mem_write        <= 1'b0;
            mem_addr         <= {ADDR_WIDTH{1'b0}};
            mem_data_out     <= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};
            l1_block_data_out<= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};
            // invalidate lines
            for (i = 0; i < SET_COUNT; i = i + 1)
                for (j = 0; j < NUM_WAYS; j = j + 1)
                    VALIDS[i][j] <= 1'b0;
        end else begin
            curr_state       <= next_state;
            // default outputs
            l1_cache_ready   <= 1'b0;
            l1_block_valid   <= 1'b0;
            l1_cache_hit     <= 1'b0;
            mem_read         <= 1'b0;
            mem_write        <= 1'b0;
            mem_addr         <= {ADDR_WIDTH{1'b0}};
            mem_data_out     <= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};
            l1_block_data_out<= {(BLOCK_SIZE*DATA_WIDTH){1'b0}};

            case (curr_state)
                IDLE: begin
                    // no action
                end

                TAG_CHECK: begin
                    if (found) begin
                        // hit path
                        l1_cache_hit     <= 1'b1;
                        l1_cache_ready   <= 1'b1;
                        if (l1_cache_read) begin
                            l1_block_data_out <= DATAS[index][found_way];
                        end else begin
                            // write-through hit
                            DATAS[index][found_way] <= l1_cache_data_in;
                            mem_data_out            <= l1_cache_data_in;
                            mem_addr                <= {tag, index, {OFFSET_WIDTH{1'b0}}};
                            mem_write               <= 1'b1;
                            l1_block_data_out       <= l1_cache_data_in;
                        end
                        VALIDS[index][found_way] <= 1'b1;
                        l1_block_valid           <= 1'b1;
                    end else begin
                        // miss path
                        reg [$clog2(NUM_WAYS)-1:0] alloc_way;
                        alloc_way = have_empty ? empty_way : 0;

                        if (l1_cache_write) begin
                            // write-miss allocate
                            TAGS[index][alloc_way]   <= tag;
                            VALIDS[index][alloc_way] <= 1'b1;
                            DATAS[index][alloc_way]  <= l1_cache_data_in;
                            mem_data_out             <= l1_cache_data_in;
                            mem_addr                 <= {tag, index, {OFFSET_WIDTH{1'b0}}};
                            mem_write                <= 1'b1;
                            l1_block_data_out        <= l1_cache_data_in;
                            l1_block_valid           <= 1'b1;
                            l1_cache_ready           <= 1'b1;
                        end else begin
                            // read-miss
                            mem_addr <= {tag, index, {OFFSET_WIDTH{1'b0}}};
                            mem_read <= 1'b1;
                        end
                    end
                end

                WRITE_ALLOCATE: begin
                    // wait for memory response
                    mem_read <= 1'b1;
                    if (mem_ready) begin
                        reg [$clog2(NUM_WAYS)-1:0] alloc_way;
                        alloc_way = have_empty ? empty_way : 0;
                        // fill from memory
                        TAGS[index][alloc_way]   <= tag;
                        VALIDS[index][alloc_way] <= 1'b1;
                        DATAS[index][alloc_way]  <= mem_data_block;
                        l1_block_data_out        <= mem_data_block;
                        l1_block_valid           <= 1'b1;
                        l1_cache_ready           <= 1'b1;
                    end
                end

            endcase
        end
    end

endmodule

