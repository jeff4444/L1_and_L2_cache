#!/usr/bin/env python3
import re
import argparse
import pandas as pd
import matplotlib.pyplot as plt

def parse_log(file_path):
    pat_num_ways = re.compile(r"=== NUM_WAYS = (\d+) ===")
    pat_seed = re.compile(r"SEED\s*=\s*(\d+)")
    pat_l1 = re.compile(r"L1 accesses:.*?hit rate:\s*([\d.]+)%")
    pat_l2 = re.compile(r"L2 accesses:.*?hit rate:\s*([\d.]+)%")
    pat_amat = re.compile(r"Average Memory Access Time:\s*([\d.]+)\s*cycles")

    records = []
    num_ways = test = None
    l1 = l2 = amat = None

    with open(file_path) as f:
        for line in f:
            line = line.strip()
            if m := pat_num_ways.match(line):
                num_ways = int(m.group(1))
                continue
            if m := pat_seed.match(line):
                test = f"seed_{m.group(1)}"
                continue
            if line == "Incremental Addresses":
                test = "incremental"
                continue
            if m := pat_l1.match(line):
                l1 = float(m.group(1))
                continue
            if m := pat_l2.match(line):
                l2 = float(m.group(1))
                continue
            if m := pat_amat.match(line):
                amat = float(m.group(1))
                records.append({
                    "num_ways": num_ways,
                    "test": test,
                    "amat": amat,
                    "l1_hit_rate": l1,
                    "l2_hit_rate": l2
                })

    return pd.DataFrame(records)

def plot_separate(df):
    tests = df['test'].unique()

    # 1) AMAT plot
    plt.figure(figsize=(6,4))
    for test in tests:
        sub = df[df['test']==test]
        plt.plot(sub['num_ways'], sub['amat'], marker='o', linewidth=2, label=test)
    plt.xlabel("NUM_WAYS")
    plt.ylabel("AMAT (cycles)")
    plt.title("Average Memory Access Time vs NUM_WAYS")
    plt.grid(True)
    plt.legend(title="Test")
    plt.tight_layout()

    # 2) L1 Hit Rate plot
    plt.figure(figsize=(6,4))
    for test in tests:
        sub = df[df['test']==test]
        plt.plot(sub['num_ways'], sub['l1_hit_rate'], marker='s', linestyle='--', linewidth=1.5, label=test)
    plt.xlabel("NUM_WAYS")
    plt.ylabel("L1 Hit Rate (%)")
    plt.title("L1 Hit Rate vs NUM_WAYS")
    plt.grid(True)
    plt.legend(title="Test")
    plt.tight_layout()

    # 3) L2 Hit Rate plot
    plt.figure(figsize=(6,4))
    for test in tests:
        sub = df[df['test']==test]
        plt.plot(sub['num_ways'], sub['l2_hit_rate'], marker='^', linestyle=':', linewidth=1.5, label=test)
    plt.xlabel("NUM_WAYS")
    plt.ylabel("L2 Hit Rate (%)")
    plt.title("L2 Hit Rate vs NUM_WAYS")
    plt.grid(True)
    plt.legend(title="Test")
    plt.tight_layout()

    plt.show()

def main():
    p = argparse.ArgumentParser(
        description="Parse cache log and plot separate figures for AMAT, L1 and L2 hit rates."
    )
    p.add_argument("logfile", help="Path to your cache log file")
    args = p.parse_args()

    df = parse_log(args.logfile)
    print("\nParsed data:\n", df, "\n")
    plot_separate(df)

if __name__=="__main__":
    main()