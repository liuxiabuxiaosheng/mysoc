# FPGA RISC-V Audio SoC MVP Design

## 1. Purpose

This specification defines a learning-oriented FPGA SoC implemented in the PL fabric of an ALINX AX7010 Zynq-7000 board. The project demonstrates the complete front-end flow from architecture and RTL design through simulation, synthesis, timing analysis, and technical documentation.

The core deliverable is a simulation-verified SoC containing a self-designed RV32I processor, on-chip memory, APB peripherals, DMA, clock-domain crossing, and a fixed-point FIR audio-processing path. Physical audio input/output, VGA, FFT, and machine-learning inference are explicitly outside the MVP implementation scope.

Project documentation and interview descriptions must distinguish among implemented RTL, simulation-verified behavior, synthesis results, architectural designs, and future extensions. Unimplemented features must not be described as completed.

## 2. Target Platform and Tools

- Board: ALINX AX7010.
- FPGA family: Xilinx Zynq-7000.
- Device: XC7Z010CLG400-1.
- Processing System: not used for core SoC functionality.
- CPU: self-designed RV32I processor implemented entirely in PL.
- RTL language: SystemVerilog.
- Primary simulator: Icarus Verilog with SystemVerilog 2012 enabled.
- FPGA flow: Xilinx Vivado.
- Firmware toolchain: RISC-V bare-metal GCC or an equivalent RV32I-capable compiler and binutils toolchain.

## 3. MVP Scope

### 3.1 Required implementation

- Multi-cycle RV32I CPU.
- 64 KiB on-chip BRAM containing program, data, and digital audio samples.
- CPU memory bus and address decoder.
- APB bridge and APB peripheral interconnect.
- GPIO, timer, and UART peripherals.
- Single-channel DMA controller.
- Asynchronous FIFO between system and audio clock domains.
- Sixteen-tap signed fixed-point FIR filter.
- Audio control/status register block.
- Unit-level and SoC-level self-checking testbenches.
- Automated simulation regression.
- Vivado synthesis, resource, and timing reports for the AX7010 target.

### 3.2 Documented extensions, not MVP deliverables

- FFT accelerator.
- VGA or TFT display engine.
- I2S, PDM, ADC, DAC, or external audio codec integration.
- Machine-learning inference or keyword spotting.
- Processor pipeline, caches, branch prediction, or multiplication/division extensions.
- Full RISC-V privileged architecture and complete exception/interrupt handling.

## 4. System Architecture

```text
                    Self-designed multi-cycle RV32I
                                  |
                           CPU memory bus
                                  |
                           Address decoder
                         /                 \
                Memory-port arbiter        APB bridge
                    /         \                 |
             CPU requests   DMA requests   APB peripheral bus
                    \         /                 |
                   64 KiB BRAM       GPIO / timer / UART / DMA
                                              / audio control

     BRAM sample area <-> DMA <-> asynchronous FIFO <-> 16-tap FIR
                            100 MHz domain       12.5 MHz domain
```

The CPU uses a simple request/response memory interface. BRAM accesses pass through a memory-port arbiter. Peripheral accesses are converted into APB setup and access phases. DMA is configured through APB and acts as a BRAM-side master when transferring sample data. The arbiter grants an already active transaction until completion and otherwise gives CPU requests priority; the multi-cycle CPU leaves request-free cycles in which DMA progresses.

The digital audio flow uses signed 16-bit samples. Input samples are stored in BRAM, transferred through DMA into an asynchronous input FIFO, processed by the FIR block in the audio clock domain, and returned through an output FIFO for DMA storage and comparison. DMA uses dedicated FIFO ready/valid handshakes rather than becoming a second APB master. No physical audio pins are required for MVP acceptance.

## 5. Clock and Reset Architecture

- The AX7010 PL oscillator input is 50 MHz.
- Vivado Clocking Wizard generates the 100 MHz system clock.
- The learning and synthesis configuration uses a 12.5 MHz audio clock derived from the clocking resources.
- A future real 48 kHz I2S interface may replace the demonstration audio clock with 12.288 MHz.
- Each clock domain has an asynchronous-assert, synchronous-deassert reset synchronizer.
- Multi-bit streaming data crosses clock domains only through asynchronous FIFOs.
- Single-bit control/status crossings use explicit synchronizers or handshake logic.
- Vivado constraints must define generated clocks and asynchronous clock groups.

## 6. CPU Design

The first CPU implementation is a multi-cycle RV32I core with fetch, decode, execute, memory, and write-back states. It supports the RV32I base integer instruction set needed by the project firmware, including arithmetic, logical, shift, branch, jump, load, store, and upper-immediate instructions.

The CPU does not contain a cache, pipeline, branch predictor, multiplier, or divider. Program and data share the same logical address space. The reset vector is `0x0000_0000`.

Illegal instructions and misaligned instruction or data accesses set a visible fault code and halt the CPU. Full traps and machine-mode CSRs are deferred. Timer and UART are polled by MVP firmware; interrupt support is an extension.

