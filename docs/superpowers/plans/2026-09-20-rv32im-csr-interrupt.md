# RV32IM CSR、Trap 与 SoC 中断 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有多周期 RV32I SoC 上加入 Machine-mode CSR/Trap、Timer/DMA/UART 中断和 RV32M 乘除法，同时保持已有测试兼容。

**Architecture:** `riscv_core` 保持主控制 FSM，新增独立 `riscv_csr` 和 `riscv_muldiv` 单元。Timer 作为 `MTIP`，DMA/UART 经 `irq_controller` 汇聚为 `MEIP`；IRQ 控制器通过 APB `0x4000_7000` 配置。旧 fault 流程在 `mtvec==0` 时保留。

**Tech Stack:** SystemVerilog RTL、Icarus Verilog 13、PowerShell `sim/run_tests.ps1`、现有 APB testbench 任务。

## Global Constraints

- 保持现有 `riscv_core` memory request/response 接口、`halted`、`fault_code` 和 `dbg_pc` 语义。
- 默认 `INTERNAL_CPU=0` 行为不变；旧 testbench 必须继续编译运行。
- `mtvec==0` 时非法指令、非对齐访问和总线错误继续走旧 FAULT 停机路径。
- 只实现 Machine Mode；不实现 Supervisor/User Mode、完整 PLIC/CLINT、向量扩展、流水线和中断嵌套。
- 所有新增生产 RTL 先有失败测试，再写最小实现；每个任务完成后运行相关单测和回归。
- 乘除法遵循 RV32M 除零和 `INT_MIN/-1` 规则。

---

### Task 1: CSR 存储与 CSR 指令单元

**Files:**
- Create: `rtl/cpu/riscv_csr.sv`
- Modify: `rtl/cpu/riscv_decoder.sv`
- Test: `tb/cpu/tb_riscv_csr.sv`
- Modify: `sim/run_tests.ps1`

**Interfaces:**
- `riscv_csr` consumes `csr_addr`, `csr_op`, `csr_wdata`, `csr_we`, `trap_enter`, `trap_is_interrupt`, `trap_cause`, `trap_pc`, `trap_tval`, `mret`, `irq_timer`, `irq_external`。
- Produces `csr_rdata`, `mtvec`, `mstatus_mie`, `mie_mtie`, `mie_meie`, `wfi_wakeup`。
- CSR addresses are `0x300/0x304/0x305/0x340..0x344/0xC00/0xC01`。

- [ ] 写 `tb_riscv_csr.sv`，先验证 reset 后 CSR 值、`CSRRW/CSRRS/CSRRC` 和立即数变体；运行 `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test riscv_csr`，确认 testbench 因模块/测试不存在失败。
- [ ] 实现 CSR 存储、只读 cycle/time 计数器、写掩码和 `mtvec[1:0]` 清零；让单元测试通过。
- [ ] 在 decoder 中增加 CSR/system 指令分类和 CSR op 输出；再次运行 `riscv_csr` 单测。
- [ ] 将测试名加入 `$Tests`，执行 `sim/run_tests.ps1 -Test riscv_csr`，确认输出 `PASS tb_riscv_csr`。
- [ ] 提交：`git add rtl/cpu/riscv_csr.sv rtl/cpu/riscv_decoder.sv tb/cpu/tb_riscv_csr.sv sim/run_tests.ps1; git commit -m "feat: add machine csr register block"`。

### Task 2: Trap、MRET、ECALL、EBREAK 和 WFI

**Files:**
- Modify: `rtl/cpu/riscv_core.sv`
- Modify: `rtl/cpu/riscv_decoder.sv`
- Test: `tb/cpu/tb_riscv_trap.sv`
- Test: `tb/cpu/tb_riscv_faults.sv`

**Interfaces:**
- `riscv_core` 新增 `input logic irq_timer`、`input logic irq_external`；旧输出保持不变。
- Core 使用 Task 1 的 CSR 接口，Trap 入口支持 direct `mtvec`。

- [ ] 写失败测试：程序设置 `mtvec` 后执行 `ECALL`，检查 `mepc/mcause/mtval` 和 handler PC；再执行 `MRET` 检查返回；加入 `WFI` 被 IRQ 唤醒测试。
- [ ] 运行 `sim/run_tests.ps1 -Test riscv_trap`，确认新行为测试失败。
- [ ] 在 core 增加 `S_TRAP`、`S_MRET`、`S_WFI`，异常优先于普通执行，且 `mtvec==0` 时沿用旧 FAULT。
- [ ] 接入 CSR trap/mret handshake，完成 `ECALL/EBREAK` 和中断入口；运行 `riscv_trap` 通过。
- [ ] 运行 `riscv_faults` 与 `riscv_core`，确认旧 fault code 仍为 1/2/3。
- [ ] 提交：`git add rtl/cpu/riscv_core.sv rtl/cpu/riscv_decoder.sv tb/cpu/tb_riscv_trap.sv tb/cpu/tb_riscv_faults.sv; git commit -m "feat: add machine trap and return flow"`。

