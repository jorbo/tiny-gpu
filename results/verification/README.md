# RTL regression evidence

`rtl_manifest.json` and `rtl_summary.txt` are the full default `sim/run.py`
corpus at 2.90 ns, run with Icarus Verilog 13.0 and Python 3.9.6:

- 1,039 instances: 100 per random family R01-R10, plus 39 directed corner cases.
- 1,039 pass, 0 fail.
- Testbench: `sim/tb_regression.v`.
- DUT: `gpu.v`, a fresh `sv2v` 0.0.13 conversion of the corrected `rtl/`
  (`make compile`), including the scheduler active-lane PC and CMP N/Z/P fixes.
- Compile log: `rtl_compile.log`.

These results are functional RTL results only. They are not a netlist
regression, a timing signoff, or a power measurement. The archived SS netlist in
`results/ss/` was synthesized before these two fixes.
