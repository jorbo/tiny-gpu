# Historical TT evidence

| Location | Previous location / meaning |
|---|---|
| `runs/` | Root `runs/`: all retained sweeps, gated/ungated candidates, PT reports. |
| `runs/lh_2.55_cg/` | Recorded clock-gated baseline; distinguish pre-DC-ECO and post-PT-ECO data. |
| `initial_rvt/` | Root `reports/`: original RVT 10 ns mapping point. |
| `initial_multi_vt/` | Root `reports_hvt/`: earlier multithreshold reports. |
| `inputs/gpu.v` | Tracked converted RTL formerly in `build/gpu.v`. |
| `activity/` | Tracked RTL/gate VCDs formerly in `build/`, including compressed traces. |
| `flow_snapshot/syn/` | Exact original flow scripts before local path reorganization. |

Payload bytes were preserved, including historical paths in logs/netlists and
original flow scripts. The selected TT baseline's earlier capacitance/import
warnings remain part of its evidence; these archives do not establish SS closure.
