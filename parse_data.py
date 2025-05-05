#!/usr/bin/env python3

import argparse
import re

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
            events.append((t, rest))

    # Count L1/L2 hits and misses
    l1_hits = l1_misses = l2_hits = l2_misses = 0
    for _, rest in events:
        if rest.startswith('[L1]'):
            msg = rest.split(']', 1)[1].strip()
            if msg.startswith('Cache hit'):
                l1_hits += 1
            elif msg.startswith('Cache miss'):
                l1_misses += 1
        elif rest.startswith('[L2]'):
            msg = rest.split(']', 1)[1].strip()
            if msg.startswith('Cache hit'):
                l2_hits += 1
            elif msg.startswith('Cache miss'):
                l2_misses += 1

    # Compute per-access latencies based on timestamp differences
    latencies = []
    for idx, (t_req, rest) in enumerate(events):
        if rest.startswith('[TEST]') and 'CPU read' in rest:
            m = re.search(r'@0x([0-9A-Fa-f]+)', rest)
            if not m:
                continue
            addr = m.group(1).lower()
            # Find the corresponding L1 service completion
            for t_serv, rest2 in events[idx+1:]:
                if rest2.startswith('[L1]'):
                    msg2 = rest2.split(']', 1)[1].strip()
                    if (msg2.startswith('Cache hit') or msg2.startswith('Cache hit from L2')):
                        m2 = re.search(r'addr\s*=\s*([0-9A-Fa-f]+)', msg2)
                        if m2 and m2.group(1).lower() == addr:
                            latencies.append(t_serv - t_req)
                            break

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
        amat = sum(latencies) / len(latencies)
        print(f'Average Memory Access Time (AMAT): {amat:.2f} cycles (from timestamps)')
    else:
        print('No completed CPU accesses found to compute AMAT.')
    
if __name__ == '__main__':
    main()