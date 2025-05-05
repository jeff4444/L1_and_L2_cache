if [ "$2" == "-p" ]; then
  iverilog -DPRETTY_PRINT -o run.vvp tb_top.v l1_cache.v l2_cache_temp.v memory.v
else
  iverilog -o run.vvp tb_top.v l1_cache.v l2_cache_temp.v memory.v
fi

if [ "$1" = "log" ]; then
  echo "Writing to log file"
  vvp run.vvp > run.log
else
  vvp run.vvp
fi
# jeff_wave tb_top.vcd --svg \
#   -p tb_top/dut/clk \
#      tb_top/dut/rst_n \
#      tb_top/dut/cpu_addr \
#      tb_top/dut/cpu_read \
#      tb_top/dut/cpu_write \
#      tb_top/dut/cpu_data_out \
#      tb_top/dut/cpu_ready \
#      tb_top/dut/l1_hit \
#      tb_top/dut/l2_cache_addr \
#      tb_top/dut/l2_cache_read \
#      tb_top/dut/l2_cache_write \
#      tb_top/dut/l2_cache_data_out \
#      tb_top/dut/l2_cache_data_in \
#      tb_top/dut/l2_cache_ready \
#      tb_top/dut/l2_cache_hit