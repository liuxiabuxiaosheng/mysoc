# Phase 7: Audio DMA/FIFO/FIR Pipeline Design

**Date:** 2026-09-19  
**Status:** Approved for implementation

## Goal

Integrate the verified DMA controller, asynchronous FIFOs, and 16-tap FIR into
one CPU-configurable audio processing path that reads signed 16-bit samples
from BRAM and writes filtered samples back to BRAM.

## Data flow

```text
BRAM input samples
       ↓
DMA system-clock domain
       ↓
input Async FIFO
       ↓  audio clock domain
16-tap FIR
       ↓
output Async FIFO
       ↓  system-clock domain
DMA writeback
       ↓
BRAM output samples
```

The system clock remains the existing 50 MHz simulation clock. The audio clock
is a separate testbench clock and is 12.5 MHz in the integration test. Physical
audio pins and the Vivado Clocking Wizard remain outside this phase.

## Audio control/status registers

The audio block occupies `0x4000_3000–0x4000_3FFF`.

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `AUDIO_CTRL` | RW | Bit 0 enable, bit 1 bypass, bit 2 clear state |
| `0x04` | `AUDIO_STATUS` | RW1C | Bit 0 input overflow, bit 1 input underflow, bit 2 output overflow, bit 3 output underflow, bit 4 active, bit 5 complete |
| `0x08` | `AUDIO_DATA_IN` | WO | Reserved for direct FIFO injection; integration uses DMA endpoint mode |
| `0x0C` | `AUDIO_DATA_OUT` | RO | Last output sample, sign-extended to 32 bits |
| `0x10` | `AUDIO_COEFF_INDEX` | RW | FIR coefficient index 0–15 |
| `0x14` | `AUDIO_COEFF_DATA` | RW | Signed Q1.15 FIR coefficient |
| `0x18` | `AUDIO_SAMPLE_COUNT` | RO | Completed output sample count |

Coefficient writes are accepted in the system clock domain and applied to the
FIR coefficient storage before processing begins. `AUDIO_CTRL.enable` gates the
audio pipeline. `clear state` clears sample history, FIFO state, sticky errors,
and the sample counter when the pipeline is idle.

## DMA endpoint behavior

The existing DMA register programming remains unchanged. The source or
destination address selects a FIFO endpoint when it equals the audio data
register address. BRAM addresses continue to use the existing RAM master port.

- BRAM → input FIFO: DMA reads one 32-bit word from BRAM and pushes its low and
  high signed 16-bit samples into the input FIFO in order.
- Output FIFO → BRAM: DMA obtains two 16-bit FIR outputs and packs them into one
  32-bit word before issuing the BRAM write.
- FIFO `ready` backpressure stalls the DMA transfer without dropping data.
- Endpoint errors set the existing DMA bus-error status and abort the transfer.

For this phase the integrated test uses an even number of 16-bit samples and
word-aligned BRAM addresses. Odd-length and partial-word transfers remain
future extensions.

## Clock-domain boundaries

The input and output streams cross only through the verified `async_fifo`
instances. The audio control enable and coefficient programming are sampled
before a run starts; the FIR processing itself remains entirely in the audio
clock domain. Status and sample count are returned through synchronized sticky
flags and a system-domain count register.

## Verification

The integration test will:

1. Seed an even-length signed sample block in BRAM.
2. Program FIR coefficients and enable the audio block through APB.
3. Configure DMA for BRAM → input FIFO and wait for completion.
4. Run the independent audio clock until all samples are filtered.
5. Configure DMA for output FIFO → BRAM and wait for completion.
6. Compare every output sample with a software Q1.15 model.
7. Exercise FIFO backpressure and sticky status clearing.

Existing unit tests for CPU, DMA, Async FIFO, FIR, and all APB peripherals must
continue to pass.

## Non-goals

No physical audio interface, I2S/PDM, FFT, display, AI inference, odd-sample
DMA packing, or FPGA clock constraints are included.
