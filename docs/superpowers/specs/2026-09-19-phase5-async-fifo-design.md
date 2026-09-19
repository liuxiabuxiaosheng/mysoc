# Phase 5: Asynchronous FIFO / CDC Design

**Date:** 2026-09-19  
**Status:** Approved for implementation

## Goal

Add a reusable asynchronous FIFO that safely transfers multi-bit samples between
independent write and read clock domains.

## Scope

The FIFO is standalone and parameterized. The default configuration is 16-bit
data and 16 entries, with a power-of-two depth. Audio, DMA endpoint wiring,
FIR processing, and board clock generation remain outside this phase.

## Interface

```systemverilog
async_fifo #(
    .DATA_WIDTH(16),
    .ADDR_WIDTH(4)
) u_fifo (
    .wr_clk, .wr_rst_n, .wr_en, .wr_data, .full, .overflow,
    .rd_clk, .rd_rst_n, .rd_en, .rd_data, .empty, .underflow
);
```

`wr_en` stores one word when `full` is low. `rd_en` returns one word when
`empty` is low. An attempted write while full sets sticky `overflow`; an
attempted read while empty sets sticky `underflow`. Data output holds its last
value when no successful read occurs.

## CDC architecture

Each domain maintains a binary pointer and a Gray-coded pointer. The write Gray
pointer crosses into the read domain through two write-clocked-to-read-clock
flip-flops, and the read Gray pointer crosses through the reciprocal pair.
Full and empty are calculated only from locally synchronized pointers.

The write pointer is considered full when its next Gray value equals the read
pointer with the two most-significant address-cycle bits inverted. Empty is
asserted when the next read operation would observe the synchronized write
pointer as equal to the local read pointer. The memory array is written only in
the write clock domain and read only in the read clock domain.

## Reset behavior

Write and read resets are independent active-low inputs. Each local pointer,
synchronizer, flag, output register, and sticky error flag returns to its idle
state in its own domain. Tests intentionally vary reset release timing and
clock phase; after both sides are released, the FIFO must resume in empty,
non-error state unless a new overflow/underflow attempt occurs.

## Verification

The testbench covers ordered transfer with unrelated clocks, full and empty
backpressure, pointer wraparound, overflow/underflow stickiness, and an
independently asserted read-side reset. It also checks that no data bus is
sampled directly across clock domains outside the dual-port memory semantics.

## Non-goals

No asynchronous reset synchronizer module replacement, clock wizard changes,
audio integration, DMA integration, or FIR implementation is included.