### Task 3: RV32M 乘法器

**Files:**
- Create: `rtl/cpu/riscv_muldiv.sv`
- Modify: `rtl/cpu/riscv_decoder.sv`
- Modify: `rtl/cpu/riscv_core.sv`
- Test: `tb/cpu/tb_riscv_muldiv.sv`

**Interfaces:**
- `riscv_muldiv` 使用 `start/op/rs1/rs2` 输入和 `busy/done/result` 输出。
- 乘法支持 `MUL/MULH/MULHSU/MULHU`；第一版使用组合 64 位乘法并在 `done` 返回。

- [ ] 写失败测试，使用机器码执行四种乘法并检查低/高 32 位、负数和 `0xffffffff` 边界。
- [ ] 运行 `sim/run_tests.ps1 -Test riscv_muldiv`，确认失败。
- [ ] 实现 signed/unsigned 乘法结果选择和 `MEXT_START/MEXT_WRITEBACK` 路径。
- [ ] 运行 `riscv_muldiv` 和 `riscv_core`，确认普通 RV32I 不回归。
- [ ] 提交：`git add rtl/cpu/riscv_muldiv.sv rtl/cpu/riscv_decoder.sv rtl/cpu/riscv_core.sv tb/cpu/tb_riscv_muldiv.sv; git commit -m "feat: add rv32m multiply operations"`。

### Task 4: RV32M 除法与余数

**Files:**
- Modify: `rtl/cpu/riscv_muldiv.sv`
- Modify: `rtl/cpu/riscv_core.sv`
- Modify: `tb/cpu/tb_riscv_muldiv.sv`

**Interfaces:**
- 复用 Task 3 的 `start/busy/done/result` 接口。
- 除法为可综合的 32 次迭代状态机，支持 signed/unsigned quotient/remainder。

- [ ] 在测试中先加入 `DIV/DIVU/REM/REMU`、负数、除零和 `32'h8000_0000 / -1` 用例，确认失败。
- [ ] 实现 unsigned restoring/non-restoring 核心、符号修正和特殊情况；保持 `busy` 直到 `done`。
- [ ] 将 core 的 M 扩展等待状态接入除法器，运行 `riscv_muldiv` 单测通过。
- [ ] 运行完整 CPU 单测，确认 M 扩展期间 memory request 不重复发起。
- [ ] 提交：`git add rtl/cpu/riscv_muldiv.sv rtl/cpu/riscv_core.sv tb/cpu/tb_riscv_muldiv.sv; git commit -m "feat: add rv32m divide and remainder"`。

### Task 5: IRQ Controller APB 单元

**Files:**
- Create: `rtl/common/irq_controller.sv`
- Modify: `rtl/bus/apb_interconnect.sv`
- Modify: `rtl/top/apb_subsystem.sv`
- Test: `tb/peripheral/tb_irq_controller.sv`
- Modify: `sim/run_tests.ps1`

**Interfaces:**
- APB slave base `0x4000_7000`，寄存器 `ENABLE/PENDING/CLEAR/STATUS`。
- 输入 `timer_irq/dma_irq/uart_irq`，输出 `irq_timer/irq_external`。

- [ ] 写 APB 失败测试，覆盖 enable、pending、RW1C clear、mask 和未映射 offset。
- [ ] 运行 `sim/run_tests.ps1 -Test irq_controller`，确认失败。
- [ ] 实现 sticky pending latch、enable mask 和 Timer 单独输出/外部 IRQ 汇聚。
- [ ] 接入 APB interconnect/subsystem，运行 `tb_irq_controller` 通过。
- [ ] 提交：`git add rtl/common/irq_controller.sv rtl/bus/apb_interconnect.sv rtl/top/apb_subsystem.sv tb/peripheral/tb_irq_controller.sv sim/run_tests.ps1; git commit -m "feat: add apb interrupt controller"`。

### Task 6: 外设 IRQ 源

