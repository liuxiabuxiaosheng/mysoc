# Phase 2: On-Chip Memory and CPU Bus Design

**Date:** 2026-09-19  
**Status:** Approved design; awaiting written-spec review before implementation

## Purpose and Scope

Phase 2 establishes the request/response path required for the future RV32I CPU to access program/data memory and the already verified APB peripherals. It implements only on-chip memory, CPU-bus address decoding, and a CPU-to-APB bridge. It does not implement the RV32I core, DMA, arbitration, firmware, or new peripherals.

## Architecture

```text
CPU bus test driver / future RV32I
              |
      cpu_bus_decoder
        /           \
onchip_ram       cpu_apb_bridge
  (64 KiB)              |
                  apb_subsystem
             GPIO / Timer / UART
```

The Phase-2 `soc_top` integration replaces the existing idle APB-master tie-off with the bridge outputs. In this phase, a testbench drives the CPU-bus inputs directly; no CPU RTL is added.

## CPU Bus Interface

The interface carries a single outstanding transaction:

- Request: 32-bit address, 32-bit write data, four byte-write strobes, read/write request indication, and request-valid.
- Response: 32-bit read data, `ready`, and `error`.

`cpu_bus_decoder` accepts a request, latches every request field, and retains it until exactly one completion response. The requester keeps its request asserted until `ready` or `error`; the decoder's latching makes downstream transactions stable even while the requester prepares a later operation.

## Address Mapping and Memory Behavior

| Address range | Target | Behavior |
| --- | --- | --- |
| `0x0000_0000`–`0x0000_FFFF` | `onchip_ram` | 64 KiB, 32-bit access, byte enables |
| `0x4000_0000` and above | APB bridge | APB peripheral access |
| All other addresses | Decoder | Complete with bus `error` |

`onchip_ram` is a single-port, synchronous-read RTL memory intended to infer FPGA Block RAM. A valid aligned request completes one clock later. Writes apply the four byte strobes independently, allowing byte, halfword, and word writes. The module has an optional hexadecimal initialization-file parameter. If no file is provided, the memory initializes to zero for deterministic simulation.

CPU-bus addresses must be four-byte aligned. An unaligned access completes with `error` and does not modify memory. The valid RAM range ends at `0x0000_FFFF`; no wraparound or aliasing is permitted.

## APB Bridge

`cpu_apb_bridge` converts one accepted peripheral request into APB Setup and Access phases. It keeps `PADDR`, `PWRITE`, `PWDATA`, and write strobes stable from Setup through Access and throughout any slave wait states. It completes the CPU transaction only when APB reports `PREADY`; `PSLVERR` becomes the CPU-bus `error`, and `PRDATA` becomes the CPU read data.

Existing APB decode and peripheral error behavior are preserved. Addresses that are forwarded to APB but are not mapped by its interconnect complete with the existing APB error response.

## Error and Reset Behavior

- Decoder-invalid and RAM-unaligned accesses return an error response without side effects.
- An APB `PSLVERR` becomes a CPU-bus error response.
- Reset cancels any in-flight decoder or bridge transaction, deasserts APB selection, and restores the RAM control state to idle.
- The BRAM contents follow its documented initialization behavior; reset does not perform a 64 KiB sequential clear.

## Verification and Acceptance

The self-checking regression gains tests for:

1. BRAM synchronous read timing, whole-word writes, byte and halfword byte-enable writes, initialization, range boundaries, and unaligned-access rejection.
2. CPU-bus reads and writes to BRAM, including a request held through completion.
3. CPU-bus accesses through the bridge to GPIO.
4. APB Setup/Access sequencing and stable address, direction, write data, and strobes during a peripheral wait state.
5. Invalid decoded addresses and APB-unmapped addresses returning bus errors.
6. Phase-2 `soc_top` integration and the full existing phase-one regression.

Phase 2 is accepted when these tests pass through the repository's one-command regression, and synthesizable top-level elaboration checks succeed in Icarus Verilog.

## Deferred Work

CPU instruction execution, CPU/DMA memory arbitration, firmware image generation, and all later DMA, CDC, audio, display, and FPGA implementation work remain outside this phase.
