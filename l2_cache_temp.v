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
    output l2_hit,
    
    // L2 Cache interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_out, // Data to be written to l2 cache
    input wire [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] mem_data_in, // Data read from l2 cache
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

    localparam L1_BLOCK_WIDTH = $clog2(L1_BLOCK_SIZE);

    // cache line structure
    reg [TAG_WIDTH-1:0] tags[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data[NUM_SETS-1:0][NUM_WAYS-1:0];
    reg valid[NUM_SETS-1:0][NUM_WAYS-1:0];

    // cache controller state
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00;
    localparam COMPARE_TAG = 2'b01;
    localparam WRITE_BACK = 2'b10;
    localparam ALLOCATE = 2'b11;

    // decompose address into tag, index, and byte offset
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;

    // assign index, byte_offset, and tag
    assign index = l2_cache_addr[INDEX_WIDTH+BYTE_OFFSET_WIDTH-1:BYTE_OFFSET_WIDTH];
    assign tag = l2_cache_addr[ADDR_WIDTH-1:INDEX_WIDTH+BYTE_OFFSET_WIDTH];

    // cache hit detection
    reg hit;
    reg updated;
    reg [$clog2(NUM_WAYS) - 1:0] updated_way;
    integer i;
    reg found;
    reg [BLOCK_SIZE-1:0][DATA_WIDTH-1:0] data_found;
    reg [BYTE_OFFSET_WIDTH-1:0] start_addr;

    // Delay logic for reads
    reg [3:0] delay_cnt;
    reg read_pending;
    reg [ADDR_WIDTH-1:0] pending_addr;

    always @(l2_cache_addr) begin
        if (BLOCK_SIZE > L1_BLOCK_SIZE) begin
            start_addr = {l2_cache_addr[BYTE_OFFSET_WIDTH-1:L1_BLOCK_WIDTH], {L1_BLOCK_WIDTH{1'b0}}};
        end else begin
            start_addr = 0;
        end
    end

    assign l2_hit = hit || mem_hit;

    // state transition
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    always @(*) begin
    found = 1'b0;
        for (i = 0; i < NUM_WAYS; i = i + 1)
            if (valid[index][i] && tags[index][i] == tag) begin
                found = 1'b1;
                data_found = data[index][i];
            end
    end

    always @(*) begin
        updated = 1'b0;
        updated_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] && !updated) begin
                updated = 1'b1;
                updated_way = i;
            end
        end
    end

    // next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (l2_cache_read || l2_cache_write) begin
                    next_state = COMPARE_TAG;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPARE_TAG: begin
                if (delay_cnt > 0) begin
                    next_state = COMPARE_TAG;
                end else begin
                    if (found) begin
                        next_state = IDLE;
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end
            ALLOCATE: begin
                if (mem_hit) begin
                    next_state = IDLE;
                end else begin
                    next_state = ALLOCATE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // cache FSM
    always @(posedge clk) begin
        if (!rst_n) begin
            l2_cache_ready <= 1'b0;
            hit <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            mem_addr <= {ADDR_WIDTH{1'b0}};
            mem_data_out <= 0;
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                for (integer j = 0; j < NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    l2_cache_ready <= 1'b0;
                    hit <= 1'b0;
                    mem_read <= 1'b0;
                    mem_write <= 1'b0;
                    mem_addr <= {ADDR_WIDTH{1'b0}};
                    mem_data_out <= 0;
                    l2_cache_data_out <= 0;
                    delay_cnt <= 8;
                end
                COMPARE_TAG: begin
                    if (delay_cnt > 0) begin
                        delay_cnt <= delay_cnt - 1;
                        l2_cache_ready <= 1'b0;
                        mem_read <= 1'b0;
                        mem_write <= 1'b0;
                        read_pending <= 1'b1;
                        pending_addr <= l2_cache_addr;
                    end else begin
                        delay_cnt <= 0;
                        mem_read <= 1'b0;
                        mem_write <= 1'b0;
                        mem_addr <= {ADDR_WIDTH{1'b0}};
                        mem_data_out <= 0;
                        if (found) begin
                            $display("%0t [L2] Cache hit: addr = %h, data = %h", $time, l2_cache_addr, data_found);
                            hit <= 1'b1;
                            l2_cache_ready <= 1'b1;
                            l2_cache_data_out <= data_found;
                        end else begin
                            $display("%0t [L2] Cache miss: addr = %h", $time, l2_cache_addr);
                            hit <= 1'b0;
                            l2_cache_ready <= 1'b0;
                            mem_addr <= {tag, index, {BYTE_OFFSET_WIDTH{1'b0}}};
                            mem_read <= 1'b1;
                            l2_cache_ready <= 1'b0;
                        end
                    end
                end
                ALLOCATE: begin
                    if (mem_hit) begin
                        $display("%0t [L2] Cache Allocate: addr = %h data = %h", $time, l2_cache_addr, mem_data_in);
                        mem_read <= 1'b0;
                        mem_write <= 1'b0;
                        mem_addr <= {ADDR_WIDTH{1'b0}};
                        mem_data_out <= 0;
                        if (updated) begin
                            valid[index][updated_way] <= 1'b1;
                            tags[index][updated_way] <= tag;
                            data[index][updated_way] <= mem_data_in;
                        end else begin
                            valid[index][0] <= 1'b1;
                            tags[index][0] <= tag;
                            data[index][0] <= mem_data_in;
                        end
                        for (i = 0; i < L1_BLOCK_SIZE; i = i + 1) begin
                            l2_cache_data_out[i] <= mem_data_in[start_addr + i];
                        end
                        l2_cache_ready <= 1'b1;
                    end else begin
                        mem_read <= read_pending;
                        mem_write <= l2_cache_write;
                        mem_addr <= pending_addr;
                        mem_data_out <= l2_cache_data_in;
                        l2_cache_ready <= 1'b0;
                    end
                end
            endcase
        end
    end 
endmodule