The CPU exposes sufficient debug status for simulation: current PC, current state, halt flag, and fault code.

## 7. Bus and Memory Architecture

### 7.1 CPU memory interface

The CPU bus contains:

- 32-bit address.
- 32-bit write data.
- 4-bit byte write strobes.
- Read/write request.
- Read data.
- Ready response.
- Error response.

Only one CPU request may be outstanding. A request remains stable until ready or error is returned.

### 7.2 Memory

The address range `0x0000_0000` through `0x0000_FFFF` maps to 64 KiB BRAM. The memory supports byte write enables and initialization from a generated hexadecimal image. CPU and DMA requests share one logical BRAM port through the memory arbiter. Concurrent CPU and DMA requests are stalled until granted, so inferred-memory collision behavior is not exposed to the requesters.

### 7.3 APB

APB is used only for low-bandwidth control and status registers. The bridge implements the APB setup and access phases and holds address, direction, and write data stable throughout a transfer. Unmapped addresses and unsupported register offsets complete with `PSLVERR` asserted.

## 8. Address Map

| Address range | Module | MVP status |
| --- | --- | --- |
| `0x0000_0000`-`0x0000_FFFF` | 64 KiB BRAM | MVP required |
| `0x4000_0000`-`0x4000_0FFF` | GPIO | MVP required |
| `0x4000_1000`-`0x4000_1FFF` | Timer | MVP required |
| `0x4000_2000`-`0x4000_2FFF` | UART | MVP required |
| `0x4000_3000`-`0x4000_3FFF` | Audio/FIR control | MVP required |
| `0x4000_4000`-`0x4000_4FFF` | Display control | Reserved only |
| `0x4000_5000`-`0x4000_5FFF` | DMA | MVP required |

All registers are 32-bit and aligned to four-byte boundaries.

## 9. Peripheral Register Interfaces

### 9.1 GPIO

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `GPIO_DATA` | RW | Output data |
| `0x04` | `GPIO_DIR` | RW | Direction, one means output |
| `0x08` | `GPIO_INPUT` | RO | Synchronized input data |

### 9.2 Timer

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `TIMER_CTRL` | RW | Bit 0 enable, bit 1 periodic mode |
| `0x04` | `TIMER_COUNT` | RO | Current counter value |
| `0x08` | `TIMER_COMPARE` | RW | Terminal count |
| `0x0C` | `TIMER_STATUS` | RW1C | Bit 0 expiry flag |

The expiry flag is sticky until software writes one to clear it. MVP firmware polls this flag.

### 9.3 UART

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `UART_DATA` | RW | TX write or RX read data |
| `0x04` | `UART_STATUS` | RO | TX/RX empty/full and error flags |
| `0x08` | `UART_CTRL` | RW | TX/RX enable and sticky error clear controls |
| `0x0C` | `UART_BAUD` | RW | System-clock cycles per serial bit |

The baud divider width is derived from its configured maximum and is not fixed to nine bits. The default simulation setting is computed from the 100 MHz system clock and 115200 baud. For safe TX and mid-bit RX timing, register writes and the TX/RX primitives clamp divider values below 8 to 8.

### 9.4 DMA

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `DMA_SRC` | RW | Source byte address |
| `0x04` | `DMA_DST` | RW | Destination byte address |
| `0x08` | `DMA_LENGTH` | RW | Number of 32-bit words |
| `0x0C` | `DMA_CTRL` | RW | Bit 0 start |
| `0x10` | `DMA_STATUS` | RW1C | Busy, done, alignment, and configuration error flags |

DMA rejects zero-length transfers, unaligned addresses, and a new start request while busy. Done and error indications remain set until cleared.

### 9.5 Audio/FIR

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `AUDIO_CTRL` | RW | Enable, bypass, and state-clear controls |
| `0x04` | `AUDIO_STATUS` | RW1C | FIFO and processing status/error flags |
| `0x08` | `AUDIO_DATA_IN` | WO | Signed 16-bit input sample |
| `0x0C` | `AUDIO_DATA_OUT` | RO | Signed 16-bit output sample |
| `0x10` | `AUDIO_COEFF_INDEX` | RW | FIR coefficient index 0 through 15 |
| `0x14` | `AUDIO_COEFF_DATA` | RW | Signed Q1.15 coefficient |
| `0x18` | `AUDIO_SAMPLE_COUNT` | RO | Number of completed output samples |

The audio status register records FIFO overflow and underflow as sticky flags. Software or the DMA path uses the data registers as peripheral endpoints.

## 10. DMA and Audio Data Flow

The DMA controller implements one read followed by one write for each word and supports a single outstanding operation. Its FSM contains idle, read request, read wait, write request, write wait, and completion states.

The MVP transfer modes are:

- BRAM-to-BRAM for standalone DMA verification.
- BRAM-to-audio input register for sample injection.
- Audio output register-to-BRAM for processed sample capture.

