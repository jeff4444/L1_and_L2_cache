iverilog -o run.vvp tb_l1_cache.v l1_cache.v memory.v
vvp run.vvp
jeff_wave tb_l1_cache.vcd --svg \
  -p tb_l1_cache/dut/clk \
     tb_l1_cache/dut/rst_n \
     tb_l1_cache/dut/cpu_addr \
     tb_l1_cache/dut/cpu_read \
     tb_l1_cache/dut/cpu_write \
     tb_l1_cache/dut/cpu_data_out \
     tb_l1_cache/dut/cpu_ready \
     tb_l1_cache/dut/l1_hit \
     tb_l1_cache/dut/l2_cache_addr \
     tb_l1_cache/dut/l2_cache_read \
     tb_l1_cache/dut/l2_cache_write \
     tb_l1_cache/dut/l2_cache_data_out