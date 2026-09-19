# Phase 2 Memory and CPU Bus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Implement and verify the 64 KiB synchronous RAM, single-outstanding CPU request routing, and CPU-to-APB connection.

**Architecture:** cpu_bus_decoder accepts and latches one CPU request. It routes aligned RAM addresses to onchip_ram, peripheral addresses to cpu_apb_bridge, and completes unsupported or unaligned requests with an error. soc_top connects these components to the existing APB subsystem while a testbench drives the exposed CPU interface.

**Tech Stack:** SystemVerilog 2012, Icarus Verilog 13.0, VVP, PowerShell.

## Global Constraints

- RAM maps exactly 0x0000_0000 through 0x0000_FFFF, is 32-bit wide, and supports four byte-write strobes.
- Requests are 32-bit address/data plus write, valid, and four strobes; responses are 32-bit read data, ready, and error.
- There is one outstanding CPU transaction; every request field is latched until completion.
- CPU accesses must be word aligned. An unaligned or unsupported address returns error with no RAM write side effect.
- RAM reads complete synchronously after acceptance. Reset cancels controls but does not clear RAM contents.
- Addresses at or above 0x4000_0000 go to APB; the bridge holds controls stable from Setup through all Access waits.
- GPIO, timer, UART, and every phase-one regression remain unchanged and passing.

## File Structure

| Path | Responsibility |
| --- | --- |
| rtl/memory/onchip_ram.sv | 64 KiB optional-image, synchronous RAM. |
| rtl/bus/cpu_apb_bridge.sv | CPU request to APB Setup/Access conversion. |
| rtl/bus/cpu_bus_decoder.sv | CPU request latching, alignment, and routing. |
| rtl/top/soc_top.sv | Phase-2 integration and exposed CPU interface. |
| tb/memory/onchip_ram_init.hex | Known RAM contents for initialization test. |
| tb/memory/tb_onchip_ram.sv | RAM unit test. |
| tb/bus/tb_cpu_apb_bridge.sv | Bridge unit test. |
| tb/bus/tb_cpu_bus_decoder.sv | RAM/GPIO/error routing integration test. |
| tb/top/tb_soc_top.sv | Board top reset and CPU-bus integration test. |
| sim/run_tests.ps1 | Registers every new test. |

---

### Task 1: Add a Tested Synchronous On-Chip RAM

**Files:**
- Create: rtl/memory/onchip_ram.sv
- Create: tb/memory/onchip_ram_init.hex
- Create: tb/memory/tb_onchip_ram.sv
- Modify: sim/run_tests.ps1

**Interfaces:**
- Inputs: clk, rst_n, req_valid, req_write, req_addr[31:0], req_wdata[31:0], req_wstrb[3:0].
- Outputs: resp_rdata[31:0], resp_ready, resp_error.
- Parameters: MEM_BYTES=65536, INIT_FILE="".

- [ ] **Step 1: Write the failing RAM test and image**

Create an initialization image containing:
    11223344
    55667788

Create the test with a task that holds req_valid to response. Require reads at 0x0 and 0x4 to return 1122_3344 and 5566_7788, and require neither to complete at the first request edge. Write AABB_CCDD at 0x10, then write 1100_2200 with strobe 4'b0101 and require AA00_CC00. Read/write 0xFFFC; request 0x2 and require resp_error without altering word zero.

    @(negedge clk); req_addr=addr; req_wdata=data; req_wstrb=strb; req_write=write_op; req_valid=1;
    @(posedge clk); if (resp_ready || resp_error) $fatal(1,"RAM response was not synchronous");
    do @(posedge clk); while (!resp_ready && !resp_error);
    result=resp_rdata; failed=resp_error;
    @(negedge clk); req_valid=0; req_write=0; req_wstrb='0;

- [ ] **Step 2: Register the failing test and run it**

Add onchip_ram = "tb/memory/tb_onchip_ram.sv" to the $Tests table.

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test onchip_ram

Expected: compilation fails because onchip_ram does not exist.

- [ ] **Step 3: Implement the RAM response state**

Create a 32-bit word array logic [31:0] mem [0:(MEM_BYTES/4)-1], zero it in an initial block, and conditionally load INIT_FILE with $readmemh. Implement IDLE and RESP: IDLE accepts exactly one request, performs an aligned in-range read or byte-strobe write, records an error otherwise, and enters RESP. RESP returns to IDLE. Use:

    assign resp_rdata = read_data_q;
    assign resp_ready = (state == RESP);
    assign resp_error = (state == RESP) && error_q;
    if (req_wstrb[0]) mem[req_addr[15:2]][7:0]   <= req_wdata[7:0];
    if (req_wstrb[1]) mem[req_addr[15:2]][15:8]  <= req_wdata[15:8];
    if (req_wstrb[2]) mem[req_addr[15:2]][23:16] <= req_wdata[23:16];
    if (req_wstrb[3]) mem[req_addr[15:2]][31:24] <= req_wdata[31:24];
    read_data_q <= mem[req_addr[15:2]];

