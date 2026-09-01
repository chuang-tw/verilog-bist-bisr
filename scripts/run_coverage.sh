#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_DIR="$PROJECT_DIR/build/run_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

vcs -full64 -timescale=1ns/1ps \
    -top TESTINGHW11TB \
    "$PROJECT_DIR/rtl/full_adder.v" \
    "$PROJECT_DIR/rtl/ripple_carry_adder.v" \
    "$PROJECT_DIR/rtl/lfsr_prpg.v" \
    "$PROJECT_DIR/rtl/misr_compactor.v" \
    "$PROJECT_DIR/rtl/lbist_controller.v" \
    "$PROJECT_DIR/rtl/Top_Module.v" \
    "$PROJECT_DIR/tb/TESTINGHW11TB.v" \
    -cm line+cond+branch+tgl+fsm \
    -cm_hier "$PROJECT_DIR/cm_hier.cfg" \
    -cm_dir simv.vdb \
    -l compile.log

./simv -cm line+cond+branch+tgl+fsm -cm_dir simv.vdb -l sim.log
urg -dir simv.vdb -report urg_report -format both

grep -E "^TEST (PASS|FAIL)" sim.log
grep -A4 "Total Hierarchical Coverage Summary" urg_report/dashboard.txt
