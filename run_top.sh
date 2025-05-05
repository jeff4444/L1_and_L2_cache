if [ "$2" == "-p" ]; then
  iverilog -DPRETTY_PRINT -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v lfsr.v
else
  iverilog -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v lfsr.v
fi

if [ "$1" = "log" ]; then
  echo "Writing to log file"
  vvp run.vvp > run.log
else
  vvp run.vvp
fi
rm run.vvp
echo "Running Python script to parse data"
python parse_data.py run.log