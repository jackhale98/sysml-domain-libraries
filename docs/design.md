# Design: engineering-domain libraries for SysML v2

## Motivation

Engineering teams usually manage tolerances, risks, and quality data in
document-centric tools — spreadsheets, per-entity records, PLM forms. Those
tools reinvent what SysML v2 already standardizes (entity schemas, links,
traceability), and their hardest maintenance problems come from duplicating
data that a modeling language resolves by reference:

- Stackup rows restate feature dimensions and drift out of sync with the
  drawings they came from. Here a contributor's `dim` is **bound through a
  feature chain** (`:>> dim = housing.depth;`) — retolerancing the feature
  retolerances every stackup that uses it. There is nothing to sync.
- RPN columns sit next to their factors and can disagree with them. Here RPN
  is a `calc def` — derived, never stored.
- Trace links (verified-by, satisfied-by) are parallel bookkeeping. Here they
  are the standard `satisfy`/`verify` relationships that any SysML tool — and
  any generic traceability command — already understands.

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

### Views are the reports

There is no report engine and no report command. SysML v2's own view
machinery is the reporting mechanism: a `view def` specifies what to include
(`expose` and `filter` expressions — e.g. `filter @RiskAnalysis::Fmea`
selects every annotated element) and names a rendering for how to present
it. A single generic verb (`sysml view <name>`) renders whatever a view def
specifies — tables today, diagrams as the existing diagram machinery folds
in. Every future domain package ships its own views and gets tool support
with zero new commands.

Where the standard goes quiet — column expressions, sort order, pivoting —
the convention is a small `@TableRendering` metadata annotation on the view
def (see `Reporting.sysml` for the full contract), so the table spec stays
in the model and any tool can implement the same behavior. The library view
defs (`FmeaWorksheet`, `RiskMatrix`, `HazardLog`, `StackupSummary`,
`FitTable`, plus the general-purpose views in `Reporting`) carry real specs and
render with `sysml view <name>`. Users add their own `view def`s; nothing
distinguishes library views from user views.

The same move covers scoring policy: `ModelQuality.sysml` declares a
`QualityScore` calc over a fixed parameter vocabulary (`documented`,
`typedUsages`, `reqSatisfied`, `reqVerified`, each 0-100) that
`sysml coverage` evaluates for its overall score. Reweighting the score —
a safety project caring more about verification than doc coverage — is a
model edit, not tool configuration.

## Hazard-driven risk analysis and RAAML alignment

Hazard analysis (top-down) and FMEA (bottom-up) meet through causal links,
and the libraries make that meeting point structural:

- `HazardAnalysis` models the top-down side: `Harm` carries the severity
  classification; `HazardousSituation` carries the ISO 14971 P1/P2
  probabilities; `Causation` connects risk events into chains
  (`FailureMode -> Hazard -> HazardousSituation -> Harm`).
- Severity is stated **once, on the harm**. `SeverityScale` gives each class
  a canonical anchor on the FMEA 1–10 severity line (negligible = 2 …
  catastrophic = 10). An `@Fmea` line that names a hazard (`hazardRef`) must
  use the linked harm's anchor as its S rating — a lintable consistency rule,
  same philosophy as derived RPN. Likelihood and detection remain bottom-up
  properties of the failure mode.
- `RiskControl` (a requirement def with the ISO 14971 control hierarchy) is
  the *obligation*; `RiskAnalysis::Mitigation` actions are the *work items*
  implementing it; `satisfy`/`verify` provide the closure evidence. "Which
  hazards lack verified controls" is a generic traceability query.

**RAAML**: OMG's Risk Analysis and Assessment Modeling Language 1.0 is a
UML/SysML v1 profile and cannot be imported into SysML v2 models, so
`HazardAnalysis` re-expresses its Core concepts natively. Mapping:

| RAAML Core | Here |
|---|---|
| Harm | `Harm` |
| Hazard | `Hazard` |
| Situation | `HazardousSituation` |
| causal relationships | `Causation` |
| ControllingMeasure | `RiskControl` |

When OMG publishes RAAML for SysML v2, migration should be mechanical
renames. The RAAML FTA and STPA libraries are intentionally deferred; the
`Causation` graph is designed to be their substrate (an FTA is this graph
plus AND/OR gate semantics).

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
3. Requirement coverage checks (W002/W003/W014) were file-local: a library
   `RiskControl` satisfied and verified in another file — through a usage of
   a *specializing* def — still warned. The checks now consult project-wide
   satisfy/verify targets resolved through usages and closed over
   specialization (satisfying `Derived :> Base` satisfies `Base`).

Validation runs both implementations on every file: `sysml check` (semantic:
resolution, constraints, lints) and `tree-sitter-sysml` (independent syntax
check). CI-friendly via `make check`.

Since sysml-cli's W017, the libraries' `assert constraint`s are *evaluated*
during `check`: a model value that violates its type's constraint (an FMEA
rating of 12, an inverted `LimitRange`) is flagged with the constraint's
own expression. This is the intended division of labor — validation rules
ship in the library as constraints, and the tool stays generic.

## Concept map

Where common engineering artifacts land in the libraries:

| Artifact | Library construct |
|---|---|
| Component / assembly | `part def` / `part` (native SysML) |
| Feature with dimensions | `GeometricFeature` item + `TolerancedDimension` attributes |
| GD&T callout | `FeatureControlFrame` attributes |
| Fit / mating condition | `Mate` connection; fit via `MinClearance`/`MaxClearance` calcs |
| Tolerance stackup | `ToleranceStackup` analysis with feature-chain contributions |
| FMEA worksheet row | `@Fmea` annotation on the affected element |
| Hazard / harm / situation | `Hazard` / `Harm` / `HazardousSituation` occurrences + `Causation` |
| Risk control / mitigation | `RiskControl` requirement + `Mitigation` action + `satisfy`/`verify` |
| Requirement / test | native `requirement` / `verification` (already in SysML) |
| Status / priority / tags | `metadata def` annotations (future `ProjectMetadata` package) |

## Roadmap

- **Phase 2 (tooling)**: ~~generic uncertainty analyzer~~ (shipped:
  `sysml analyze run -n <case> --method worst-case|rss|monte-carlo`,
  resolving contributions through feature chains, seeded reproducible
  Monte Carlo); still open: the generic view renderer (`sysml view
  <name>`) with the library view defs upgraded to real filter
  expressions and `@TableRendering` specs.
- **GD&T depth**: bonus tolerance (MMC/LMC) contributions to stackups.
- **3D chains**: small-displacement-torsor analysis over `Frame3D` placements —
  the one genuinely tool-side solver; models stay declarative.
- **Action Priority**: AIAG-VDA 2019 replaced RPN with an Action Priority
  table lookup on S/O/D; add an `ActionPriority` calc for automotive users.
- **FTA / STPA packages**: RAAML-aligned fault trees (gates over the
  `Causation` graph) and STPA control structures, as optional packages.
- **`QualityManagement` package**: manufacturing processes, control plans,
  and the NCR/CAPA quality loop.
- **`ProjectMetadata` package**: status workflow, priority, ownership
  annotations.
- **Editor support**: sysml-mode snippets and completion for the library
  vocabulary.