**Files:**
- Modify: `rtl/dma/dma_controller.sv`
- Modify: `rtl/peripheral/uart/uart_regs.sv`
- Modify: `rtl/peripheral/uart/uart_top.sv`
- Modify: `rtl/top/apb_subsystem.sv`
- Modify: `tb/top/tb_soc_dma.sv`
- Create: `tb/peripheral/tb_uart_irq.sv`

**Interfaces:**
- DMA 新增 `irq` 输出，完成/config/bus error 任一 sticky 状态时有效。
- UART 新增 `irq` 输出，RX 非空或 sticky RX error 时有效，控制寄存器新增 IRQ enable 位。

- [ ] 先扩展测试：DMA Done 产生 IRQ；UART 接收一个字节后产生 IRQ，读取数据/清错误后解除 IRQ。
- [ ] 运行对应测试确认失败。
- [ ] 实现 DMA IRQ level 输出，不改变现有状态和 RW1C 语义。
- [ ] 实现 UART IRQ enable、RX-not-empty/error 条件和顶层连接。
- [ ] 运行 `tb_soc_dma`、`tb_uart_irq` 和原 UART 回归。
- [ ] 提交：`git add rtl/dma/dma_controller.sv rtl/peripheral/uart/uart_regs.sv rtl/peripheral/uart/uart_top.sv rtl/top/apb_subsystem.sv tb/top/tb_soc_dma.sv tb/peripheral/tb_uart_irq.sv; git commit -m "feat: expose dma and uart interrupt sources"`。

### Task 7: SoC CPU IRQ 集成

**Files:**
- Modify: `rtl/top/soc_top.sv`
- Modify: `rtl/cpu/riscv_core.sv`
- Modify: `tb/top/tb_soc_irq.sv`
- Create: `tb/top/tb_soc_rv32im.sv`

**Interfaces:**
- `soc_top` 内部连接 `irq_controller` 输出到 `riscv_core`；外部 CPU 模式下新增 IRQ 状态仍可通过 APB 读取。
- 内部 CPU 复位后程序从 BRAM 运行，设置 `mtvec/mstatus/mie` 后响应 Timer/External IRQ。

- [ ] 写 SoC 失败测试：BRAM 程序设置 trap handler，Timer 到期后 handler 写 GPIO；DMA Done 触发外部 handler。
- [ ] 运行 `soc_irq`/`soc_rv32im`，确认失败。
- [ ] 接线 `soc_top` 的 Timer/DMA/UART/IRQ controller/CPU，并补充 audio_clk/audio_rst_n 的旧 testbench 默认连接兼容。
- [ ] 运行 `tb_soc_irq` 和 `tb_soc_rv32im`，验证中断返回、GPIO 可观察结果和 M 指令。
- [ ] 提交：`git add rtl/top/soc_top.sv rtl/cpu/riscv_core.sv tb/top/tb_soc_irq.sv tb/top/tb_soc_rv32im.sv; git commit -m "feat: integrate rv32im interrupts into soc"`。

### Task 8: 完整验证与文档

**Files:**
- Modify: `sim/run_tests.ps1`
- Create: `docs/verification/phase8-rv32im-csr-interrupt.md`
- Modify: `FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md`

- [ ] 执行 `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all`，记录所有 PASS 测试名和 Icarus warning。
- [ ] 执行 `$rtl = rg --files rtl -g '*.sv'; iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl` 和同样命令的 `-s soc_top` elaboration，确认退出码 0。
- [ ] 在验证文档中记录 CSR、Trap、中断寄存器、M 扩展语义、测试命令和已知边界。
- [ ] 更新项目状态，把 RV32IM/CSR/Timer-DMA-UART IRQ 标为已实现，把完整 PLIC/CLINT 标为非目标。
- [ ] `git diff --check`、`git status --short` 后提交：`git add sim/run_tests.ps1 docs/verification/phase8-rv32im-csr-interrupt.md FPGA_RISC_V_Audio_SoC_Project_Plan.md; git commit -m "docs: verify rv32im csr and soc interrupts"`。

## 验收标准

完成后必须满足：

1. 旧测试全部通过，新增 CSR、Trap、M 扩展、IRQ 和 SoC 测试全部输出 `PASS`。
2. RV32IM 程序能执行乘除法并通过 `MRET` 从 Timer/External interrupt 返回。
3. DMA、UART 和 Timer 中断能够被 APB 配置、被 CPU 感知并按状态寄存器清除。
4. `mtvec==0` 时旧非法指令 fault 流程不变。
5. `git diff --check` 无错误，顶层 `soc_top` 和 `apb_subsystem` elaboration 成功。
