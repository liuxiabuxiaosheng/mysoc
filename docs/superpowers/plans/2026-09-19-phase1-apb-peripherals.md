# Phase 1 APB Peripherals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a simulation-verified APB subsystem containing GPIO, timer, UART TX/RX with FIFOs, deterministic error handling, top-level integration, and a one-command regression.

**Architecture:** An external APB master BFM drives `apb_subsystem` during this phase. The interconnect decodes one 4 KiB window per peripheral and returns `PSLVERR` for unmapped addresses. Every peripheral is independently self-tested before the subsystem integration test is enabled.

**Tech Stack:** SystemVerilog 2012, Icarus Verilog, VVP, PowerShell, Git.

## Global Constraints

- Target board is ALINX AX7010 with XC7Z010CLG400-1.
- RTL is SystemVerilog and uses active-low peripheral reset `presetn`.
- APB data and address widths are 32 bits; register offsets are four-byte aligned.
- System-clock behavioral tests run at 100 MHz using a 10 ns period.
- UART default is 115200 baud from a 100 MHz clock and uses an integer divider of 868 cycles per bit.
- Invalid peripheral offsets and unmapped peripheral windows complete with `PREADY=1` and `PSLVERR=1`.
- Existing unrelated files must not be staged or committed. The untracked original project-plan Markdown file remains untouched until Task 8, where it is deliberately updated and added as project documentation.
- Each RTL change begins with a failing self-checking test and ends with the relevant regression passing.

---

## Planned File Structure

| Path | Responsibility |
| --- | --- |
| `sim/run_tests.ps1` | Compile and run one test or the complete regression |
| `tb/common/apb_tasks.svh` | Reusable APB read/write BFM tasks |
| `tb/peripheral/tb_apb_gpio.sv` | GPIO register and error tests |
| `tb/peripheral/tb_apb_timer.sv` | Timer timing, modes, status, and error tests |
| `tb/peripheral/tb_uart_fifo.sv` | FIFO ordering, wrap, full, and empty tests |
| `tb/peripheral/tb_uart_tx.sv` | UART TX bit timing and handshake tests |
| `tb/peripheral/tb_uart_rx.sv` | UART RX sampling and frame-error tests |
| `tb/peripheral/tb_uart_top.sv` | UART APB and loopback integration test |
| `tb/bus/tb_apb_interconnect.sv` | Address decode, wait-state, and unmapped tests |
| `tb/top/tb_apb_subsystem.sv` | Full APB subsystem regression |
| `tb/top/tb_soc_top.sv` | Reset and phase-one top-level smoke test |
| `rtl/peripheral/apb_gpio.sv` | GPIO APB slave |
| `rtl/peripheral/apb_timer.sv` | Timer APB slave with sticky expiry status |
| `rtl/peripheral/uart/uart_fifo.sv` | Parameterized synchronous UART FIFO |
| `rtl/peripheral/uart/uart_tx.sv` | Programmable-divider UART transmitter |
| `rtl/peripheral/uart/uart_rx.sv` | Mid-bit-sampling UART receiver |
| `rtl/peripheral/uart/uart_regs.sv` | UART APB register bank and FIFO handshakes |
| `rtl/peripheral/uart/uart_top.sv` | Complete UART APB peripheral |
| `rtl/bus/apb_interconnect.sv` | GPIO/timer/UART APB decode and response mux |
| `rtl/top/apb_subsystem.sv` | Peripheral subsystem integration |
| `rtl/top/soc_top.sv` | Phase-one board-facing integration shell |

---

### Task 1: Add the Self-Checking Simulation Harness

**Files:**
- Create: `sim/run_tests.ps1`
- Create: `tb/common/apb_tasks.svh`
- Create: `tb/common/tb_smoke.sv`

**Interfaces:**
- Produces: `sim/run_tests.ps1 -Test <name>` and reusable `apb_write`/`apb_read` tasks.
- Consumes: `iverilog` and `vvp` available on `PATH`.

- [ ] **Step 1: Add a smoke test that proves the runner can report pass/fail**

Create `tb/common/tb_smoke.sv`:

