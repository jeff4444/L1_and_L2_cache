# L1 and L2 Cache Implementation

## Overview
This project implements a two-level cache hierarchy designed in Verilog, featuring a configurable L1 cache combined with a larger L2 cache. It provides a realistic cache model for CPU-memory interactions, supporting parameterized associativity, block size, and replacement policies. The goal is to simulate cache behavior and analyze performance metrics such as hit rate, miss latency, and throughput.

## Features
- **Configurable Parameters**: Data width, address width, cache size, block size, number of ways, and replacement policy (e.g., LRU).
- **Two-Level Hierarchy**: Fast L1 cache for low-latency access, backed by a larger L2 cache for higher capacity.
- **Miss Handling**: Automatic propagation of misses from L1 to L2, and from L2 to main memory via a memory module.
- **Verilog Testbenches**: Ready-to-run testbenches for functional verification of both L1 and L2 caches.
- **Waveform Dumping**: VCD output support for detailed timing analysis in waveform viewers (e.g., GTKWave).

## Architecture
```
CPU <--> L1 Cache <--> L2 Cache <--> Main Memory
```
- **L1 Cache**: Set-associative cache optimized for speed. Hits return data in one cycle.
- **L2 Cache**: Larger cache to reduce main memory accesses. Handles L1 misses with a configurable miss penalty.
- **Memory Module**: Simple synchronous memory initialized via a .mem file, used for cache fill operations.

## Getting Started
### Prerequisites
- Verilog simulator (e.g., Icarus Verilog, ModelSim)
- GNU Make (optional)
- GTKWave for waveform visualization (optional)

### Building and Simulation
1. **Compile the design and testbench**:
   ```bash
   iverilog -g2012 -o run.vvp tb_top.v l1_cache.v l2_cache.v memory.v
   ```

2. **Run the simulation**:
   ```bash
   vvp run.vvp
   ```

3. **View waveforms** (if enabled):
   ```bash
   gtkwave tb_top.vcd
   ```

## Directory Structure
```
├── README.md
├── l1_cache.v         # L1 cache implementation
├── l2_cache.v         # L2 cache implementation
├── memory.v           # Main memory model
├── tb_top.v           # Top-level testbench
└── memory_init.mem    # Memory initialization file
```

## Cache Design Details
### L1 Cache
- **Associativity**: Parameterized via `NUM_WAYS`.
- **Replacement Policy**: Least Recently Used (LRU) tracked per set.
- **Interface**:
  - `cpu_addr`, `cpu_data_in`, `cpu_data_out`, `cpu_read`, `cpu_write`, `cpu_ready`.

### L2 Cache
- **Larger Capacity**: Parameterized `CACHE_SIZE` and `NUM_WAYS`.
- **Interface**:
  - Connects to L1 (`l2_cache_read`, `l2_cache_write`, `l2_cache_addr`, etc.) and memory (`mem_addr`, `mem_data_out`, `mem_data_in`).

## Configuration Parameters
All parameters can be adjusted at module instantiation:
- `DATA_WIDTH` (default: 32)
- `ADDR_WIDTH` (default: 32)
- `CACHE_SIZE` (in bytes)
- `BLOCK_SIZE` (in words)
- `NUM_WAYS` (associativity)

## Contributing
Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a Pull Request.

## License
This project is released under the MIT License. See [LICENSE](LICENSE) for details.