- [ ] **Step 4: Verify and commit RAM**

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test onchip_ram
    git add rtl/memory/onchip_ram.sv tb/memory/onchip_ram_init.hex tb/memory/tb_onchip_ram.sv sim/run_tests.ps1
    git commit -m "feat: add verified on-chip ram"

Expected: PASS tb_onchip_ram before commit.

---

### Task 2: Add a Tested CPU-to-APB Bridge

**Files:**
- Create: rtl/bus/cpu_apb_bridge.sv
- Create: tb/bus/tb_cpu_apb_bridge.sv
- Modify: sim/run_tests.ps1

**Interfaces:**
- CPU request/response interface from Task 1.
- APB outputs: paddr[31:0], psel, penable, pwrite, pwdata[31:0], pstrb[3:0].
- APB inputs: prdata[31:0], pready, pslverr.

- [ ] **Step 1: Write the failing bridge test**

Write CAFE_BABE with all strobes to 4000_0000. Require Setup (psel and not penable), then Access (psel and penable). Keep pready low for two clocks while changing every CPU input; require APB controls remain original. Complete with prdata=1234_5678 and pslverr=1, then require one CPU error response containing that data. Repeat a successful read.

    repeat (2) begin @(posedge clk); #1;
      check(paddr==32'h4000_0000 && pwrite && pwdata==32'hCAFE_BABE && pstrb==4'hF,
            "APB control changed during wait");
    end

- [ ] **Step 2: Register and demonstrate the failing test**

Add cpu_apb_bridge = "tb/bus/tb_cpu_apb_bridge.sv".

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test cpu_apb_bridge

Expected: compile failure because the bridge is absent.

- [ ] **Step 3: Implement the four-state bridge**

Use IDLE, SETUP, ACCESS, and RESP. Latch all CPU fields only in IDLE. In ACCESS, capture prdata and pslverr when pready. Output:

    assign paddr=addr_q; assign pwrite=write_q; assign pwdata=wdata_q; assign pstrb=strb_q;
    assign psel=(state==SETUP)||(state==ACCESS); assign penable=(state==ACCESS);
    assign resp_rdata=rdata_q; assign resp_ready=(state==RESP);
    assign resp_error=(state==RESP)&&error_q;

- [ ] **Step 4: Verify and commit bridge**

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test cpu_apb_bridge
    git add rtl/bus/cpu_apb_bridge.sv tb/bus/tb_cpu_apb_bridge.sv sim/run_tests.ps1
    git commit -m "feat: add cpu to apb bridge"

Expected: PASS tb_cpu_apb_bridge before commit.

---

### Task 3: Add CPU-Bus Decode and Routed Integration

**Files:**
- Create: rtl/bus/cpu_bus_decoder.sv
- Create: tb/bus/tb_cpu_bus_decoder.sv
- Modify: sim/run_tests.ps1

**Interfaces:**
- CPU inputs: cpu_req_valid, cpu_req_write, cpu_req_addr, cpu_req_wdata, cpu_req_wstrb.
- CPU outputs: cpu_resp_rdata, cpu_resp_ready, cpu_resp_error.
- Child requests: ram_req_* and apb_req_*; child responses: ram_resp_* and apb_resp_*.

- [ ] **Step 1: Write the failing decoder integration test**

Instantiate decoder, Task-1 RAM, Task-2 bridge, and apb_subsystem. Wire bridge APB outputs to the subsystem master interface. Write/read DEAD_BEEF at RAM 0x20; write/read GPIO DATA at 4000_0000 and require gpio_out==8'h5A; require errors for 0x2, 0x0001_0000, and 0x2000_0000; require the APB error and DEAD_BEEF response for 0x4000_6000.

    do @(posedge clk); while (!cpu_resp_ready && !cpu_resp_error);
    rdata=cpu_resp_rdata; failed=cpu_resp_error;
    @(negedge clk); cpu_req_valid=0;

- [ ] **Step 2: Register and demonstrate the failing decoder test**

Add cpu_bus_decoder = "tb/bus/tb_cpu_bus_decoder.sv".

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test cpu_bus_decoder

Expected: compile failure because the decoder is absent.

- [ ] **Step 3: Implement latching and routing**

