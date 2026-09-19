# Phase 3: Multi-Cycle RV32I CPU Design

**Date:** 2026-09-19  
**Status:** Approved for implementation

## Goal

Add a small, synthesizable, non-pipelined RV32I processor that can execute instructions from the existing 64 KiB RAM and access the existing APB peripherals through the phase-two CPU memory bus.

## Scope

The CPU implements the base integer instructions needed by the project MVP:

- U type: `LUI`, `AUIPC`.
- Jumps: `JAL`, `JALR`.
- Conditional branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
- Loads: `LB`, `LH`, `LW`, `LBU`, `LHU`.
- Stores: `SB`, `SH`, `SW`.
- Immediate ALU: `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`.
- Register ALU: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`.

Multiplication, division, CSR, traps/interrupts, compressed instructions, caches, and pipelining remain out of scope.

## Microarchitecture

The core is a single-outstanding-request finite-state machine:

```text
FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK
```

Instruction fetch and data accesses share the existing request/response bus. Requests remain asserted until `mem_resp_ready` or `mem_resp_error`. The core latches the PC, instruction, decoded operands, and memory response data so external bus inputs may change only after completion.

The register file has 32 registers with two combinational read ports and one synchronous write port. Register `x0` always reads as zero and ignores writes. The PC resets to `0x0000_0000`.

## Module Boundaries

- `rtl/cpu/riscv_regfile.sv`: register storage and x0 semantics.
- `rtl/cpu/riscv_alu.sv`: 32-bit arithmetic, logic, shifts, and comparisons.
- `rtl/cpu/riscv_imm_gen.sv`: I/S/B/U/J immediate extraction.
- `rtl/cpu/riscv_decoder.sv`: opcode/funct decode and control fields.
- `rtl/cpu/riscv_control.sv`: state encoding and control sequencing helpers.
- `rtl/cpu/riscv_core.sv`: top-level CPU FSM and memory-bus interface.

The core interface is compatible with the phase-two bus:

```text
mem_req_valid, mem_req_write, mem_req_addr, mem_req_wdata, mem_req_wstrb
mem_resp_rdata, mem_resp_ready, mem_resp_error
```

An optional `halted` and `fault_code` output exposes terminal illegal-instruction, misaligned-access, and bus-error states for verification.

## Memory Semantics

Instruction fetches are 32-bit aligned reads. Loads and stores calculate an effective address from `rs1 + immediate`; byte and halfword operations generate the corresponding write strobes and sign/zero extend returned data. A misaligned halfword or word access halts with a fault before issuing a bus request. A byte access is always aligned.

For a load or store, the core waits in `MEMORY` until the bus responds. A bus error halts the core with a distinct fault code. For stores, response data is ignored; for loads, response data is formatted in `WRITEBACK`.

Branches and jumps update the PC only after decode/execute. `JAL` and `JALR` write `PC+4` to `rd`; `JALR` clears bit 0 of its target.

## Verification

Self-checking simulation will cover:

1. Register x0 immutability and ALU/decoder behavior.
2. A hand-assembled instruction program exercising arithmetic, shifts, comparisons, branches, loops, `LUI/AUIPC`, and `JAL/JALR`.
3. Byte/halfword/word loads and stores with sign extension.
4. RAM writes and reads through the existing bus, plus GPIO writes through APB.
5. Illegal instruction, misaligned access, and bus-error halts.
6. Full phase-one and phase-two regression plus top-level elaboration.

The test program is loaded into a dedicated simulation RAM image; no compiler toolchain is required.

## Non-Goals

This phase does not add firmware build tooling, DMA, arbitration, interrupts, machine-mode CSRs, or board-level clocking changes. Those remain later phases.
