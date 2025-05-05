module L2_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16,
    parameter NUM_WAYS = 4,
    parameter L1_BLOCK_SIZE = 16
)(
    input wire clk,
    input wire rst_n,

    // CPU interface
    input wire [ADDR_WIDTH-1:0] l2_cache_addr,
    input wire [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_in,
    output reg [L1_BLOCK_SIZE-1:0][DATA_WIDTH-1:0] l2_cache_data_out,
    input wire l2_cache_read,
    input wire l2_cache_write,
    output reg l2_cache_ready,
    output wire l2_hit,

    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out,
    input wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_in,
    output reg mem_read,
    output reg mem_write,
    input wire mem_ready,
    input wire mem_hit
);

    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS = NUM_BLOCKS / NUM_WAYS;
    localparam INDEX_WIDTH = $clog2(NUM_SETS);
    localparam BYTE_OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET_WIDTH;

    reg [TAG_WIDTH-1:0] tags[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg valid[NUM_SETS-1:0][NUM_WAYS-1:0];

    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, COMPARE_TAG = 2'b01, ALLOCATE = 2'b10;

    wire [INDEX_WIDTH-1:0] index = l2_cache_addr[INDEX_WIDTH + BYTE_OFFSET_WIDTH - 1 : BYTE_OFFSET_WIDTH];
    wire [TAG_WIDTH-1:0] tag = l2_cache_addr[ADDR_WIDTH - 1 : INDEX_WIDTH + BYTE_OFFSET_WIDTH];

    wire [BYTE_OFFSET_WIDTH-1:0] offset = l2_cache_addr[BYTE_OFFSET_WIDTH-1:0];
    wire [BYTE_OFFSET_WIDTH-1:0] start_index = (offset >> $clog2(L1_BLOCK_SIZE)) << $clog2(L1_BLOCK_SIZE);


    reg hit;
    reg [$clog2(NUM_WAYS)-1:0] hit_way;
    reg [$clog2(NUM_WAYS)-1:0] alloc_way;

    reg [3:0] delay_cnt;
    reg [BYTE_OFFSET_WIDTH-1:0] start_addr;
    integer i, j;

    assign l2_hit = hit || mem_hit;

    // Determine hit
    always @(*) begin
        hit = 1'b0;
        hit_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && tags[index][i] == tag) begin
                hit = 1'b1;
                hit_way = i;
            end
        end
    end

    // Find a replacement way (invalid or use way 0)
    always @(*) begin
        alloc_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!valid[index][i]) begin
                alloc_way = i;
            end
        end
    end

    // FSM transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:
                if (l2_cache_read || l2_cache_write)
                    next_state = COMPARE_TAG;
                else
                    next_state = IDLE;

            COMPARE_TAG:
                if (delay_cnt > 0)
                    next_state = COMPARE_TAG;
                else if (hit)
                    next_state = IDLE;
                else
                    next_state = ALLOCATE;

            ALLOCATE:
                if (mem_ready || mem_hit)
                    next_state = IDLE;
                else
                    next_state = ALLOCATE;

            default: next_state = IDLE;
        endcase
    end

    // FSM outputs and behavior
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_cache_ready <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            hit <= 1'b0;
            mem_addr <= 0;
            mem_data_out <= 0;
            l2_cache_data_out <= 0;
            delay_cnt <= 0;
            for (i = 0; i < NUM_SETS; i = i + 1)
                for (j = 0; j < NUM_WAYS; j = j + 1)
                    valid[i][j] <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    l2_cache_ready <= 1'b0;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    delay_cnt <= 4;  // adjustable latency
                end

                COMPARE_TAG: begin
                    if (delay_cnt > 0)
                        delay_cnt <= delay_cnt - 1;
                    else if (hit) begin
                        l2_cache_ready <= 1'b1;
                        for (i = 0; i < L1_BLOCK_SIZE; i = i + 1) begin
                            l2_cache_data_out[i] <= data[index][hit_way][i];
                        end
                        $display("%0t [L2] Cache hit: addr = 0x%h", $time, l2_cache_addr);
                    end else begin
                        mem_addr <= {tag, index, {BYTE_OFFSET_WIDTH{1'b0}}};
                        mem_read <= 1'b1;
                        l2_cache_ready <= 1'b0;
                        $display("%0t [L2] Cache miss: addr = 0x%h", $time, l2_cache_addr);
                    end
                end

                ALLOCATE: begin
                    if (mem_ready || mem_hit) begin
                        // install block
                        data[index][alloc_way] <= mem_data_in;
                        tags[index][alloc_way] <= tag;
                        valid[index][alloc_way] <= 1'b1;

                        // transfer L1 block
                        for (i = 0; i < L1_BLOCK_SIZE; i = i + 1) begin
                            if ((start_index + i) < BLOCK_SIZE)begin
                                l2_cache_data_out[i] <= mem_data_in[start_index + i];
                            end
                            else begin
                                l2_cache_data_out[i] <= 0;
                            end
                        end

                        l2_cache_ready <= 1'b1;
                        mem_read <= 1'b0;
                        $display("%0t [L2] Cache Allocate Complete: addr = 0x%h", $time, l2_cache_addr);
                    end
                end
            endcase
        end
    end
endmodule
