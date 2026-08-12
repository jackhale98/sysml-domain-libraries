# SysML v2 Domain Libraries

Engineering-domain vocabulary for SysML v2, written as **pure, standard-conformant
`.sysml` model libraries**: dimensional tolerancing and GD&T, tolerance stackup
analysis, FMEA and hazard analysis.

There is no code in this repository — only SysML v2 packages and examples. Any
conformant SysML v2 tool can parse and use these models. Tools that additionally
implement three *generic* primitives get executable analysis on top:

| Generic primitive | What it does | Example use here |
|---|---|---|
| Calc evaluation | Evaluate any `calc` usage, resolving inputs through feature chains | RPN, fit clearance, stackup nominal |
| Uncertainty propagation | Evaluate a calc/analysis by worst-case, RSS, or Monte Carlo when inputs are `UncertainValue`s | Tolerance stackups, budgets with uncertainty |
| Model-defined reports | Render `view def`s as tables/pivots | FMEA worksheet, risk matrix, stackup summary |

The [sysml CLI](https://github.com/jackhale98/sysml-cli) implements these
primitives; the domain semantics stay entirely in the model, so no tool —
including ours — is load-bearing.

## Packages

- **`Uncertainty`** (`libraries/Uncertainty.sysml`) — the analyzer contract:
  `UncertainValue` (nominal + asymmetric bounds + distribution), `LimitRange`
  (LSL/nominal/USL targets), and `UncertaintyAnalysis` (sigma level, Bender
  mean shift, Monte Carlo iterations and seed).
- **`Tolerancing`** (`libraries/Tolerancing.sysml`) — toleranced dimensions,
  geometric features, ASME Y14.5 feature control frames, mates as
  `connection def`s with fit calcs, and `ToleranceStackup` analyses whose
  contributors *reference* feature dimensions through feature chains — one
  source of truth, nothing to keep in sync.
- **`HazardAnalysis`** (`libraries/HazardAnalysis.sysml`) — top-down hazard
  analysis aligned with the OMG RAAML Core concepts and ISO 14971 /
  MIL-STD-882E: `Harm` (carries the severity classification),
  `Hazard`, `HazardousSituation` (P1/P2 probabilities), `Causation` links
  between risk events, and `RiskControl` requirement obligations with the
  ISO 14971 control hierarchy.
- **`RiskAnalysis`** (`libraries/RiskAnalysis.sysml`) — bottom-up FMEA on the
  AIAG/VDA 1–10 scales with RPN as a derived calc (never stored, never
  stale), `@Fmea` worksheet annotations, structural `FailureMode` occurrences
  that join HazardAnalysis causal chains, and mitigations traced with
  standard `satisfy`/`verify`. Hazard analysis drives the FMEA: a failure
  mode linked to a hazard derives its severity from the harm at the end of
  the causal chain.

## Examples

- `examples/EnclosureGap.sysml` — a sealed-enclosure gap stackup: three parts,
  a pilot-bore mate with expected fit, and a critical stackup with a Bender
  mean-shift factor.
- `examples/BatteryFmea.sysml` — hazard-driven battery-pack FMEA: a causal
  chain from failure mode through hazard and hazardous situation to harm,
  worksheet lines checked against the harm's severity anchor, and a risk
  control implemented by a mitigation, satisfied by the BMS, and verified by
  test.
- `examples/ReliefValve.sysml` — the user guide's running example: a
  pressure relief valve where a critical travel-gap stackup is the evidence
  behind an inherent-safety risk control against an overpressure hazard.

## Using the libraries

Copy `libraries/` into your project (or add it to your tool's import path) and
import what you need:

```sysml
private import Tolerancing::*;

part def Housing {
    item bore : GeometricFeature {
        :>> form = FeatureForm::hole;
        :>> nature = FeatureNature::internal;
        attribute diameter : ToleratedDimension {
            :>> nominal = 10.0; :>> plus = 0.1; :>> minus = 0.05;
        }
    }
}
```

With the sysml CLI, `sysml init` picks up a `libraries/` directory
automatically.

## Validation

Every file is validated against two independent implementations on every
change:

```sh
make check     # sysml check (semantic) + tree-sitter-sysml (syntactic)
```

Requires [`sysml`](https://github.com/jackhale98/sysml-cli) on PATH; the
tree-sitter pass runs when a built
[tree-sitter-sysml](https://github.com/jackhale98/tree-sitter-sysml) checkout
is found (see `scripts/validate.sh`).

## Documentation

- **[User guide](docs/guide.md)** — from an empty directory to a validated
  model where a tolerance stackup is the evidence behind a safety risk
  control, with no SysML v2 experience assumed. Its running example is
  [`examples/ReliefValve.sysml`](examples/ReliefValve.sysml).
- **[Design](docs/design.md)** — the architecture: why the domain semantics
  live in model libraries instead of tool code, the analyzer contract, and
  the roadmap (GD&T bonus tolerance, 3D torsor chains, FTA/STPA,
  manufacturing quality loop).

## License

MIT — these are model libraries meant to be imported into your designs;
permissive licensing is the point.
