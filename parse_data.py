#!/usr/bin/env python3

import argparse
import re
import sys
def parse_log(file_path):
    events = []
    with open(file_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(' ', 1)
            if len(parts) != 2:
                continue
            time_str, rest = parts
            try:
                t = int(time_str)
            except ValueError:
                continue
            if rest.startswith('[TEST]'):
                addr_match = re.search(r'@0x([0-9A-Fa-f]+)', rest)
                if not addr_match:
                    continue
                module = 'TEST'
                keyword = 'read'
            elif rest.startswith('[L1]'):
                addr_match = re.search(r'addr\s*=\s*0x([0-9A-Fa-f]+)', rest)
                module = 'L1'
                keyword = re.search(r'Cache (hit|miss|Allocate)', rest)
                keyword = keyword.group(1) if keyword else None
            elif rest.startswith('[L2]'):
                addr_match = re.search(r'addr\s*=\s*0x([0-9A-Fa-f]+)', rest)
                module = 'L2'
                keyword = re.search(r'Cache (hit|miss|Allocate)', rest)
                keyword = keyword.group(1) if keyword else None
            elif rest.startswith('[MEM]'):
                addr_match = re.search(r'addr\s*=\s*0x([0-9A-Fa-f]+)', rest)
                module = 'MEM'
                keyword = re.search(r'Mem (hit|miss|Allocate)', rest)
                keyword = keyword.group(1) if keyword else None
            events.append((t, module, keyword, addr_match.group(1).lower() if addr_match else None))

    # Count L1/L2 hits and misses
    l1_hits = l1_misses = l2_hits = l2_misses = 0
    for i, (t, module, keyword, _) in enumerate(events):
        if module == 'L1':
            if keyword == 'hit':
                if i > 0 and events[i-1][1] == 'L1' and events[i-1][2] == 'Allocate':
                    # This is just a cache allocation, not a hit
                    continue
                l1_hits += 1
            elif keyword == 'miss':
                l1_misses += 1
        elif module == 'L2':
            if keyword == 'hit':
                l2_hits += 1
            elif keyword == 'miss':
                l2_misses += 1

    # Compute per-access latencies based on timestamp differences
    latencies = []
    cur_addr = None
    start_time = None
    for i, (t, module, keyword, addr) in enumerate(events):
        if cur_addr is None:
            if module == 'TEST':
                cur_addr = addr
                start_time = t
        elif module == 'L1' and keyword == 'hit':
            if addr == cur_addr:
                # This is a hit for the current address
                latencies.append(t - start_time)
                cur_addr = None
                start_time = None

    return l1_hits, l1_misses, l2_hits, l2_misses, latencies

def main():
    parser = argparse.ArgumentParser(description='Parse cache log and compute hit/miss ratios and AMAT from timestamps.')
    parser.add_argument('logfile', help='Path to the log file')
    args = parser.parse_args()

    l1_hits, l1_misses, l2_hits, l2_misses, latencies = parse_log(args.logfile)
    l1_accesses = l1_hits + l1_misses
    l2_accesses = l2_hits + l2_misses
    l1_hit_rate = l1_hits / l1_accesses if l1_accesses else 0.0
    l2_hit_rate = l2_hits / l2_accesses if l2_accesses else 0.0

    print(f'L1 accesses: {l1_accesses}, hits: {l1_hits}, misses: {l1_misses}, hit rate: {l1_hit_rate:.2%}')
    print(f'L2 accesses: {l2_accesses}, hits: {l2_hits}, misses: {l2_misses}, hit rate: {l2_hit_rate:.2%}')
    
    if latencies:
        avg_latency = sum(latencies) / len(latencies)
        avg_latency_cycles = avg_latency / 10  # Convert to cycles
        print(f'Average Memory Access Time: {avg_latency_cycles:.2f} cycles')
    else:
        print('No L1 hits found for latency calculation.')
    
if __name__ == '__main__':
    main()