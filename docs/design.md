# Design: engineering-domain libraries for SysML v2

## Motivation

These libraries replace [Tessera](https://github.com/jackhale98/Tessera), a
YAML-based engineering-artifact manager covering requirements, risks,
tolerances, and quality data. Tessera worked, but it reinvented things SysML v2
already standardizes — entity schemas, links, traceability — and its hardest
maintenance problems came from duplicating data that a modeling language
resolves by reference:

- Stackup contributors *cached* feature dimensions and needed `validate --fix`
  to re-sync them. Here a contributor's `dim` is **bound through a feature
  chain** (`:>> dim = housing.depth;`) — retolerancing the feature
  retolerances every stackup that uses it. There is nothing to sync.
- RPN was stored next to its factors and could disagree with them. Here RPN is
  a `calc def` — derived, never stored.
- Links (`verified_by`, `satisfied_by`) were a parallel bookkeeping system.
  Here they are the standard `satisfy`/`verify` relationships that any SysML
  tool — and any generic traceability command — already understands.

## Architecture: semantics in the model, math in the tool

The split is strict:

- **Domain vocabulary → SysML v2 libraries** (this repo). Only standard
  mechanisms: `attribute def`, `item def`, `connection def`, `analysis def`,
  `occurrence def`, `metadata def`, `calc def`, `enum def`, `view def`,
  `assert constraint`. No annotations that require a specific tool.
- **Generic primitives → tools.** A tool that implements calc evaluation,
  uncertainty propagation, and view rendering gets *all* of these domains (and
  future ones) without domain-specific code. A tool that implements none of
  them still parses, navigates, and diagrams the models.

The no-lock-in claim is structural: another vendor could implement the same
three primitives against these libraries and reproduce the behavior, because
the behavior is specified by the model, not by our binary.

### The analyzer contract (`Uncertainty` package)

An uncertainty analyzer evaluates an `UncertaintyAnalysis` (or any calc over
`UncertainValue` inputs) by one of three methods:

| Method | Semantics |
|---|---|
| `worst-case` | Interval arithmetic over `[nominal - minus, nominal + plus]` |
| `rss` | Linear variance propagation; per-input sigma = `(plus + minus) / sigmaLevel` (default 6.0 = ±3σ process); reports mean, 3σ, Cp/Cpk, yield, per-input sensitivity |
| `monte-carlo` | Sample each input from its `distribution` (`normal`, `uniform`, `triangular`); reports mean, σ, yield, percentiles, Pp/Ppk; the seed used must be recorded (audit trails) |

`meanShiftK` (Bender factor) shifts the RSS mean `k·σ` toward the nearest
specification limit; 1.5 is the automotive convention. Pass/fail comes from the
analysis's `target : LimitRange`.

For a `Tolerancing::ToleranceStackup`, the evaluated expression is the signed
sum of contributions (sign from each contribution's `sense`). Contributors are
declared by subsetting the inherited `contributions` collection; analyzers must
also accept plain `Contribution`-typed attributes.

Units: dimension values are `Real`s interpreted in the dimension's `unit`
attribute (default `"mm"`). All dimensions in one chain must agree; analyzers
should check and convert. A future revision may move to quantity-typed values
(`ISQ`/`SI`) once cross-tool support for quantity arithmetic is dependable.

### Reports

`view def`s in the libraries (`FmeaWorksheet`, `RiskMatrix`, `StackupSummary`,
`FitTable`) document standard tabular renderings. A report engine renders a
view by querying the model (e.g. all `@Fmea` annotations), computing derived
columns via calcs (RPN), and applying the documented sort/pivot. Users can add
their own `view def`s; nothing distinguishes library views from user views.

## Dogfooding findings

Building these libraries against our own toolchain surfaced two cross-file
resolution bugs in sysml-cli (both fixed there, with regression tests):

1. Subsetting an inherited member across an import
   (`attribute x :> contributions` where `contributions` lives on an imported
   `analysis def`) raised a false W004 — the resolver exposed imported
   *definitions* but not imported *members*.
2. `@Fmea` annotations raised a false W013 camelCase note — metadata
   annotation usages take the metadata def's PascalCase name by design, and
   the lint's shadowing exception only looked at same-file defs.

Validation runs both implementations on every file: `sysml check` (semantic:
resolution, constraints, lints) and `tree-sitter-sysml` (independent syntax
check). CI-friendly via `make check`.

## Tessera migration map

| Tessera entity | Library construct |
|---|---|
| CMP / ASM | `part def` / `part` (native SysML) |
| FEAT + dimensions | `GeometricFeature` item + `ToleratedDimension` attributes |
| FEAT GD&T controls | `FeatureControlFrame` attributes |
| MATE | `Mate` connection; fit via `MinClearance`/`MaxClearance` calcs |
| TOL stackup | `ToleranceStackup` analysis with feature-chain contributions |
| RISK (FMEA) | `@Fmea` annotation on the affected element |
| HAZ | `Hazard` occurrence |
| Mitigation | `Mitigation` action + `satisfy`; verification via `verify` |
| REQ / TEST | native `requirement` / `verification` (already in SysML) |
| Status/priority/tags | `metadata def` annotations (future `ProjectMetadata` package) |

A one-time converter from Tessera YAML to these libraries is planned in the
sysml-cli repo (Tessera's own `tdt export sysml` is the starting point).

## Roadmap

- **Phase 2 (tooling)**: generic uncertainty analyzer + report engine in
  sysml-cli (`sysml analyze --method ...`, `sysml report <view>`), math ported
  from Tessera's tested Rust implementation.
- **GD&T depth**: bonus tolerance (MMC/LMC) contributions to stackups.
- **3D chains**: small-displacement-torsor analysis over `Frame3D` placements —
  the one genuinely tool-side solver; models stay declarative.
- **`QualityManagement` package**: manufacturing processes, control plans,
  NCR/CAPA loop (Tessera's PROC/CTRL/NCR/CAPA).
- **`ProjectMetadata` package**: status workflow, priority, ownership
  annotations.
- **Editor support**: sysml-mode snippets and completion for the library
  vocabulary.
