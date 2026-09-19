# Phase 6: 16-Tap Fixed-Point FIR Design

**Date:** 2026-09-19  
**Status:** Approved for implementation

## Goal

Add a standalone, synthesizable 16-tap fixed-point FIR filter that accepts
streaming signed audio samples and produces numerically defined saturated
outputs.

## Interface

```systemverilog
fir_filter #(.TAPS(16), .DATA_WIDTH(16), .COEFF_WIDTH(16), .ACC_WIDTH(40)) u_fir (
    .clk, .rst_n,
    .in_valid, .in_ready, .in_sample,
    .coeff_we, .coeff_index, .coeff_data,
    .out_valid, .out_ready, .out_sample
);
```

`in_valid && in_ready` accepts one sample. `out_valid && out_ready` retires one
output. The output register holds its value while `out_valid` is asserted and
the consumer is stalled. The filter can accept a new sample in the same cycle
that a previous output is consumed.

## Fixed-point arithmetic

Samples and coefficients are signed Q1.15 values. Each product is signed
16×16-bit and is accumulated in a signed 40-bit accumulator. The sum is
rounded to nearest with a half-LSB adjustment at bit 14, arithmetically shifted
right by 15, and saturated to the signed 16-bit range `[-32768, 32767]`.

Coefficient writes are synchronous and select one of the 16 taps with
`coeff_index`. Tap zero multiplies the newly accepted sample; higher taps
multiply progressively older samples in the shift history.

## Microarchitecture

The filter keeps a 16-entry sample shift register and computes the complete MAC
for an accepted sample in one clocked transaction. `in_ready` is high whenever
the output register is empty or its current value is being consumed. This
provides a one-sample-per-cycle steady state when the downstream consumer is
ready, while requiring no hidden queue.

## Verification

The testbench uses a software-equivalent signed arithmetic model to check an
impulse response, a short stream with programmable coefficients, positive and
negative saturation, output backpressure, and coefficient updates. Existing
CPU, DMA, and Async FIFO regression tests remain mandatory.

## Non-goals

No DMA endpoint, Async FIFO connection, audio clocking, I2S interface, FFT, or
board-level implementation is included in this phase.
