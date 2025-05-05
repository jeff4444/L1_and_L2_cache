if [ "$2" == "-p" ]; then
  iverilog -DPRETTY_PRINT -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v
else
  iverilog -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v
fi

if [ "$1" = "log" ]; then
  echo "Writing to log file"
  vvp run.vvp > run.log
else
  vvp run.vvp
fi
echo "Running Python script to parse data"
python parse_data.py run.log