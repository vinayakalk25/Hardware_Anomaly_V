# Hardware Anomaly Detector

A systolic array neural network pipeline for V2X (Vehicle-to-Everything) cyber attack detection, designed for the Tiny Tapeout 130nm ASIC shuttle.

## How it works

This custom silicon architecture acts as an inline hardware firewall. It ingests serial data streams, reconstructs them into parallel packets, and runs a mathematical threat-scoring algorithm using a hardcoded neural network (Systolic Array) to detect malicious payloads in real-time.

**The Pipeline:**
1. **SIPO Ingestion (`u_input`):** Captures 64 bits of serial data and reconstructs the packet.
2. **Feature Extraction (`u_extractor`):** Slices out targeted data nodes (e.g., spatial coordinates or CAN bus identifiers).
3. **Systolic Array Core (`u_core`):** Performs Two's Complement Multiply-Accumulate (MAC) operations, multiplying the extracted data against hardcoded neural network weights (12 and 88).
4. **Threat Scoring (`u_scoring`):** Evaluates the MAC output. If the calculated score exceeds the hardcoded safety threshold (`1500`), it trips the physical hardware alarm.

## How to test

The chip evaluates a 64-bit payload injected serially via the `ui_in` pins. 

* **Test 1 (Safe Payload):** Inject `0xAA00123400001122`. The hardware extracts the middle coordinates (`0000`), calculates a threat score of `0`, and keeps the `irq` alarm pin at `0`.
* **Test 2 (Malicious Cyber Attack):** Inject `0x00000000FEFE0000`. The hardware extracts `FEFE` (which represents massive positive logic in reverse-wiring), calculates a threat score vastly exceeding the `1500` threshold, and immediately spikes the `irq` alarm pin to `1`.

## External hardware

No external hardware is strictly required to run this chip. It can be fully driven and monitored using the built-in RP2040 microcontroller on the Tiny Tapeout demo board.
EOF