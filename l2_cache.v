module L2_cache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 32,
    parameter NUM_WAYS = 4,
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
    input wire mem_hit
);
    //Module constants
    localparam block_num = CACHE_SIZE/BLOCK_SIZE;
    localparam set_num = CACHE_SIZE / NUM_WAYS;
    localparam index_width = $clog2(set_num);
    localparam offset_width = $clog2(BLOCK_SIZE);
    localparam tag_width = DATA_WIDTH - index_width - offset_width;

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
    reg[offset_width-1:0] byte_offset;
    reg[index_width-1:0] index;
    reg[tag_width-1:0] tag;

    //We need to give index, byte_offset and tag thier respective values
    assign tag = l1_cache_addr[DATA_WIDTH-1:index_width + offset_width];
    assign index = l1_cache_addr[DATA_WIDTH - tag_width - 1:offset_width];
    assign byte_offset = l1_cache_addr[offset_width-1:0]

    //L2 detection
    reg l2_hit;
    reg update;
    reg ii;
    
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
            l1_cache_hit <= 0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            mem_data_out <= 0;
            mem_addr <= 0;
        end 
        case(curr_state)
            IDLE: begin
                mem_read <= 0;
                mem_write <= 0;
                l1_cache_ready <= 0;
                l1_cache_hit <= 0;
                if(l1_cache_read || l1_cache_write)begin
                    next_state <= TAG_CHECK;
                end 
                else begin
                    next_state <= IDLE;
                end 
            end 
            TAG_CHECK: begin
                l2_cache_hit <= 0;
                for(ii = 0; ii < NUM_WAYS; ii = ii + 1)begin
                    if(VALIDS[index][i] && (TAGS[index][i] == tag))begin
                        l2_cache_hit <= 1;
                        




    
endmodule