For audio transfers, the programmed audio register addresses select dedicated FIFO endpoints inside the DMA address decoder. Data movement then uses direct valid/ready handshakes with the audio input and output FIFOs; DMA does not arbitrate for the CPU APB bus.

The asynchronous FIFO uses Gray-coded read and write pointers, two-flop pointer synchronization, and full/empty detection in the local clock domains. Parameterized depth must be a power of two. Simulation verifies wraparound and independently varying clock phases.

The FIR accepts one signed 16-bit Q1.15 sample at a time, stores the most recent sixteen samples, multiplies them by sixteen signed Q1.15 coefficients, accumulates at extended precision, rounds or truncates at one explicitly documented bit position, and saturates the result to signed 16-bit range.

## 11. Error Handling

- CPU illegal instruction: halt and record an illegal-instruction fault code.
- CPU misaligned access: halt and record a misalignment fault code.
- Unmapped bus address: return an error response.
- Invalid APB register offset: assert `PSLVERR`.
- DMA configuration error: do not begin transfer; set the corresponding sticky status bit.
- FIFO overflow or underflow: preserve data-path state where possible and set a sticky status bit.
- FIR arithmetic overflow: saturate to `0x7FFF` or `0x8000` instead of wrapping.
- Reset during an operation: return every block to a defined idle state and discard the incomplete transaction.

## 12. Verification Strategy

Verification is performed continuously rather than as a final project phase.

### 12.1 Unit tests

- ALU operations and comparison behavior.
- Immediate decoding for every RV32I immediate format.
- Register file reset and x0 behavior.
- CPU execution of each supported instruction class.
- APB bridge setup/access timing, wait states, and error response.
- GPIO reads and writes.
- Timer enable, compare, periodic behavior, and sticky status clearing.
- UART TX waveform, RX sampling, FIFO full/empty, and loopback.
- DMA copy, boundary conditions, and configuration errors.
- Asynchronous FIFO ordering, wraparound, full, empty, overflow, and underflow.
- FIR impulse, step, negative values, maximum values, and saturation.

### 12.2 Integration tests

- CPU boots a BRAM image and writes a known GPIO pattern.
- CPU polls the timer and observes an expiry.
- CPU transmits a fixed string through UART; the testbench decodes and checks it.
- CPU configures DMA for a BRAM-to-BRAM transfer and verifies the destination.
- CPU configures the audio path, loads FIR coefficients, processes a sample block, and verifies output memory.

### 12.3 Golden reference

A small deterministic software model generates expected FIR outputs from the same signed samples and coefficients used by the RTL test. RTL results must match the model exactly after applying the documented fixed-point rounding and saturation rules.

### 12.4 Regression criteria

- Every test is self-checking and returns a nonzero process status on failure.
- One command runs all unit and integration tests.
- Waveforms are optional debugging artifacts, not the pass/fail mechanism.
- No test depends on manual waveform inspection.

## 13. Synthesis and Timing Acceptance

- Vivado synthesis targets XC7Z010CLG400-1.
- The 100 MHz system clock constraint must meet timing with nonnegative worst slack.
- Generated clocks and asynchronous clock groups are explicitly constrained.
- There are no inferred latches, multiple drivers, combinational loops, or unconstrained primary clocks.
- Resource reports record LUT, flip-flop, BRAM, DSP, and clocking-resource use.
- Critical warnings are reviewed and either fixed or documented with a technical justification.
- Physical audio operation and board-level display output are not required for MVP acceptance.

## 14. Completion Criteria

The MVP is complete only when all of the following are true:

1. The RV32I CPU boots a program from BRAM and passes arithmetic, branch, jump, load, and store integration tests.
2. Firmware reads and writes GPIO, timer, and UART through APB.
3. UART transmits the expected simulation string and completes an RX loopback test.
4. DMA BRAM-to-BRAM output exactly matches the source block.
5. The asynchronous FIFO preserves sample order across independent 100 MHz and 12.5 MHz clocks.
6. FIR output exactly matches the golden fixed-point model, including saturation cases.
7. The SoC integration test transfers samples through DMA and FIR and stores verified results in BRAM.
8. The complete automated regression passes from a clean checkout.
9. Vivado completes synthesis for the confirmed XC7Z010 target and produces reviewed timing and resource reports.
10. Documentation clearly labels FFT, display, real audio hardware, and AI as unimplemented extensions.

## 15. Recommended Delivery Sequence

1. Stabilize coding conventions, build commands, memory map, and APB protocol tests.
2. Finish GPIO, timer, UART, and APB subsystem verification.
3. Implement and test BRAM and the multi-cycle RV32I CPU.
4. Boot minimal firmware and exercise the APB peripherals.
5. Implement and verify DMA with BRAM-to-BRAM transfers.
6. Implement and verify the asynchronous FIFO.
7. Implement the FIR and fixed-point golden model.
8. Integrate the sample-processing data path and SoC firmware test.
9. Add Vivado clock/reset infrastructure and timing constraints.
10. Run synthesis, collect reports, and update the project summary with measured results only.
