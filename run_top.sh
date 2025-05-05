#!/bin/bash
SEED=$RANDOM
PRETTY_PRINT_FLAG=0
TEMP_FLAG=0
NUM_WAYS=4 
IS_RANDOM=1

usage="Usage: $0 [-p] [-t] [-i] [-s seed] [-n num_ways] [no-log]"

while getopts "ptis:n:" opt; do
  case "$opt" in
    p) PRETTY_PRINT_FLAG=1 ;;
    t) TEMP_FLAG=1 ;;
    i) IS_RANDOM=0 ;;
    s) SEED="$OPTARG" ;;
    n) NUM_WAYS="$OPTARG" ;;
    *) echo "$usage"; exit 1 ;;
  esac
done
shift $((OPTIND -1))


DEFINES="-DNUM_WAYS=$NUM_WAYS"
if [ "$PRETTY_PRINT_FLAG" -eq 1 ]; then
  DEFINES="$DEFINES -DPRETTY_PRINT"
fi

if [ "$IS_RANDOM" -eq 1 ]; then
  DEFINES="$DEFINES -DRANDOM -DSEED=$SEED"
fi

echo "Testing with NUM_WAYS=$NUM_WAYS"
if [ "$IS_RANDOM" -eq 1 ]; then
  echo "SEED = $SEED"
else
  echo "Incremental Addresses"
fi

if [ "$TEMP_FLAG" -eq 1 ]; then
  echo "Using temp L2"
  iverilog $DEFINES -g2005-sv -o run.vvp tb_random.v l1_cache.v l2_cache_temp.v memory.v lfsr.v
else
  iverilog $DEFINES -g2005-sv -o run.vvp tb_random.v l1_cache.v l2_cache.v memory.v lfsr.v
fi

if [ "$1" = "no-log" ]; then
  vvp run.vvp
else
  echo "Writing to log file"
  if [ "$TEMP_FLAG" -eq 1 ]; then
    vvp run.vvp > run2.log
  else
    vvp run.vvp > run.log
  fi
fi

rm run.vvp
if [ "$TEMP_FLAG" -eq 1 ]; then
  python parse_data.py run2.log
else
  python parse_data.py run.log
fi