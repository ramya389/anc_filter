# anc_filter
Verilog implementation of Adaptive Noise Canceller (ANC) filter with normal and pipelined architectures, analyzed using Vivado for area, timing, and power.
# Adaptive Noise Canceller (ANC) Filter in Verilog

## Project Overview
This project implements an Adaptive Noise Canceller (ANC) filter using Verilog HDL. Two architectures were developed and analyzed:

1. Original ANC architecture
2. Pipelined ANC architecture

The project includes simulation, synthesis, timing analysis, power analysis, and area comparison using Xilinx Vivado.

---

## Objective
The objective of this project is to design and compare a normal ANC datapath and a pipelined ANC datapath in terms of:

- Functional correctness
- Timing performance
- Hardware utilization
- Power consumption

---

## Filter Description
The ANC filter removes unwanted noise from a desired signal by using an adaptive filtering approach. The design uses FIR-based filtering and LMS-based coefficient updating.

### Main blocks used
- Sample shift register
- FIR MAC unit
- Error subtractor
- Coefficient memory
- LMS update unit

The pipelined version introduces additional stages to improve throughput and analyze timing-performance trade-offs.
