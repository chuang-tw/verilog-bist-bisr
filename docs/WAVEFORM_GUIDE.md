# FSDB Waveform Guide

The waveform demo uses `WAVE_DEMO_TB` and the marker signal `Demo_phase`.
The following times were measured from a passing VCS simulation.

| Time range | Demo_phase | Meaning | Expected result |
| --- | ---: | --- | --- |
| 100–140 ns | 0 | Normal functional mode | `16'h1234 + 16'h5678 + 1 = 17'h068ad` |
| 140–1451 ns | 1 | Healthy 64-cycle LBIST | `Signature=17'h1338d`, `PF=1` |
| 1500–2831 ns | 2 | FA13 carry stuck-at-1 detection | `Fault_signature=17'h1dd39` |
| 2831–4171 ns | 3 | Spare-FA repair verification | `Faulty_FA=12`, final `Signature=17'h1338d` |

Key fault and repair events:

- 1500 ns: enable fault injection with `Fault_select=12` and `fault_value=1`.
- 2810 ns: `Fault_detected` becomes 1.
- 2811 ns: captured faulty signature is `17'h1dd39`.
- 2830 ns: `Repair_enable` becomes 1 and the controller selects FA13.
- 2831 ns: `Demo_phase` changes to repair verification.
- 4150 ns: `PF`, `Repair_success`, and `Done` become 1.
- 4171 ns: repaired functional response is `17'h068ad`.

Run from the repository root:

```sh
bash scripts/run_wave.sh
```

Open the generated file with the path printed by the script:

```sh
verdi -ssf build/wave_<timestamp>/bist_wave.fsdb
```

Recommended waveform signals:

```text
Demo_phase
Test
State
Cycle_count
Signature
Signature_diff
Fault_signature
Fault_detected
Faulty_FA
Fault_type
Repair_enable
Repair_success
PF
Done
X Y Cin Sum Cout
```

Controller state encoding:

| State | Meaning |
| ---: | --- |
| 0 | IDLE |
| 1 | RUN_INITIAL |
| 2 | CHECK_INITIAL |
| 3 | DIAG_SA1 |
| 4 | DIAG_SA0 |
| 5 | INIT_REPAIR |
| 6 | RUN_REPAIR |
| 7 | CHECK_REPAIR |
