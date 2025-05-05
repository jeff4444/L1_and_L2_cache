#!/bin/bash
SEED=$RANDOM
PRETTY_PRINT_FLAG=0

while getopts "ps:" opt; do
  case "$opt" in
    p) PRETTY_PRINT_FLAG=1 ;;
    s) SEED="$OPTARG" ;;
    *) echo "Usage: $0 [-p] [-s seed] [no-log]"; exit 1 ;;
  esac
done
shift $((OPTIND -1))


DEFINES="-DSEED=$SEED"
if [ "$PRETTY_PRINT_FLAG" -eq 1 ]; then
  DEFINES="$DEFINES -DPRETTY_PRINT"
fi

iverilog $DEFINES -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v lfsr.v

if [ "$1" = "no-log" ]; then
  vvp run.vvp
else
  echo "Writing to log file"
  vvp run.vvp > run.log
fi

rm run.vvp
echo "Running Python script to parse data"
python parse_data.py run.log