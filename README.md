# LMS-Based Adaptive Filter for Adaptive Noise Cancellation (ANC)

## Project Overview

This project implements an **Adaptive Noise Canceller (ANC)** filter using Verilog HDL. Two architectures are designed, simulated, and analyzed:

* **Normal (Original) Architecture**
* **Pipelined Architecture**

The designs are synthesized and implemented using **Xilinx Vivado**, and compared in terms of **area, timing, and power**.

---

## Objective

The main objective of this project is to:

* Design an ANC filter using Verilog
* Implement both normal and pipelined datapaths
* Perform synthesis and implementation in Vivado
* Compare hardware utilization, timing performance, and power consumption
* Analyze trade-offs between speed, area, and power

---

## Filter Description

An Adaptive Noise Canceller removes unwanted noise from a signal using an adaptive filtering technique.

### Key Components

* **Sample Shift Register** – stores input samples
* **FIR MAC Unit** – performs multiply-accumulate operation
* **Error Subtractor** – computes error signal
* **Coefficient Memory** – stores adaptive weights
* **LMS Update Unit** – updates coefficients dynamically

The pipelined version introduces additional registers to improve throughput and analyze timing-performance trade-offs.

---

## Source Files

### Normal Architecture

* `anc_datapath.v`
* `fir_mac_unit.v`
* `lms_update_unit.v`
* `coefficient_memory.v`
* `error_subtractor.v`
* `sample_shift_register.v`

### Pipelined Architecture

* `anc_datapath_pipelined.v`
* `fir_pipeline_unit.v`
* `lms_pipeline_update.v`

### Testbenches

* `tb_anc_datapath.v`
* `tb_anc_datapath_pipelined.v`

---

## Tools Used

* **Verilog HDL**
* **Xilinx Vivado**
* **FPGA synthesis and implementation tools**
* **Testbench-based simulation**

---

## Synthesis Results (20 ns Constraint)

| Parameter          | Normal Architecture | Pipelined Architecture |
| ------------------ | ------------------- | ---------------------- |
| LUTs               | 238                 | 327                    |
| Registers          | 363                 | 407                    |
| DSP Blocks         | 3                   | 9                      |
| Total Power        | 0.081 W             | 0.123 W                |
| Timing Slack (WNS) | +5.115 ns           | +0.379 ns              |

---

## Timing Analysis

* Both architectures were analyzed using a **20 ns clock constraint**
* Both designs successfully **met timing requirements**
* The normal architecture shows higher slack
* The pipelined design meets timing but with increased complexity

---

## Power Analysis

* Static power remains almost constant due to same FPGA device
* Pipelined architecture shows **higher dynamic power**
* Increased switching activity due to pipeline registers

---

## Key Observations

* Pipelining increases **register count and hardware usage**
* DSP utilization increased due to parallel operations
* Power consumption increased in pipelined design
* Timing improvement depends on **proper pipeline stage placement**

---

## Conclusion

This project demonstrates the implementation of an ANC filter using both normal and pipelined architectures. While the pipelined design increases hardware utilization and power consumption, it successfully meets timing requirements under practical constraints. However, the current implementation shows that effective pipelining requires balanced stage placement to achieve optimal performance.

---

## Future Improvements

* Optimize pipeline stage placement
* Reduce critical path in LMS update loop
* Improve power efficiency
* Explore higher clock frequency operation
