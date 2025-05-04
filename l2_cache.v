module L2_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11,
    parameter CACHE_SIZE = 512,
    parameter BLOCK_SIZE = 32,
    parameter NUM_WAYS = 4
) (
    input wire clk,
    input wire rst_n,
    
    // L1 Cache interface
    input wire [ADDR_WIDTH-1:0] l1_cache_addr,
    input wire [DATA_WIDTH-1:0] l1_cache_data_in,
    output reg [DATA_WIDTH*(BLOCK_SIZE/(DATA_WIDTH/8))-1:0] l1_block_data_out,
    output reg l1_block_valid,
    input wire l1_cache_read,
    input wire l1_cache_write,
    output reg l1_cache_ready,
    output reg l1_cache_hit,
    
    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_data_out, // Data to be written to memory
    input  wire [DATA_WIDTH*(BLOCK_SIZE/(DATA_WIDTH/8))-1:0] mem_data_block,
    output reg mem_read,
    output reg mem_write,
    input wire mem_ready
);
    //Module constants
    localparam block_num = CACHE_SIZE/BLOCK_SIZE;
    localparam set_num = block_num / NUM_WAYS;
    localparam index_width = $clog2(set_num);
    localparam offset_width = $clog2(BLOCK_SIZE);
    localparam tag_width = ADDR_WIDTH - index_width - offset_width;
    localparam words_per_block = BLOCK_SIZE / (DATA_WIDTH/8);

    //FSM-Sates
    reg [1:0]next_state, curr_state;
    localparam IDLE = 2'b00;
    localparam TAG_CHECK = 2'b01;
    localparam WRITE_BACK = 2'b10;
    localparam WRITE_ALLOCATE = 2'b11; 

    //L2 cache 
    reg [tag_width-1:0]     TAGS[0:set_num-1][0:NUM_WAYS-1]; //Tag 2d vector reg
    reg [DATA_WIDTH-1:0]    DATAS[0: set_num-1][0:NUM_WAYS-1][0:words_per_block-1]; //Data 2D vector reg
    reg                     VALIDS[0:set_num-1][0:NUM_WAYS-1];

    //Address calculations
    wire[offset_width-1:0] byte_offset;
    wire[index_width-1:0] index;
    wire[tag_width-1:0] tag;

    //We need to give index, byte_offset and tag thier respective values
    assign tag = l1_cache_addr[ADDR_WIDTH-1:index_width + offset_width];
    assign index = l1_cache_addr[offset_width + index_width -1 :offset_width];
    assign byte_offset = l1_cache_addr[offset_width-1:0];

    //Miss handling helpers
    reg l2_hit;
    reg update;
    integer ii;
    //reg [$clog2(words_per_block)-1:0] beat_cnt;
    reg [$clog2(NUM_WAYS)-1:0] alloc_way;


    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end 
    end 

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            l1_cache_ready  <= 1'b0;
            l1_cache_hit    <= 1'b0;
            l1_block_valid  <= 1'b0;
            mem_read        <= 1'b0;
            mem_write       <= 1'b0;
            mem_data_out    <= {DATA_WIDTH{1'b0}};
            mem_addr        <= {ADDR_WIDTH{1'b0}};
            l1_block_data_out <= {DATA_WIDTH*(BLOCK_SIZE/(DATA_WIDTH/8)){1'b0}};
            // Invalidate all lines
            for (ii = 0; ii < set_num; ii = ii + 1)begin
                for(alloc_way = 0; alloc_way < NUM_WAYS; alloc_way = alloc_way +1)
                VALIDS[ii][alloc_way] <= 1'b0;
            end 
        end 
        else begin
            l1_cache_ready <= 1'b0;
            l1_block_valid <= 1'b0;
            l1_cache_hit   <= 1'b0;
            mem_read       <= 1'b0;
            mem_write      <= 1'b0;
            l2_hit         <= 1'b0;
            update         <= 1'b0;
            
            case(curr_state)
                IDLE: begin
                    if(l1_cache_read || l1_cache_write)begin
                        next_state <= TAG_CHECK;
                    end 
                    else begin
                        next_state <= IDLE;
                    end 
                end 
                TAG_CHECK: begin
                    
                    for(ii = 0; ii < NUM_WAYS; ii = ii + 1)begin
                        if(VALIDS[index][ii] && (TAGS[index][ii] == tag))begin
                            l2_hit <= 1'b1;
                            l1_cache_hit <= 1'b1;
                            l1_block_data_out <= {
                                DATAS[index][ii][0], DATAS[index][ii][1], DATAS[index][ii][2], DATAS[index][ii][3],
                                DATAS[index][ii][4], DATAS[index][ii][5], DATAS[index][ii][6], DATAS[index][ii][7]    
                            };
                            l1_block_valid <= 1'b1;
                        end 
                    end 
                    if(l2_hit)begin
                        //hit return data
                        l1_cache_ready <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        //We choose a way: first invalid or way 0
                        for(alloc_way = 0; alloc_way < NUM_WAYS; alloc_way = alloc_way +1) begin
                            if(!VALIDS[index][alloc_way] && !update) begin
                                update <= 1'b1;
                            end 
                        end 
                        if(!update)begin
                            alloc_way <= 0;
                        end 

                        mem_addr   <= { tag, index, {offset_width{1'b0}} };
                        mem_read <= 1'b1;
                        next_state <= WRITE_ALLOCATE;
                    end
                end   
                WRITE_ALLOCATE: begin
                    mem_read <= 1'b1;
                    if(mem_ready) begin
                        //write entire block
                        for(ii = 0; ii < words_per_block; ii = ii + 1)
                            DATAS[index][alloc_way][ii] <= mem_data_block[ii*DATA_WIDTH +: DATA_WIDTH];
                        TAGS[index][alloc_way]      <= tag;
                        VALIDS[index][alloc_way]    <= 1'b1;
                        //forward to L1

                        l1_block_data_out <= mem_data_block;
                        l1_block_valid <= 1'b1;
                        l1_cache_ready <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        next_state <= WRITE_ALLOCATE;
                    end 
                end 
                default: next_state <= IDLE;
            endcase
        end 
    end 
                          
endmodule