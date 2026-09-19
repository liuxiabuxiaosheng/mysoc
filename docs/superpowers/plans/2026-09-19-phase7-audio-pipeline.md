# Phase 7 Audio Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect BRAM, DMA, asynchronous FIFOs, and the fixed-point FIR into a CPU-configurable audio processing path and verify the returned samples against a software model.

**Architecture:** Add an APB audio control block at `0x4000_3000`, extend DMA with explicit 16-bit FIFO endpoint handshakes, and add an audio-clock-domain wrapper containing input FIFO, FIR, and output FIFO. `soc_top` keeps CPU/APB/RAM behavior and supplies the system and audio clock/reset ports needed by the integration test.

**Tech Stack:** SystemVerilog 2012, Icarus Verilog 13.0, VVP, PowerShell.

## Global Constraints

- Audio control window is `0x4000_3000–0x4000_3FFF`.
- Samples and coefficients are signed 16-bit Q1.15 values.
- BRAM-to-audio transfers use even sample counts and 32-bit word packing.
- Input/output streams cross clock domains only through `async_fifo`.
- FIFO backpressure stalls DMA without dropping a sample.
- Existing CPU, DMA, Async FIFO, FIR, and APB regression tests remain passing.

---

### Task 1: Audio control/status peripheral

**Files:**
- Create: `rtl/peripheral/audio/audio_ctrl.sv`
- Modify: `rtl/bus/apb_interconnect.sv`
- Modify: `rtl/top/apb_subsystem.sv`
- Create: `tb/peripheral/tb_audio_ctrl.sv`
- Modify: `sim/run_tests.ps1`

- [ ] Test APB register reads/writes, coefficient programming, enable/bypass, sample count, and RW1C status clearing.
- [ ] Run the focused test and observe the missing-module failure.
- [ ] Implement the register bank and FIR configuration outputs with a stable APB ready/error response.
- [ ] Verify `PASS tb_audio_ctrl` and commit `feat: add audio control peripheral`.

### Task 2: DMA audio FIFO endpoints

**Files:**
- Modify: `rtl/dma/dma_controller.sv`
- Modify: `rtl/top/apb_subsystem.sv`
- Create: `tb/dma/tb_dma_audio_endpoints.sv`
- Modify: `sim/run_tests.ps1`

- [ ] Add endpoint address parameters for input/output sample streams and 16-bit ready/valid handshakes.
- [ ] Test BRAM-to-input-FIFO packing, output-FIFO-to-BRAM packing, endpoint backpressure, and endpoint errors.
- [ ] Preserve the existing BRAM-to-BRAM path and register map.
- [ ] Verify `PASS tb_dma_audio_endpoints` and commit `feat: add dma audio endpoints`.

### Task 3: Audio pipeline wrapper and SoC wiring

**Files:**
- Create: `rtl/audio/audio_pipeline.sv`
- Modify: `rtl/top/soc_top.sv`
- Create: `tb/top/tb_soc_audio.sv`
- Modify: `sim/run_tests.ps1`

- [ ] Instantiate input/output `async_fifo` and `fir_filter` in the audio clock domain.
- [ ] Connect audio control, coefficient, status, and sample-count signals.
- [ ] Add system/audio clock and reset ports while preserving the existing default top-level behavior.
- [ ] Write an end-to-end test that seeds BRAM, configures coefficients, runs both DMA directions, and checks every output sample against the Q1.15 model.
- [ ] Verify `PASS tb_soc_audio` and commit `feat: integrate audio dma fifo fir pipeline`.

### Task 4: Regression and evidence

**Files:**
- Create: `docs/verification/phase7-audio-pipeline.md`
- Modify: `FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md`
- Modify: `docs/FPGA_RISC_V_Audio_SoC_Implementation_Roadmap.md`

- [ ] Run focused audio tests, full `sim/run_tests.ps1 -Test all`, and null elaboration for `apb_subsystem` and `soc_top`.
- [ ] Record exact commands, sample packing, backpressure, status/error coverage, and non-goals.
- [ ] Mark the integrated audio path as implemented while keeping physical audio, FFT, display, and AI outside scope.
- [ ] Commit `docs: record phase-seven audio pipeline verification`.