Use IDLE, RAM_WAIT, APB_WAIT, RESP. In IDLE, latch all CPU fields. Enter RAM_WAIT for aligned addresses no greater than 0000_FFFF, APB_WAIT for aligned addresses at least 4000_0000, otherwise record error and enter RESP. Capture the selected child response in its wait state. Output:

    assign ram_req_valid=(state==RAM_WAIT); assign apb_req_valid=(state==APB_WAIT);
    assign ram_req_addr=addr_q; assign apb_req_addr=addr_q;
    assign ram_req_write=write_q; assign apb_req_write=write_q;
    assign ram_req_wdata=wdata_q; assign apb_req_wdata=wdata_q;
    assign ram_req_wstrb=strb_q; assign apb_req_wstrb=strb_q;
    assign cpu_resp_rdata=rdata_q; assign cpu_resp_ready=(state==RESP);
    assign cpu_resp_error=(state==RESP)&&error_q;

- [ ] **Step 4: Verify and commit decoder integration**

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test cpu_bus_decoder
    git add rtl/bus/cpu_bus_decoder.sv tb/bus/tb_cpu_bus_decoder.sv sim/run_tests.ps1
    git commit -m "feat: route cpu bus to ram and apb"

Expected: PASS tb_cpu_bus_decoder before commit.

---

### Task 4: Integrate Phase 2 into the SoC Top

**Files:**
- Modify: rtl/top/soc_top.sv
- Modify: tb/top/tb_soc_top.sv

**Interfaces:**
- Add CPU inputs cpu_req_valid, cpu_req_write, cpu_req_addr[31:0], cpu_req_wdata[31:0], cpu_req_wstrb[3:0].
- Add CPU outputs cpu_resp_rdata[31:0], cpu_resp_ready, cpu_resp_error.
- Preserve every board port and phase1_ready behavior.

- [ ] **Step 1: Extend the top test before RTL integration**

Connect the new ports. Preserve reset checks, then write/read 1357_9BDF at RAM 0x40; write A5 at GPIO 4000_0000 and require gpio_out==A5 and no CPU error.

    @(negedge clk_50m); cpu_req_addr=32'h40; cpu_req_wdata=32'h1357_9BDF;
    cpu_req_wstrb=4'hF; cpu_req_write=1; cpu_req_valid=1;
    do @(posedge clk_50m); while (!cpu_resp_ready && !cpu_resp_error);
    check(!cpu_resp_error,"RAM access through soc_top failed");

- [ ] **Step 2: Run the intentionally failing top test**

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_top

Expected: compile failure because soc_top lacks CPU ports.

- [ ] **Step 3: Replace idle APB wiring**

Add the CPU ports and instantiate decoder, RAM, and bridge on clk_sys/rst_sync. Join decoder RAM request/response signals to RAM, decoder APB request/response signals to bridge, and bridge APB outputs to the existing subsystem. Remove idle_prdata, idle_pready, idle_pslverr, and the five constant APB-master connections. Keep the bridge pstrb as an internally verified output because the phase-one subsystem has no strobe input.

- [ ] **Step 4: Run all acceptance checks and commit**

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_top
    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
    $rtl = rg --files rtl -g '*.sv'
    iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
    iverilog -g2012 -Wall -tnull -s soc_top $rtl
    git add rtl/top/soc_top.sv tb/top/tb_soc_top.sv
    git commit -m "feat: integrate phase-two cpu memory bus"

Expected: all tests pass and both elaboration commands exit zero.

---

### Task 5: Record Observed Verification Evidence

**Files:**
- Create: docs/verification/phase2-memory-cpu-bus.md

**Interfaces:**
- Consumes final regression and elaboration output.
- Produces reproducible evidence and an accurate Phase-2 boundary statement.

- [ ] **Step 1: Perform a clean final regression**

    git clean -fdX -- sim/build
    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all

Expected: every registered test reports PASS and exits zero.

- [ ] **Step 2: Write and commit verification evidence**

Record the exact command, pass list, RAM timing/byte-strobe rules, RAM/APB/error mapping, bridge wait stability, top CPU interface, and that CPU, DMA, and firmware remain unimplemented. Re-run and commit:

    powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
    git add docs/verification/phase2-memory-cpu-bus.md
    git commit -m "docs: record phase-two verification"

## Plan Self-Review

- Tasks 1 through 4 implement every approved Phase-2 requirement; Task 5 records the observed acceptance evidence.
- RAM alignment/range, decoder gaps, and APB PSLVERR each have an explicit error response.
- CPU, RAM, and APB signal names and widths are consistent between producer and consumer.
- There are no unspecified implementation or test steps.
