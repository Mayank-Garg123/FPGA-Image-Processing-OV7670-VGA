# FPGA Image Processing using OV7670 and VGA on ZedBoard

## Overview
This project implements a real-time image processing pipeline on FPGA using the OV7670 camera and VGA display on the ZedBoard. The system captures live video, processes it using multiple convolution-based operations, and displays the output on a VGA monitor.

## Features
- OV7670 camera interface (SCCB + pixel capture)
- Clock-domain crossing using AXI-stream FIFO
- Multi-opcode convolution engine
- VGA controller (640×480 @ 60Hz)
- Fully hardware-accelerated image processing

## Hardware Platform
- ZedBoard
- OV7670 Camera Module
- VGA Monitor

## Toolchain
- Vivado 2022.2
- Verilog HDL

## Project Architecture
1. Camera Capture (OV7670)
2. FIFO Buffer (Clock Domain Crossing)
3. Image Processing Engine
4. VGA Display Pipeline

## Results
- Real-time processing at VGA resolution
- Total on-chip power ≈ 0.205 W
- Deterministic latency with no CPU involvement

## Future Improvements
- AXI4 interface for PS–PL control
- HDMI output
- Line-buffer optimization using BRAM
- Support for higher resolutions

## Author
Mayank Garg
