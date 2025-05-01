module L2_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 32,
    parameter NUM_WAYS = 4
) (
    input wire clk,
    input wire rst_n,
    
    // L1 Cache interface
    input wire [ADDR_WIDTH-1:0] l1_cache_addr,
    input wire [DATA_WIDTH-1:0] l1_cache_data_in,
    output reg [DATA_WIDTH-1:0] l1_cache_data_out,
    input wire l1_cache_read,
    input wire l1_cache_write,
    output reg l1_cache_ready,
    output reg l1_cache_hit,
    
    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_data_out, // Data to be written to memory
    input wire [DATA_WIDTH-1:0] mem_data_in, // Data read from memory
    output reg mem_read,
    output reg mem_write,
    input wire mem_ready,
);
    //Module constants
    localparam block_num = CACHE_SIZE/BLOCK_SIZE;
    localparam set_num = block_num / NUM_WAYS;
    localparam index_width = $clog2(set_num);
    localparam offset_width = $clog2(BLOCK_SIZE);
    localparam tag_width = ADDR_WIDTH - index_width - offset_width;

    //FSM-Sates
    reg [1:0]next_state, curr_state;
    localparam IDLE = 2'b00;
    localparam TAG_CHECK = 2'b01;
    localparam WRITE_BACK = 2'b10;
    localparam WRITE_ALLOCATE = 2'b11; 

    //L2 cache 
    reg [tag_width-1:0] TAGS[set_num-1:0][NUM_WAYS-1:0]; //Tag 2d vector reg
    reg [DATA_WIDTH-1:0] DATAS[set_num-1:0][NUM_WAYS-1:0]; //Data 2D vector reg
    reg [NUM_WAYS-1:0] VALIDS[set_num-1:0];

    //Address calculations
    wire[offset_width-1:0] byte_offset;
    wire[index_width-1:0] index;
    wire[tag_width-1:0] tag;

    //We need to give index, byte_offset and tag thier respective values
    assign tag = l1_cache_addr[ADDR_WIDTH-1:index_width + offset_width];
    assign index = l1_cache_addr[offset_width + index_width -1 :offset_width];
    assign byte_offset = l1_cache_addr[offset_width-1:0];

    //L2 detection
    reg l2_hit;
    reg update;
    integer ii;
    
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
            l1_cache_ready <= 1'b0;
            l1_cache_hit <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            mem_data_out <= {DATA_WIDTH_WIDTH{1'b0}};
            mem_addr <= {ADDR_WIDTH{1'b0}};
            // Invalidate all lines
            for (i = 0; i < SET_NUM; i = i + 1)begin
                valid[i] <= {NUM_WAYS{1'b0}};
            end 
        else begin
            l1_cache_ready <= 1'b0;
            mem_read       <= 1'b0;
            mem_write      <= 1'b0;
            l2_hit         <= 1'b0;
            update         <= 1'b0;
            l1_cache_hit   <= 1'b0;
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
                    l1_cache_hit <= 0;
                    for(ii = 0; ii < NUM_WAYS; ii = ii + 1)begin
                        if(VALIDS[index][ii] && (TAGS[index][ii] == tag))begin
                            l2_hit <= 1'b1;
                            l1_cache_hit <= 1'b1;
                            l1_cache_data_out <= DATAS[index][ii];
                        end 
                    end 
                    if(l2_hit)begin
                        //hit return data
                        l1_cache_ready <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        mem_addr <= l1_cache_addr;
                        mem_read <= 1'b1;
                        next_state <= WRITE_ALLOCATE;
                    end
                end   
                WRITE_ALLOCATE: begin
                    if(mem_ready)begin
                        for(ii = 0; ii < NUM_WAYS; ii = ii + 1)begin
                            if(!VALIDS[index][ii] && ! update)begin
                                TAGS[index][ii] <= tag;
                                VALIDS[index][ii] <= 1'b1;
                                DATAS[index][ii] <= mem_data_in;
                                update <= 1'b1;
                            end 
                        end 
                        if(!update)begin
                            //If !update after the for loop this means that all the blocks are full 
                            TAGS[index][0] <= tag;
                            VALIDS[index][0] <= 1'b1;
                            DATAS[index][0] <= mem_data_in;
                        end 
                        l1_cache_ready <= 1'b1;
                        l1_cache_hit <= 1'b0; //Fetched from Mem 
                        next_state <= IDLE;
                    end
                    else begin
                        next_state <= WRITE_ALLOCATE;
                    end                    
                end 
                default: next_state <= IDLE;
            endcase
        end 
    end 
                          
endmodule