# Hardware-Assisted V2X Anomaly Detection Engine

[![gds](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/gds.yaml/badge.svg)](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/gds.yaml)
[![docs](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/docs.yaml/badge.svg)](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/docs.yaml)
[![test](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/test.yaml/badge.svg)](https://github.com/vinayakalk25/Hardware_Anomaly_V/actions/workflows/test.yaml)

## Overview
This repository contains the RTL (Register-Transfer Level) design for a custom Application-Specific Integrated Circuit (ASIC) targeting the SkyWater 130nm process via the Tiny Tapeout framework.

The chip operates as a **Pipelined Systolic Neural Network Core** designed to track and intercept real-time cybersecurity threat vectors in Vehicle-to-Everything (V2X) communication streams.

## Hardware Architecture
The anomaly detection engine is fully parallelized and executes across a rigid 6-layer pipeline:

1. **SIPO Ingestion (Layer 1):** Captures incoming serial telemetry bits and constructs stable 64-bit parallel packets.
2. **Feature Extractor (Layer 2):** Performs spatial slicing to isolate critical coordinates (e.g., node positioning, velocity vectors) while preserving signed configurations.
3. **AXI4-Stream DMA (Layer 3):** Manages flow control and handshake protocols (`tvalid`/`tready`) to prevent execution node override.
4. **Systolic Array Core (Layer 4):** A 2x2 hardware multiplier-accumulator (MAC) matrix applying hardcoded network weights and a hardware-level ReLU activation function.
5. **Threat Evaluator (Layer 5):** A digital magnitude comparator that evaluates computed results against preset safety thresholds.
6. **Output Endpoints (Layer 6):** Drives a parallel threat severity bus and triggers an instant physical hardware Interrupt Request (IRQ) upon detecting critical attack vectors.

## Testing & Verification
The chip logic is verified using `cocotb` and Icarus Verilog. The testbench simulates 50MHz real-time data injection.

To run the verification suite locally:
```bash
cd test
make clean
make