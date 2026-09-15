# 16-bit LBIST/BISR Ripple-Carry Adder

這是一個以 Verilog-2001 實作的 16-bit ripple-carry adder，整合
Logic Built-In Self-Test（LBIST）、故障定位與 Built-In Self-Repair（BISR）。

## Features

- 16 個主要 full adders 與 1 個 spare full adder
- 33-bit LFSR 產生 `X`、`Y` 與 `Cin` 測試向量
- 17-bit MISR 壓縮 `{Cout, Sum}` response
- 64-cycle LBIST 與 golden signature 比對
- 支援 16 個 carry node 的 stuck-at-0／stuck-at-1 fault injection
- 自動定位 faulty FA，切換 spare FA 後重新執行 LBIST
- Self-checking testbench 掃描全部 32 組故障
- VCS line、condition、branch、toggle、FSM code coverage

## Architecture

```text
                     +--------------------+
                     |   LBIST Controller |
                     +-----+----------+---+
                           |          |
                    control|          |diagnosis/repair
                           v          v
+----------+       +------------------------+       +----------+
| 33-bit   | X/Y/  | 16-bit Ripple Adder    | 17-bit| 17-bit   |
| LFSR     +------>| 16 main FA + 1 spare FA+------>| MISR     |
| PRPG     | Cin   | fault injection/repair |response|          |
+----------+       +------------------------+       +----------+
                                                          |
                                                          v
                                               Golden Signature
```

LFSR state 的位元配置如下：

- `[15:0]`：`X`
- `[31:16]`：`Y`
- `[32]`：`Cin`

MISR polynomial 為 `17'h02001`，64 個測試週期後的 golden signature
為 `17'h1338d`。

## Fault Detection and Repair

1. LFSR 產生 64 組 pseudo-random patterns。
2. MISR 將每個 `{Cout, Sum}` response 壓縮成 signature。
3. Signature 不等於 golden signature 時，controller 進入 diagnosis。
4. 全 0 與全 1 diagnostic patterns 分別定位 stuck-at-1 與 stuck-at-0。
5. Controller 記錄故障種類與 FA index，並將 spare FA 接到故障級。
6. 保持外部故障注入，重新執行完整 LBIST 確認修復結果。

## Repository Structure

```text
.
|-- rtl/
|   |-- Top_Module.v
|   |-- full_adder.v
|   |-- ripple_carry_adder.v
|   |-- lfsr_prpg.v
|   |-- misr_compactor.v
|   `-- lbist_controller.v
|-- tb/
|   |-- TESTINGHW11TB.v
|   `-- WAVE_DEMO_TB.v
|-- scripts/
|   |-- run_coverage.sh
|   `-- run_wave.sh
|-- docs/
|   |-- coverage_summary.txt
|   `-- WAVEFORM_GUIDE.md
|-- filelist.f
|-- filelist_wave.f
|-- cm_hier.cfg
`-- README.md
```

## VCS Simulation

在 repository 根目錄執行：

```sh
vcs -full64 -timescale=1ns/1ps -top TESTINGHW11TB -f filelist.f
./simv
```

預期結果：

```text
TEST PASS: 32/32 faults detected, diagnosed and repaired
```

## Code Coverage

```sh
bash scripts/run_coverage.sh
```

報告會產生在 `build/run_<timestamp>/urg_report/`。目前 regression 結果：

| Metric | Result |
| --- | ---: |
| Line | 100% |
| Condition | 100% |
| Branch | 100% |
| Toggle | 100% |
| FSM | 100% |

## FSDB Waveform Demo

`WAVE_DEMO_TB.v` 將波形分成四個 `Demo_phase`：

| Demo_phase | Section | Description |
| ---: | --- | --- |
| 0 | Normal mode | 外部輸入執行 `16'h1234 + 16'h5678 + 1` |
| 1 | Healthy BIST | 無故障的 64-cycle LBIST |
| 2 | Fault detection | FA13 carry stuck-at-1 注入與偵測 |
| 3 | Repair verification | spare FA 取代 FA13 並重新執行 LBIST |

在 repository 根目錄執行：

```sh
bash scripts/run_wave.sh
```

腳本會產生 `bist_wave.fsdb`，使用 Verdi 開啟：

```sh
verdi -ssf build/wave_<timestamp>/bist_wave.fsdb
```

建議加入波形的訊號：`Demo_phase`、`Test`、`State`、`Cycle_count`、
`Signature`、`Signature_diff`、`Fault_detected`、`Faulty_FA`、
`Fault_type`、`Repair_enable`、`Repair_success`、`PF` 與 `Done`。

實際模擬時間點與 controller state 對照請參考
[`docs/WAVEFORM_GUIDE.md`](docs/WAVEFORM_GUIDE.md)。