```systemverilog
`timescale 1ns/1ps
module tb_smoke;
    initial begin
        if (32'h4000_2000 + 32'h0000_000C !== 32'h4000_200C)
            $fatal(1, "address arithmetic failed");
        $display("PASS tb_smoke");
        $finish;
    end
endmodule
```

- [ ] **Step 2: Add the regression runner**

Create `sim/run_tests.ps1`:

```powershell
param([string]$Test = "all")

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $ProjectRoot "sim\build"
New-Item -ItemType Directory -Force $BuildDir | Out-Null

$Tests = [ordered]@{
    smoke           = "tb/common/tb_smoke.sv"
    apb_gpio        = "tb/peripheral/tb_apb_gpio.sv"
    apb_timer       = "tb/peripheral/tb_apb_timer.sv"
    uart_fifo       = "tb/peripheral/tb_uart_fifo.sv"
    uart_tx         = "tb/peripheral/tb_uart_tx.sv"
    uart_rx         = "tb/peripheral/tb_uart_rx.sv"
    uart_top        = "tb/peripheral/tb_uart_top.sv"
    apb_interconnect = "tb/bus/tb_apb_interconnect.sv"
    apb_subsystem   = "tb/top/tb_apb_subsystem.sv"
    soc_top         = "tb/top/tb_soc_top.sv"
}

$Selected = if ($Test -eq "all") { @($Tests.Keys) } else { @($Test) }
foreach ($Name in $Selected) {
    if (-not $Tests.Contains($Name)) { throw "Unknown test: $Name" }
    $TbPath = Join-Path $ProjectRoot $Tests[$Name]
    if (-not (Test-Path $TbPath)) {
        if ($Test -eq "all") { continue }
        throw "Testbench does not exist: $TbPath"
    }
    $Top = "tb_$Name"
    $Output = Join-Path $BuildDir "$Name.vvp"
    $Rtl = @(Get-ChildItem (Join-Path $ProjectRoot "rtl") -Recurse -Filter "*.sv" | ForEach-Object FullName)
    & iverilog -g2012 -Wall -I (Join-Path $ProjectRoot "tb\common") -s $Top -o $Output @Rtl $TbPath
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $Name" }
    & vvp $Output
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $Name" }
}
```

- [ ] **Step 3: Add reusable APB tasks**

Create `tb/common/apb_tasks.svh` with tasks that assume the including testbench declares `pclk`, `paddr`, `psel`, `penable`, `pwrite`, `pwdata`, `prdata`, `pready`, and `pslverr`:

```systemverilog
task automatic apb_idle;
    begin
        paddr = '0; psel = 0; penable = 0; pwrite = 0; pwdata = '0;
    end
endtask

task automatic apb_write(input logic [31:0] addr,
                         input logic [31:0] data,
                         output logic error_seen);
    begin
        @(negedge pclk);
        paddr = addr; pwdata = data; pwrite = 1; psel = 1; penable = 0;
        @(negedge pclk);
        penable = 1;
        while (!pready) @(negedge pclk);
        error_seen = pslverr;
        @(negedge pclk);
        apb_idle();
    end
endtask

task automatic apb_read(input logic [31:0] addr,
                        output logic [31:0] data,
                        output logic error_seen);
    begin
        @(negedge pclk);
        paddr = addr; pwrite = 0; psel = 1; penable = 0;
        @(negedge pclk);
        penable = 1;
        while (!pready) @(negedge pclk);
        data = prdata; error_seen = pslverr;
        @(negedge pclk);
        apb_idle();
    end
endtask
```

- [ ] **Step 4: Run the smoke test**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test smoke`

Expected: output contains `PASS tb_smoke` and the process exits with status zero.

- [ ] **Step 5: Commit the harness**

```powershell
git add sim/run_tests.ps1 tb/common/apb_tasks.svh tb/common/tb_smoke.sv
git commit -m "test: add SystemVerilog regression harness"
```

---

### Task 2: Make GPIO APB Behavior Fully Specified

**Files:**
- Create: `tb/peripheral/tb_apb_gpio.sv`
- Modify: `rtl/peripheral/apb_gpio.sv`

**Interfaces:**
- Consumes: standard APB slave signals and `gpio_in[GPIO_WIDTH-1:0]`.
- Produces: `gpio_out`, `gpio_dir`, zero-wait-state APB response, and `PSLVERR` on invalid offsets.

- [ ] **Step 1: Write the failing GPIO test**

The test must instantiate `apb_gpio #(.GPIO_WIDTH(8))`, generate a 100 MHz clock, hold reset low for four clocks, include `apb_tasks.svh`, and perform these exact checks:

```systemverilog
apb_read(32'h4000_0000, rdata, err);
if (err || rdata !== 32'h0) $fatal(1, "GPIO_DATA reset mismatch");
apb_write(32'h4000_0000, 32'h0000_00A5, err);
if (err || gpio_out !== 8'hA5) $fatal(1, "GPIO_DATA write failed");
apb_write(32'h4000_0004, 32'h0000_003C, err);
if (err || gpio_dir !== 8'h3C) $fatal(1, "GPIO_DIR write failed");
gpio_in = 8'h5A;
apb_read(32'h4000_0008, rdata, err);
if (err || rdata !== 32'h0000_005A) $fatal(1, "GPIO_INPUT read failed");
apb_read(32'h4000_000C, rdata, err);
if (!err) $fatal(1, "invalid GPIO offset did not assert PSLVERR");
```

End with `PASS tb_apb_gpio` and `$finish`.

- [ ] **Step 2: Run the test and verify the invalid-offset check fails**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_gpio`

Expected: FAIL because the current GPIO permanently drives `pslverr=0`.

- [ ] **Step 3: Implement valid-offset decoding**

In `rtl/peripheral/apb_gpio.sv`, add:

```systemverilog
wire [3:0] reg_offset = paddr[5:2];
wire valid_offset = (reg_offset == 4'h0) ||
                    (reg_offset == 4'h1) ||
                    (reg_offset == 4'h2);
assign pready = 1'b1;
assign pslverr = psel && penable && !valid_offset;
wire apb_write = psel && penable && pwrite && pready && valid_offset;
```

Use `reg_offset` in both register cases. Keep `GPIO_INPUT` read-only, reset `gpio_out` and `gpio_dir` to zero, and return zero data for an invalid offset.

- [ ] **Step 4: Run the GPIO test**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_gpio`

Expected: `PASS tb_apb_gpio`.

- [ ] **Step 5: Commit GPIO behavior and test**

```powershell
git add rtl/peripheral/apb_gpio.sv tb/peripheral/tb_apb_gpio.sv
git commit -m "fix: define GPIO APB error behavior"
```

---

### Task 3: Replace the Timer Pulse with a Sticky Status Model

**Files:**
- Create: `tb/peripheral/tb_apb_timer.sv`
- Modify: `rtl/peripheral/apb_timer.sv`

**Interfaces:**
- `TIMER_CTRL[0]`: enable.
- `TIMER_CTRL[1]`: periodic mode.
- `TIMER_STATUS[0]`: sticky expiry, write one to clear.
- `timer_irq`: asserted whenever sticky expiry is set.

- [ ] **Step 1: Write the failing timer test**

Use APB tasks to set `TIMER_COMPARE=3`, enable one-shot mode, wait four rising edges, and check:

```systemverilog
apb_read(32'h4000_100C, rdata, err);
if (err || rdata[0] !== 1'b1 || timer_irq !== 1'b1)
    $fatal(1, "one-shot expiry was not sticky");
repeat (4) @(posedge pclk);
if (timer_irq !== 1'b1) $fatal(1, "timer status disappeared without clear");
apb_write(32'h4000_100C, 32'h1, err);
if (err || timer_irq !== 1'b0) $fatal(1, "RW1C clear failed");
```

Then set periodic mode, verify two expiry events can be observed with a clear between them, and verify offset `0x10` returns `PSLVERR`.

- [ ] **Step 2: Run and verify failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_timer`

Expected: FAIL because the existing `timer_irq` is a one-cycle pulse and invalid offsets never error.

- [ ] **Step 3: Consolidate timer state into one sequential process**

Implement `ctrl_reg`, `counter_reg`, `compare_reg`, and `status_reg` in one `always_ff` block to avoid multiple drivers. Apply operations in this order within each clock: reset, APB writes, counter update, and expiry set, with an expiry set taking precedence over a simultaneous software clear.

Use this terminal-count behavior:

```systemverilog
if (ctrl_reg[0]) begin
    if ((compare_reg == 0) || (counter_reg + 1 >= compare_reg)) begin
        counter_reg <= 0;
        status_reg[0] <= 1'b1;
        if (!ctrl_reg[1]) ctrl_reg[0] <= 1'b0;
    end else begin
        counter_reg <= counter_reg + 1'b1;
    end
end
```

Drive `timer_irq` from `status_reg[0]`, expose offsets `0x00`, `0x04`, `0x08`, and `0x0C`, and assert `PSLVERR` for any other accessed offset.

- [ ] **Step 4: Run timer and GPIO regressions**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_timer`

Expected: `PASS tb_apb_timer`.

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_gpio`

Expected: `PASS tb_apb_gpio`.

- [ ] **Step 5: Commit timer behavior and test**

```powershell
git add rtl/peripheral/apb_timer.sv tb/peripheral/tb_apb_timer.sv
git commit -m "feat: add sticky timer status and periodic mode"
```

---

### Task 4: Implement and Verify UART Datapath Primitives

**Files:**
- Create: `tb/peripheral/tb_uart_fifo.sv`
- Create: `tb/peripheral/tb_uart_tx.sv`
- Create: `tb/peripheral/tb_uart_rx.sv`
- Modify: `rtl/peripheral/uart/uart_fifo.sv`
- Modify: `rtl/peripheral/uart/uart_tx.sv`
- Modify: `rtl/peripheral/uart/uart_rx.sv`

**Interfaces:**
- FIFO: `wr_en`, `wr_data`, `full`, `rd_en`, `rd_data`, `empty`, `count`.
- TX: `data_in`, `start`, `baud_div`, `tx`, `busy`, `done`.
- RX: `rx`, `baud_div`, `data_out`, `valid`, `frame_error`.

- [ ] **Step 1: Write FIFO tests before implementation**

`tb_uart_fifo.sv` must instantiate an 8-bit, depth-4 FIFO and verify reset-empty, writes of `11/22/33/44`, full detection, rejection of a fifth write, ordered reads, wraparound after mixed reads/writes, empty detection, and rejection of an empty read. The test must compare `count` after every operation and finish with `PASS tb_uart_fifo`.

- [ ] **Step 2: Run FIFO test and verify compile or behavior failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_fifo`

Expected: FAIL because `uart_fifo.sv` is empty.

- [ ] **Step 3: Implement the synchronous FIFO**

Use parameters `DATA_WIDTH=8` and `DEPTH=16`, require a power-of-two depth, derive pointer width with `$clog2(DEPTH)`, maintain a count from zero through DEPTH, and allow a simultaneous read/write without changing count. Ignore writes while full and reads while empty. Register `rd_data` when a valid read occurs.

The count update must use:

```systemverilog
case ({wr_en && !full, rd_en && !empty})
    2'b10: count <= count + 1'b1;
    2'b01: count <= count - 1'b1;
    default: count <= count;
endcase
```

- [ ] **Step 4: Run FIFO test to green**

Expected command: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_fifo`

Expected: `PASS tb_uart_fifo`.

- [ ] **Step 5: Write TX timing test before changing TX RTL**

Instantiate TX with a runtime `baud_div=8`. Pulse `start` for one clock with data `8'hA5`. Sample `tx` in the center of ten consecutive bit periods and compare against `{stop=1, data=8'hA5 LSB-first, start=0}`. Verify `busy` stays high for the complete frame, `done` pulses once, and a second `start` while busy is ignored.

- [ ] **Step 6: Run TX test and verify interface failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_tx`

Expected: FAIL because the existing transmitter has a fixed parameter divider, a nine-bit counter, and no `done` output.

- [ ] **Step 7: Implement programmable-divider TX**

Replace the fixed `BAUD_CNT` parameter with `input logic [31:0] baud_div`. Latch `data_in` only when idle and `start` is asserted. Treat divider values below two as two. Hold start, each of eight data bits, and stop for exactly the latched divider count. Keep `busy=1` from acceptance through the final stop-bit clock and pulse `done` for one system clock.

- [ ] **Step 8: Write and run RX test before RX implementation**

Drive an idle-high serial line, transmit `8'h3C` with eight clocks per bit, and verify one-cycle `valid` with `data_out=8'h3C`. Repeat with a low stop bit and verify `frame_error=1`. Apply a short low glitch shorter than half a bit and verify no valid byte is produced.

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_rx`

Expected: FAIL because `uart_rx.sv` is empty.

- [ ] **Step 9: Implement mid-bit-sampling RX**

Synchronize `rx` through two flip-flops. Detect a low start candidate, wait half of the latched divider, reject it if the synchronized line returned high, then sample eight LSB-first data bits every divider clocks. Sample the stop bit one divider later, pulse `valid`, and pulse `frame_error` when stop is low. Treat divider values below two as two.

- [ ] **Step 10: Run all three primitive tests**

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_fifo
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_tx
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_rx
```

Expected: all three tests print PASS.

- [ ] **Step 11: Commit UART primitives**

```powershell
git add rtl/peripheral/uart/uart_fifo.sv rtl/peripheral/uart/uart_tx.sv rtl/peripheral/uart/uart_rx.sv tb/peripheral/tb_uart_fifo.sv tb/peripheral/tb_uart_tx.sv tb/peripheral/tb_uart_rx.sv
git commit -m "feat: implement verified UART datapath primitives"
```

---

### Task 5: Build the APB UART Peripheral

**Files:**
- Create: `tb/peripheral/tb_uart_top.sv`
- Modify: `rtl/peripheral/uart/uart_regs.sv`
- Modify: `rtl/peripheral/uart/uart_top.sv`

**Interfaces:**
- APB offsets: DATA `0x00`, STATUS `0x04`, CTRL `0x08`, BAUD `0x0C`.
- STATUS bits: 0 TX empty, 1 TX full, 2 RX empty, 3 RX full, 4 RX frame error, 5 RX overflow.
- CTRL bits: 0 TX enable, 1 RX enable, 8 write-one-to-clear frame error.

- [ ] **Step 1: Write the failing APB UART loopback test**

Instantiate `uart_top` with `tx` connected to `rx`. After reset, verify BAUD defaults to 868, program BAUD to 8 for fast loopback simulation, enable TX and RX, write bytes `8'h55`, `8'hA3`, and `8'h00` to DATA, wait until RX is nonempty, then read the same bytes in order. In a separate fullness case, reset the DUT, set BAUD to 2000, enable TX, perform seventeen DATA writes faster than one frame can drain, and verify the seventeenth full-FIFO write returns `PSLVERR`. Also verify reading DATA while RX-empty returns `PSLVERR` and offset `0x10` returns `PSLVERR`.

- [ ] **Step 2: Run and verify failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_top`

Expected: FAIL because `uart_regs.sv` and `uart_top.sv` are empty.

- [ ] **Step 3: Implement `uart_regs.sv`**

The register bank must:

- Reset `ctrl_reg` to zero and `baud_reg` to 868.
- Push `pwdata[7:0]` to TX FIFO on a valid DATA write when TX is enabled and FIFO is not full.
- Pop RX FIFO on a valid DATA read when RX is enabled and FIFO is not empty.
- Return STATUS from the defined FIFO flags and sticky frame-error bit.
- Update CTRL and BAUD on valid writes, clamping BAUD values below two to two.
- Return `PSLVERR` for invalid offsets, TX writes when disabled/full, and RX reads when disabled/empty.
- Set frame-error sticky status on an RX frame error and clear it when CTRL bit 8 is written as one.

- [ ] **Step 4: Implement `uart_top.sv` integration**

Instantiate two depth-16 `uart_fifo` blocks, `uart_tx`, `uart_rx`, and `uart_regs`. Start TX whenever TX is enabled, TX FIFO is nonempty, and the transmitter is idle; pop one byte for each accepted start. Push a received byte when `valid` is asserted and RX is enabled; if RX FIFO is full, preserve existing FIFO data and expose overflow through an additional sticky STATUS bit 5.

- [ ] **Step 5: Run UART integration and primitive regressions**

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_top
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_fifo
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_tx
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test uart_rx
```

Expected: all tests print PASS.

- [ ] **Step 6: Commit APB UART integration**

```powershell
git add rtl/peripheral/uart/uart_regs.sv rtl/peripheral/uart/uart_top.sv tb/peripheral/tb_uart_top.sv
git commit -m "feat: add APB UART with TX and RX FIFOs"
```

---

### Task 6: Extend the APB Interconnect and Subsystem

**Files:**
- Create: `tb/bus/tb_apb_interconnect.sv`
- Create: `tb/top/tb_apb_subsystem.sv`
- Modify: `rtl/bus/apb_interconnect.sv`
- Modify: `rtl/top/apb_subsystem.sv`

**Interfaces:**
- GPIO window: `0x4000_0000`-`0x4000_0FFF`.
- Timer window: `0x4000_1000`-`0x4000_1FFF`.
- UART window: `0x4000_2000`-`0x4000_2FFF`.
- Exactly one slave select may be asserted for a mapped transfer.

- [ ] **Step 1: Write the failing interconnect test**

Drive mapped setup and access phases for all three windows. Check one-hot slave selection, returned `PRDATA/PREADY/PSLVERR`, propagation of a two-cycle UART wait state, and an unmapped access to `0x4000_6000` returning `32'hDEAD_BEEF`, `PREADY=1`, and `PSLVERR=1`. Check that no slave select is active while master `PSEL=0`.

- [ ] **Step 2: Run and verify UART decode failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_interconnect`

Expected: FAIL because the current interconnect has no UART port or decode.

- [ ] **Step 3: Add UART ports and gate response selection**

Add `uart_psel`, `uart_prdata`, `uart_pready`, and `uart_pslverr`. Decode `m_paddr[31:12] == 20'h40002`. Drive each slave select as `m_psel && corresponding_decode`. Select return data only when `m_psel` and a decode are both active. Preserve `DEAD_BEEF` and `PSLVERR` for unmapped selected transfers.

- [ ] **Step 4: Run interconnect test to green**

Expected command: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_interconnect`

Expected: `PASS tb_apb_interconnect`.

- [ ] **Step 5: Write the subsystem test**

Instantiate `apb_subsystem` with UART loopback. Through the master APB interface:

- Write/read GPIO DATA and DIR.
- Set GPIO input and read it back.
- Configure timer compare and observe sticky `timer_irq`.
- Program UART divider to 8, enable TX/RX, send and receive `8'hC7`.
- Access `0x4000_6000` and verify system-level `PSLVERR`.
- Assert reset during a UART transfer and verify all peripherals return to documented reset state.

- [ ] **Step 6: Run and verify subsystem compile failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_subsystem`

Expected: FAIL because the current subsystem has no UART instance or pins.

- [ ] **Step 7: Integrate UART in `apb_subsystem.sv`**

Add `uart_rx` input and `uart_tx` output, connect the UART APB return path to the interconnect, and instantiate `uart_top`. Keep GPIO and timer interfaces unchanged.

- [ ] **Step 8: Run the complete subsystem regression**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_subsystem`

Expected: `PASS tb_apb_subsystem`.

- [ ] **Step 9: Commit interconnect and subsystem integration**

```powershell
git add rtl/bus/apb_interconnect.sv rtl/top/apb_subsystem.sv tb/bus/tb_apb_interconnect.sv tb/top/tb_apb_subsystem.sv
git commit -m "feat: integrate UART into APB subsystem"
```

---

### Task 7: Integrate the Phase-One SoC Shell

**Files:**
- Create: `tb/top/tb_soc_top.sv`
- Modify: `rtl/common/clk_gen.sv`
- Modify: `rtl/top/soc_top.sv`

**Interfaces:**
- Board-facing inputs: `clk_50m`, `rst_n`, `uart_rx`, `gpio_in[7:0]`.
- Board-facing outputs: `uart_tx`, `gpio_out[7:0]`, `gpio_dir[7:0]`, `timer_irq`, `phase1_ready`.

- [ ] **Step 1: Write the failing top-level smoke test**

Instantiate `soc_top`, toggle `clk_50m` every 10 ns, hold `rst_n=0` for five input clocks, release reset, and require `phase1_ready` to assert within twenty input clocks. Verify UART idles high and GPIO outputs/directions remain zero after reset.

- [ ] **Step 2: Run and verify interface failure**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_top`

Expected: FAIL because the current top has no peripheral subsystem or board-facing ports.

- [ ] **Step 3: Define the phase-one clock wrapper behavior**

For simulation-only phase one, keep `clk_sys=clk_50m` and document that it runs at 50 MHz until the later Vivado clocking task replaces the wrapper. Set `locked` after reset has synchronously deasserted. The phase-one top has an idle APB master, so the UART default divider is not exercised at board level. Do not claim 100 MHz timing or functional board UART from this wrapper.

- [ ] **Step 4: Integrate the APB subsystem with idle master inputs**

Instantiate `apb_subsystem`, expose GPIO/UART/timer pins, and tie the temporary master interface to an idle transfer (`PSEL=0`). Drive `phase1_ready = locked && rst_sync`. This smoke shell proves reset and peripheral integration; functional APB traffic remains verified through `tb_apb_subsystem` until the CPU/APB bridge phase replaces idle master inputs.

- [ ] **Step 5: Run top-level and full phase-one regression**

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_top
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
```

Expected: every existing test prints PASS and the PowerShell process exits zero.

- [ ] **Step 6: Compile both synthesizable tops independently**

```powershell
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

Expected: both commands exit zero without syntax errors.

- [ ] **Step 7: Commit phase-one top integration**

```powershell
git add rtl/common/clk_gen.sv rtl/top/soc_top.sv tb/top/tb_soc_top.sv
git commit -m "feat: add phase-one SoC integration shell"
```

---

### Task 8: Final Phase-One Verification and Documentation

**Files:**
- Create: `docs/verification/phase1-apb-peripherals.md`
- Modify: `FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md`

**Interfaces:**
- Produces: reproducible test instructions and an honest project-status table.

- [ ] **Step 1: Run clean regression and capture evidence**

Remove only generated files under `sim/build`, rerun `sim/run_tests.ps1 -Test all`, and record the exact list of passing tests. Do not remove or modify any source file.

- [ ] **Step 2: Run RTL syntax checks**

Run the two top-level Icarus commands from Task 7 and record their zero exit status.

- [ ] **Step 3: Write the phase-one verification document**

Document:

- Tool versions from `iverilog -V` and `vvp -V`.
- Commands used to run the regression.
- The exact passing test names.
- Implemented address windows and registers.
- Known phase-one limitation: `soc_top` has an idle APB master until CPU integration.
- Known phase-one limitation: `clk_gen` does not yet instantiate Vivado Clocking Wizard.
- Next planned subproject: BRAM, CPU memory bus, APB bridge, and multi-cycle RV32I.

Only include results observed in the preceding steps.

- [ ] **Step 4: Update the original project plan status without overstating completion**

Add a status section that marks APB/GPIO/Timer/UART and their testbenches as completed only if the full regression passed. Mark BRAM, CPU, DMA, CDC, FIR, display, FFT, physical audio, and AI as not implemented. Preserve the original roadmap text.

- [ ] **Step 5: Review the working tree**

Run: `git status --short`

Expected: only phase-one source, test, verification-document, and explicitly updated plan files are listed. Investigate any unrelated file before staging.

- [ ] **Step 6: Commit verification evidence**

```powershell
git add docs/verification/phase1-apb-peripherals.md FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md
git commit -m "docs: record phase-one APB verification results"
```

- [ ] **Step 7: Final verification before claiming completion**

Run: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all`

Expected: all tests pass after the documentation commit and `git status --short` shows no unexpected source changes.

---

## Subsequent Independent Plans

After this phase passes, create and approve separate detailed plans in this order:

1. BRAM, CPU memory bus, APB bridge, and multi-cycle RV32I instruction tests.
2. Bare-metal firmware image generation and CPU/peripheral integration.
3. DMA, asynchronous FIFO, fixed-point FIR, and golden-model verification.
4. Full SoC integration, Vivado Clocking Wizard, XDC constraints, synthesis, timing, and resource reporting.

Each subsequent plan must begin from the verified interfaces produced by the preceding phase and must not describe FFT, display, physical audio, or AI as implemented MVP features.
