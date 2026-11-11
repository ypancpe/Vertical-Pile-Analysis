# navfac_general — generalized NAVFAC DM-7.02 axial pile capacity + Vesic settlement

A clean, fully parameterized MATLAB/Octave package for the NAVFAC DM-7.02 axial
method (the method ALLPILE uses): side friction + tip bearing + uplift + Vesic
(1977) settlement. It generalizes the validated `../navfac/` implementation
(all project-specific constants removed) and carries over — and extends — the
input/output/logging system of `../reissner/` (per-case input files, rich
per-layer debug struct, per-layer CSV export). Both sibling packages are left
untouched.

Works for any round or square pile, any embedment/water table, and any number
of soil layers (each layer sand XOR clay).

## Method (NAVFAC DM-7.02)

| Piece | Formula |
|---|---|
| Side, sand | `f = K * sigma_v * tan(delta)`, `delta = Kf * phi` (or a per-layer `delta_deg` override); `K = K_down` (compression) / `K_up` (uplift). Within `z_crit`, each segment uses the exact length-average `sigma_v` (= the classic midpoint value unless the water table cuts the segment) |
| Side, clay | `Ca = Kc * Ka * cu` (same value down and up) |
| Critical depth | `sigma_v` capped at its value at `z_crit = PR * D` — applied to BOTH side friction and tip bearing |
| Tip, sand | `qp = Nq * sigma_v(@min(embed, z_crit))`, `Nq` from Table 8-1 (displacement vs non-displacement) |
| Tip, clay | `qp = Nc * cu`, `Nc` from Table 8-2 (function of z/B, max 9.0) |
| Caps | optional absolute `f_limit` / `q_limit` (off by default) |
| Uplift | `Qup_ult = Qside_up + W`, `W` = buoyant weight of the embedded pile (negative for timber lighter than water) |
| Allowable | `down = Qtip/FS_tip + Qside/FS_side`; `up = Qside_up/FS_uplift + W/FS_weight` (ALLPILE manual 8.1.1.7) |
| Settlement (max) | Vesic (1977) at ULTIMATE resistance — an **upper bound**: `X_max = Xs + Xpp + Xps`, `Cp` from Table 8-3 |
| Settlement (applied) | at `Q = inp.Q_applied` (compression > 0, **uplift < 0**), by `par.settle_method`: **`'allpile'`** (default) — ALLPILE's load-settlement relation from the Reese & O'Neill t-z/q-w curves scaled by the Vesic settlement; or `'vesic_linear'` — shaft-first split + linear Vesic terms. Reported only when `Q_applied` is set |

**Two settlements, and what they mean.** `X_max` is the Vesic settlement at
**ultimate** resistance — the *maximum* that could occur (an upper bound),
**not** the service settlement. `s_applied` is the settlement under the
applied working load.

**`s_applied`, `settle_method = 'allpile'` (default).** This is ALLPILE 7's
"LOAD - TOTAL SETTLEMENT RELATION (from t-z, and q-w curves) — Based on Vesic
Method" (Advanced page, *Option 2*), reconstructed from ALLPILE's own output
and verified on all 17 benchmark runs (see *Validation against ALLPILE*):

- the Reese & O'Neill normalized curves for cohesionless soil (ALLPILE manual
  Figs 8-3 side, 8-5 base) are expressed in `u = movement / X_max` and
  stepped over ALLPILE's 100-point grid (`ng_lt_curves`);
- **compression**: `Xtip = u·X_max`, `Qtip = R_tip(u)·Qtip_ult`,
  `Qside = R_side(u)·Qside_ult`, shaft compression
  `Xshaft = (Qtip + 0.5·Qside)·Le/(A·E)` (+ the full load over any stick-up),
  `Xtop = Xtip + Xshaft`;
- **uplift**: the pile moves as a rigid body, `Xtop = −u·X_up_max` with
  `X_up_max = Xs_up + Xps_up`, and `Qtotal = R_side(u)·(Qside_up + W) + W`;
- the work-load settlement is a linear interpolation of `Xtop` against
  `Qtotal` at `Q_applied`, as ALLPILE does. Upward movement is negative.
  A load above the curve's peak gives NaN and a warning (ALLPILE prints 99999).

Both `s_allpile` and `s_vesic_linear` are always reported; `s_applied` is
the selected one. Known limits of the `'allpile'` method:

- **Cohesive soil.** ALLPILE uses separate cohesive curves (Figs 8-2/8-4) that
  the benchmark doesn't cover, so they aren't included. With clay along the
  pile the cohesionless curves are used and a `navfac_general:ltCohesive`
  warning says so.
