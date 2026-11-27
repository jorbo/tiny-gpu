#!/bin/bash
# netlist_shards.sh <name> <run_dir> <period>: one sim.run process per family shard
cd /home/csgrad/szimm011/tiny-gpu/tiny-gpu
export PATH=$HOME/.local/bin:$PATH
N=$1; R=$2; P=$3; M=$PWD/build/saed_models; O=$PWD/build/verification/netlist_$N
mkdir -p $O
SHARDS="R01 R02 R03 R04 R05 R06 R07 R08 R09 R10 A1_01 A1_02 A1_03 A1_04 A1_05 A1_07 A1_10"
CORNERS="--case C01 --case C02 --case C03 --case C04 --case C05 --case C06 --case C07 --case C08 --case C09 --case C10 --case A1_06 --case A1_08 --case A1_09"
run() { python3 -m sim.run --mode netlist --suite all --netlist $R/out/gpu_netlist_eco.v \
  --cell-model $M/saed32nm_lvt.v --cell-model $M/saed32nm_hvt.v --period $P --timeout 300 \
  --out $O/$1 "${@:2}" > $O/$1.log 2>&1; }
for f in $SHARDS; do run $f --case $f & done
run corners $CORNERS &
wait
echo ALL_SHARDS_DONE > $O/DONE
