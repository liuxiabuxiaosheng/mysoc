# Phase 4: BRAM-to-BRAM DMA Controller Design

**Date:** 2026-09-19  
**Status:** Approved for implementation

## Goal

Add a single-channel DMA controller that software can configure through APB and
that copies 32-bit words between the existing 64 KiB on-chip RAM and itself
through a dedicated memory-master request/response port.

## Scope

This phase implements only BRAM-to-BRAM transfers. Audio FIFO endpoints,
interrupts, and multi-channel scheduling remain later work. The existing CPU
request path and default `soc_top` external-master behavior remain unchanged;
the internal RAM connection gains only the arbitration needed to share the
single-port model safely.

## Register interface

The DMA APB window is `0x4000_5000` through `0x4000_5FFF`.

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `DMA_SRC` | RW | Source byte address |
| `0x04` | `DMA_DST` | RW | Destination byte address |
| `0x08` | `DMA_LENGTH` | RW | Number of 32-bit words |
| `0x0C` | `DMA_CTRL` | RW | Bit 0 requests start |
| `0x10` | `DMA_STATUS` | RW1C | Bit 0 busy, bit 1 done, bit 2 alignment/configuration error, bit 3 bus error |

Writes to `DMA_CTRL` with bit 0 set start a transfer. A start request is
rejected when the length is zero, either address is not word aligned, or the
controller is already busy. Rejected requests set the sticky configuration
error bit and do not alter the programmed addresses or length. `DONE` and
error bits remain set until software writes ones to the corresponding status
bits. Status reads are always ready in the APB access phase.

## DMA state machine

The controller has one outstanding memory operation:

```text
IDLE → READ_REQ → READ_WAIT → WRITE_REQ → WRITE_WAIT → DONE
```

`READ_REQ` and `WRITE_REQ` assert a stable request until the memory target
returns `mem_resp_ready` or `mem_resp_error`. A successful read latches the
word; a successful write increments both addresses and decrements the
remaining-word counter. The final write enters `DONE`, which raises the sticky
done bit and returns to `IDLE` after one cycle.

The dedicated memory-master interface is:

```text
dma_mem_req_valid, dma_mem_req_write, dma_mem_req_addr,
dma_mem_req_wdata, dma_mem_req_wstrb,
dma_mem_resp_rdata, dma_mem_resp_ready, dma_mem_resp_error
```

All DMA accesses use `4'b1111` strobes and word-aligned addresses. A target
error aborts the transfer, clears `busy`, and sets the sticky bus-error bit.

## APB integration

`apb_interconnect` adds a DMA select for `0x4000_5xxx`; `apb_subsystem`
instantiates the DMA register bank and exposes its memory-master signals.
`soc_top` connects the DMA master to the existing RAM through a small
round-robin-free arbiter with CPU priority: an active CPU RAM transaction is
completed first, otherwise a DMA request is forwarded. Since both clients
hold requests until completion, the arbiter grants one transaction at a time
and never mixes response data between clients. The external CPU bus ports and
their timing remain unchanged.

## Verification

The testbench will cover:

1. APB register read/write and RW1C status clearing.
2. A multi-word BRAM-to-BRAM transfer with exact destination matching.
3. Zero-length, unaligned, busy-start, and memory-error rejection.
4. Stable memory request signals while the target stalls.
5. CPU-visible APB access through the integrated `soc_top` path.
6. Existing phase-one through phase-three regression and top-level elaboration.

## Non-goals

No audio FIFO endpoints, interrupts, asynchronous clock crossing, burst
protocol, scatter/gather descriptors, or software toolchain changes are part of
this phase.
