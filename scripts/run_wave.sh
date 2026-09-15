#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_DIR="$PROJECT_DIR/build/wave_$(date +%Y%m%d_%H%M%S)"

VERDI_ROOT="${VERDI_HOME:-${NOVAS_HOME:-}}"

if [ -z "$VERDI_ROOT" ]; then
    echo "ERROR: VERDI_HOME or NOVAS_HOME is not set"
    exit 1
fi

PLI_DIR="$VERDI_ROOT/share/PLI/VCS/LINUX64"

if [ ! -r "$PLI_DIR/novas.tab" ] || [ ! -r "$PLI_DIR/pli.a" ]; then
    echo "ERROR: Verdi PLI was not found under $PLI_DIR"
    exit 1
fi

mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

vcs -full64 -debug_all -timescale=1ns/1ps \
    -top WAVE_DEMO_TB \
    "$PROJECT_DIR/rtl/full_adder.v" \
    "$PROJECT_DIR/rtl/ripple_carry_adder.v" \
    "$PROJECT_DIR/rtl/lfsr_prpg.v" \
    "$PROJECT_DIR/rtl/misr_compactor.v" \
    "$PROJECT_DIR/rtl/lbist_controller.v" \
    "$PROJECT_DIR/rtl/Top_Module.v" \
    "$PROJECT_DIR/tb/WAVE_DEMO_TB.v" \
    -P "$PLI_DIR/novas.tab" "$PLI_DIR/pli.a" \
    -l compile.log

./simv -l sim.log

test -s bist_wave.fsdb
test -s bist_wave.vcd
grep -E "^\[WAVE\]|^WAVE DEMO" sim.log
echo "FSDB: $RUN_DIR/bist_wave.fsdb"
echo "VCD:  $RUN_DIR/bist_wave.vcd"
echo "Open: verdi -ssf $RUN_DIR/bist_wave.fsdb"