- **Stick-up.** None of the benchmark runs has one, so behaviour with a
  free length (full load carried above grade) is an extrapolation, not a
  verified match.
- **Heavy piles in uplift.** ALLPILE's uplift table counts the pile weight
  `W` twice (in the mobilized side *and* in the total). That is reproduced
  as-is. For piles lighter than water (`W < 0`, timber) it is immaterial; for
  heavy piles (`W > 0`, concrete) the uplift table can exceed `Qup_ult`.

**`s_applied`, `settle_method = 'vesic_linear'`.** The earlier linear
estimate, compression only. The load is split **shaft-first** —
`Qws = min(Q, Qside)`, `Qwp = Q − Qws` — then `s1 = (Qwp + xi·Qws)·L/(Ap·Ep)`,
`s2 = Cp·Qwp/(D·qp)`, `s3 = Cs·Qws/(Le·qp)`. For any `Q ≤ Qside` the point
term `s2` is exactly zero. It runs 11–17 % above ALLPILE on the benchmark.

## Parameters, defaults, and sources

All of these live in the input/config — **nothing is hardcoded in the calc
functions**. Full documentation in [ng_defaults.m](ng_defaults.m).

| Parameter | Default | Units | Source / notes |
|---|---|---|---|
| `par.K_down` | 1.0 | – | NAVFAC DM-7.02 earth-pressure coeff. K_HC; driven displacement pile range 1.0–1.5 (H-pile 0.5–1.0, tapered 1.5–2.0, jetted 0.4–0.9, bored 0.7) |
| `par.K_up` | 0.7 | – | NAVFAC K_HT; driven displacement pile range 0.6–1.0 (H-pile 0.3–0.5, tapered 1.0–1.3, jetted 0.3–0.6, bored 0.4) |
| `par.Kf` | 0.75 | – | `delta = Kf*phi`; NAVFAC: concrete/timber `delta = 3/4*phi`; steel `delta = 20°` constant — use the per-layer `layers(i).delta_deg` override (a single `Kf = 20/phi` is exact only for uniform-phi profiles) |
| `par.Kc`, `par.Ka` | 1.0, 1.0 | – | clay adhesion `Ca = Kc*Ka*cu`; reduce per an adhesion table if warranted |
| `par.PR` | 20 | – | critical-depth ratio, `z_crit = PR*D`; customary 10–20, 20 = ALLPILE/NAVFAC deep-pile default |
| `par.FS_tip/_side/_uplift` | 3.0 | – | NAVFAC DM-7.02, static analysis without load test |
| `par.FS_weight` | 1.0 | – | factor on the pile weight `W` in the allowable uplift, `Qside_up/FS_uplift + W/FS_weight` (ALLPILE's default and formula) |
| `par.f_limit`, `par.q_limit` | NaN (off) | psf | absolute caps on unit side/tip resistance |
| `par.Cp` | NaN (auto) | – | Vesic Table 8-3 via [ng_cp_table.m](ng_cp_table.m): sand driven 0.02–0.04 (mid 0.03), sand bored 0.09–0.18; clay driven 0.02–0.03, clay bored 0.03–0.06 (range midpoints) |
| `par.settle_dz` | 0.05 | ft | slice size for the axial-shortening integration |
| `par.settle_method` | 'allpile' | – | `'allpile'` (ALLPILE t-z/q-w, compression + uplift) or `'vesic_linear'` (shaft-first linear Vesic, compression only); selects `s_applied` |
| `par.xi` | 0.6 | – | Vesic shaft-shortening coeff. in `s1` (`'vesic_linear'` only); range 0.5 (uniform side load) – 0.67 (triangular). `'allpile'` uses ALLPILE's fixed 0.5 |
| `pile.pile_type` | 'displacement' | – | 'displacement' (driven) / 'nondisplacement' (bored); selects Nq and Cp columns |
| `pile.water_table_ft` | 0 | ft | depth below surface; 0 = at/above surface |
| `pile.gamma_w` | 62.4 | pcf | water unit weight for pile buoyancy (64.0 seawater) |
| `Q_applied` (top-level) | NaN (skip) | lb | applied axial load for the service-settlement check, ALLPILE's sign: **compression > 0, uplift < 0**; NaN/absent ⇒ only `X_max` is reported, while `0` still runs the block and reports `s_applied = 0`; a load `≥` the ultimate capacity in its direction warns |

Units throughout: depths/lengths **ft**, pile size **in**, unit weights
**pcf**, stress/strength **psf**, `phi` **deg**, pile modulus `E` **psi**,
forces **lb** internally (printed in kips), settlement **in**.

## File map

```
navfac_general/
├── README.md
├── pile_calc.m            driver: run ONE case (edit the input name at top)
├── pile_calc_batch.m      driver: run MANY/ALL cases, comparison table + batch CSV
├── ng_run_case.m          orchestrator: load → defaults → validate → compute → print → CSV
├── ng_defaults.m          all defaults, documented (the only place defaults live)
├── ng_apply_defaults.m    merge user input over defaults (warns on typo'd par/opts/pile fields)
├── ng_validate_input.m    input validation with specific error messages
├── ng_capacity.m          NAVFAC side + tip + uplift, returns [cap, dbg]
├── ng_unit_side_friction.m unit f (down/up) for one layer — shared by capacity & settlement
├── ng_vertical_stress.m   effective-stress profile (vectorized, exact)
├── ng_nq_table.m          Table 8-1 Nq (warns + clamps outside 26–40°)
├── ng_nc_table.m          Table 8-2 Nc(z/B)
├── ng_cp_table.m          Table 8-3 Vesic Cp (range midpoints)
├── ng_settlement_vesic.m  Vesic (1977) settlement: ultimate bound X_max + applied-load s_applied
├── ng_load_transfer.m     ALLPILE t-z/q-w load-settlement tables + work-load settlement
├── ng_lt_curves.m         normalized load-transfer curves (cohesionless), ALLPILE grid
├── ng_pile_geometry.m     round/square A & P (+ optional A/P overrides, e.g. H-pile)
├── ng_layer_at.m          layer index containing a depth
├── ng_print_results.m     console summary + per-layer debug table
├── ng_write_csv.m         struct-array → CSV (Octave-safe; no writetable)
├── ng_summary_row.m       one-row case summary (per-case + batch CSVs)
├── inputs/
│   ├── input_template.m   copy/rename to add a case (fully documented)
│   └── input_example_timber.m  worked example
├── outputs/               created at runtime: layer_results_<case>.csv,
│                          summary_<case>.csv, batch_summary.csv
└── tests/
    ├── run_all_tests.m        run the whole suite
    ├── test_regression_P1.m   P-1 vs ALLPILE regression (the proof)
    ├── input_P1_regression.m  frozen P-1 fixture — do not edit
    ├── test_validation.m      validation errors, warnings, generalization checks
    ├── test_allpile_benchmark.m  all 17 ALLPILE runs vs the package
    ├── allpile_benchmark_cases.m ALLPILE inputs + results (generated from the outputs)
    └── ci_run.m               headless runner (writes ci_run.log + ci_done.txt)
```

## How to add a case

1. Copy `inputs/input_template.m` → `inputs/input_myCase.m`; rename the
   function inside to match the file name.
2. Fill in the pile block and the soil layers (contiguous from depth 0, deep
   enough to cover the tip; each layer `phi` XOR `cu`). Override any `par.*`
   you need — everything else uses the documented defaults. Optionally set
   `inp.Q_applied` (applied load [lb], compression > 0 / uplift < 0) to also
   get the service-load settlement `s_applied` alongside the ultimate bound
   `X_max`.
3. Run it:
   ```matlab
   >> results = ng_run_case('input_myCase');   % or edit + run pile_calc.m
   ```
   Console shows the capacity/settlement summary plus a per-layer debug table;
   `outputs/layer_results_input_myCase.csv` gets the full per-layer log
   (z1/z2, soil type, within/beyond-critical split, sigma_v, delta or Ca, unit
   f and dQs for both down and up, running totals) and
   `outputs/summary_input_myCase.csv` the one-row summary.
   `results.dbg` holds the same data as structs.
4. Batch: `>> pile_calc_batch` runs every `inputs/input_*.m` (except the
   template) and writes `outputs/batch_summary.csv`.

## How to run the regression test

```matlab
>> cd tests
>> run_all_tests          % or just: test_regression_P1
```

Headless (no GUI):

```
matlab -wait -batch "run('<path>\navfac_general\tests\ci_run.m')"   % log: tests/ci_run.log
octave --eval "cd('<path>/navfac_general/tests'); run_all_tests"
```

`test_regression_P1` runs the frozen P-1 fixture — 10-in round timber
displacement pile, 24 ft embedment, the B-7 sand profile, with the exact
ALLPILE Setup/Advanced values (`K_down=1.8, K_up=0.7, Kf=0.8, PR=20, FS=3,
Cp=0.03`) — and asserts the ALLPILE-validated results within 0.5 %:

| item | ALLPILE [kips] |
|---|---|
| side resistance (down) | 42.722 |
| tip resistance | 52.467 |
| total ultimate (down) | 95.189 |
| side resistance (up) | 16.614 |
| total ultimate (up) | 16.278 |

Those project-specific parameter values exist **only** in the test fixture;
package defaults are the generic NAVFAC values above. The test proves the
generalization didn't change the physics.

`test_validation` covers the input checks (layer gaps/overlaps, both-φ-and-cu,
uncovered tip, bad shapes/types), the out-of-range-Nq warning (warn + clamp,
never silent extrapolation), and generalization behaviors (square piles, clay
tips, critical-depth capping, water table below grade, f/q limits,
non-displacement piles).

## Validation against ALLPILE

`test_allpile_benchmark` runs all 17 ALLPILE 7 vertical analyses in
`Foundation\Test Cases - Allpile` (Cristobal Pier: 11 timber piles, 5 distinct
soil profiles, compression and uplift work loads) through the package and
checks every output it reproduces. The fixture `allpile_benchmark_cases.m` is
generated from ALLPILE's `0summary.txt` / `0detail.txt` and passes ALLPILE's
own inputs, including its stored section values (A = 78.5 in², P = 31.4 in)
and pile weight per foot (0.020 kip/ft → `SW = 20/A`).

| Output | Agreement with ALLPILE (17 runs) |
|---|---|
| side resistance down / up, tip, ultimate down / up, allowable down | ≤ 0.13 % |
| allowable uplift | ≤ 0.07 % |
| pile weight W | within ALLPILE's 2-decimal print |
| Vesic Xs, Xpp, Xps, X_max at ultimate | every printed digit |
| work-load settlement, compression (13 runs) | ≤ 0.35 % |
| work-load movement, uplift (4 runs) | every printed digit |

The ≤ 0.13 % capacity residual is ALLPILE's numerics: it sums side friction
over a fixed 500-node grid, while the package integrates each layer exactly.
The residual doesn't follow any single discretization rule and is below what
the printed inputs can resolve, so it is left as is.

## Octave compatibility

No tables/`writetable`, no `string` class, no `arguments` blocks — plain
structs, `fprintf`, and `interp1` only, so the suite runs under GNU Octave
(tested style; CSV writing is hand-rolled in `ng_write_csv.m`).

## Changes in v3

Carried over from the v2 package, with four fixes:

1. **Applied-load split is now shaft-first, and committed to.** v2 had a
   half-finished edit: the proportional split was commented out and replaced
   with a shaft-first one, while the README, the `ng_settlement_vesic`
   docstring and both tests still described and asserted the proportional
   split (so `test_regression_P1` and `test_validation` would have failed).
   The shaft-first model is now the documented, implemented and tested
   behaviour throughout: `Qws = min(Q, Qside)`, `Qwp = Q - Qws`.
2. **`par.Kf` default is 0.75**, matching the documented NAVFAC
   `delta = 3/4*phi` for concrete/timber piles. v2 documented 0.75 but shipped
   0.8. `inputs/input_10in_LJ.m` now sets `Kf = 0.80` explicitly, so that
   case's results are unchanged by the new default.
3. **Stale CSVs removed from `outputs/`.** v2 shipped a `batch_summary.csv`
   generated before the settlement edit and before the second case existed.
   Everything in `outputs/` is generated - run `pile_calc_batch` to rebuild it.
4. **`inputs/input_example_timber.m` now matches its own description** - it
   really does have a water table below grade (4 ft) and a clay interbed
   (15-20 ft), so the clay side-friction and split-unit-weight paths are
   exercised by the shipped example, not just by the test suite.

### ALLPILE benchmark update (2026-11-04)

Checked against the 17 ALLPILE runs in `Test Cases - Allpile` and changed in
place (see *Validation against ALLPILE*):

1. **Allowable uplift now follows ALLPILE**: `Qside_up/FS_uplift +
   W/FS_weight` (new `par.FS_weight`, default 1.0), replacing
   `Qup_ult/FS_uplift`. It had run 4–6 % high on every run.
2. **Work-load settlement now reproduces ALLPILE** (new default
   `par.settle_method = 'allpile'`, new `ng_load_transfer.m` /
   `ng_lt_curves.m`). The shaft-first linear Vesic estimate, which had run
   11–17 % high, is kept as `'vesic_linear'` and still reported as
   `s_vesic_linear`.
3. **Uplift work loads are now accepted**: `Q_applied < 0`, ALLPILE's sign
   convention, giving an upward (negative) movement.
4. New outputs: `X_up_max`, `s_allpile`, `s_vesic_linear`, `Kqx` (secant
   stiffness, as ALLPILE prints) and the full load-settlement tables in
   `results.settlement.lt`.

Capacities and the Vesic settlement at ultimate already matched ALLPILE and
are unchanged.

Only the navfac side changed between v1, v2 and v3; the sibling `reissner/`
package is byte-identical across all three.
