# Phase 5 Async FIFO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement and verify a parameterized asynchronous FIFO for safe multi-bit CDC between unrelated clocks.

**Architecture:** `async_fifo` stores data in a dual-clock memory array, maintains binary and Gray pointers locally, and synchronizes only Gray pointers through two-flop chains. Full, empty, overflow, and underflow are generated in their respective domains.

**Tech Stack:** SystemVerilog 2012, Icarus Verilog 13.0, VVP, PowerShell.

## Global Constraints

- Default data width is 16 bits and default depth is 16 entries.
- `ADDR_WIDTH` must describe a power-of-two depth.
- Write and read clocks/resets are independent active-low domains.
- Multi-bit data crosses only through the dual-clock memory array and local read/write enables.
- Full/empty flags use synchronized Gray pointers; no unsynchronized binary pointer is used in flag logic.
- Existing DMA and all prior regression tests must remain passing.

---

### Task 1: Write the failing Async FIFO test

**Files:**
- Create: `tb/cdc/tb_async_fifo.sv`
- Modify: `sim/run_tests.ps1`

- [x] Add unrelated write/read clocks, ordered writes/reads, full/empty checks, wraparound, overflow/underflow, and reset scenarios.
- [x] Register the test as `async_fifo` in the runner.
- [x] Run `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test async_fifo` and observe the expected missing-module compile failure.

### Task 2: Implement Gray-pointer Async FIFO

**Files:**
- Create: `rtl/cdc/async_fifo.sv`

- [x] Implement local binary/Gray pointers and two-flop pointer synchronizers.
- [x] Implement full/empty next-state comparisons using synchronized Gray pointers.
- [x] Implement dual-clock memory access, sticky overflow/underflow, and independent resets.
- [x] Run the focused test and verify `PASS tb_async_fifo`.
- [x] Commit `feat: add async fifo cdc primitive`.

### Task 3: Regression and verification record

**Files:**
- Create: `docs/verification/phase5-async-fifo.md`
- Modify: `FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md`
- Modify: `docs/FPGA_RISC_V_Audio_SoC_Implementation_Roadmap.md`

- [x] Run the focused test, full `sim/run_tests.ps1 -Test all`, and `iverilog -g2012 -Wall -tnull -s soc_top`.
- [x] Record exact commands, pass results, CDC coverage, and remaining non-goals.
- [x] Mark CDC/Async FIFO as implemented while keeping audio/FIR integration explicitly pending.
- [x] Commit `docs: record phase-five async fifo verification`.
