# Changelog

## 0.4.0 — 2026-08-18

Works with: sysml-cli >= 0.9.3. Every file is accepted by the OMG SysML
v2 Pilot Implementation with zero errors and zero warnings, and by
`sysml check` with zero warnings.

### Acceptance policy is model content
- **`UncertaintyAnalysis::marginalFraction`** (default 0.10) decides
  when a positive margin still reports MARGINAL instead of PASS. It was
  a constant inside the analyzer; a project now tunes it here, on a
  single analysis or across a class of them by specializing the def.
  Editing this library changes the verdicts, with no tool change.

### Examples
- **`examples/ShaftFits.sysml`** — one Ø20 H7 bore mated to a g6, a k6
  and a p6 shaft, giving a clearance, a transition and an interference
  fit from the same hole. Nothing declares the fit type: each mate is
  paired with a two-term stackup whose worst-case range is the fit, so
  `wcMin` is the clearance at MMC and `wcMax` at LMC and the pair of
  signs classifies it. Limits are ISO 286 for the 18..30 mm step. Also
  carries an axial chain that is not a fit, and a project `CriticalFit`
  def holding the two critical-to-quality fits to a stricter marginal
  band than the library default.
- **`examples/BatteryFmea.sysml` expanded** from 2 worksheet lines to 8,
  across all four RiskCategory values, with six hazards each on its own
  causal chain and five harms spanning the whole SeverityScale. Risk
  controls now cover all three levels of the ISO 14971 hierarchy, with
  Mitigation actions in both kinds and four of the four statuses. Two
  chains converge on one harm, which is the point: the severity of a
  worksheet line is the anchor of the harm its hazard leads to, so a
  software failure and a cell defect that end the same way rate the
  same without anyone coordinating.
- Requirement and verification subjects are typed by the component they
  constrain rather than all by the pack, which is what the pilot's
  "bound features should have conforming types" warning was pointing at.
- New project views: `SoftwareRisks` and `UndetectableRisks` (a
  high-severity failure nobody can see coming does not surface on an
  RPN-sorted sheet), `ControlCoverage`, `ToleranceAnalysis`,
  `PressFits`.

## 0.3.1 — 2026-08-18

Works with: sysml-cli >= 0.9.2. Every file — libraries and examples — is
accepted by the OMG SysML v2 Pilot Implementation with zero errors
(`make check-pilot`) and by `sysml check` with zero warnings.

- **`FitTable` now lists mates, not every connection.** It selected
  `relation:connection`, so on a model with a hazard chain the "fit
  table" reported the causal edges — three causations and no fits on
  `BatteryFmea`. It now selects `relation:connection:Mate`, which
  covers any type specializing `Mate`.
- **`Reporting::Bom`** — a bill of materials over the composition tree:
  `path`, `type`, `quantity` (usage multiplicity) and `extended`
  (quantity multiplied down the tree). Connections are excluded; they
  are structure, not content. Name any attribute the model declares as
  a column. `sysml view Bom -f csv > bom.csv`.
- **The examples declare their own views.** `sysml view` on an example
  used to list only library views; each example now ships the tables
  its own review would run — `RiskReduction` and `ActionableRisks`
  (BatteryFmea), `GapCapability` (EnclosureGap), `TightClearances` and
  `HazardLinkedFailures` (ReliefValve). They demonstrate the extension
  point: a project tailors reports by writing `view def`s, not by
  asking for a tool feature.
- Examples import `Reporting`, which they need for `@TableRendering`.

## 0.3.0 — 2026-08-17

Works with: sysml-cli >= 0.9.0. Every file — libraries and examples —
is accepted by the OMG SysML v2 Pilot Implementation with zero errors
and zero warnings (`make check-pilot`, run in CI).

- **Typed hazard references** (breaking): `Fmea::hazardRef : String` and
  `RiskControl::hazardRef : String` are now `ref hazard : Hazard[0..1]`
  - real model references (pilot-validated), so tools list a hazard's
  worksheet lines and controls by collecting refs instead of matching
  strings. Examples bind them unqualified (`hazard = overpressure;`).
- **StandardViews merged into Reporting** (breaking): the five
  domain-neutral views (PortTable, AllocationMatrix,
  RequirementsTraceMatrix, ModelStats, ConnectionTable) live in
  `Reporting.sysml`; the convention and the generic views that use it
  are one import. `StandardViews.sysml` is gone.

## 0.2.0 — 2026-08-15

Works with: sysml-cli >= 0.8.0 (likelihood-named FMEA fields, model-side
gates, chained verify targets). Every file — libraries and examples —
is accepted by the OMG SysML v2 Pilot Implementation with zero errors
and zero warnings.

- **Renames for clarity and conformance** (breaking): FMEA `occurrence`
  -> `likelihood` (AIAG "occurrence" collides with the SysML
  `occurrence` keyword and needed quoting everywhere; likelihood
  doesn't), `initialOccurrence` -> `initialLikelihood`, and
  `ToleratedDimension` -> `TolerancedDimension` (drawing-practice term).
- **Model-side CI gates**: `ModelQuality` adds `QualityGate` and
  `TraceGate` constraint defs. Declaring a usage (`constraint g :
  QualityGate { :>> minScore = 80.0; }`) activates the gate that
  `sysml coverage --check` / `sysml trace --check` evaluate; thresholds
  are `default` attributes the usage overrides. Pilot-validated,
  including the usage pattern.
- **`RiskControl.hazardRef`**: closes the control->hazard side of the
  ISO 14971 audit trail (harm carries severity, Causation carries the
  chain, hazardRef links the control), same convention as
  `Fmea::hazardRef`. Both examples use it.
- **ReliefValve engineering audit**: the `@Fmea` line moved onto the
  assembly's actual piston (the free-floating `pistonTracked` part was
  a phantom BOM entry); requirement and pop-test wording aligned on
  maximum allowable accumulation (110% of rating, ASME practice); the
  stackup's upper limit documented (guided engagement); a nested
  requirement hierarchy (`SYS-01` system obligation containing the
  `RV-01` risk control) with chain-path satisfy/verify; and a `PopTest`
  functional verification of the system requirement. Trace closes at
  100%/100% and the gates assert it.
- **`ModelQuality` package**: a `QualityScore` calc def over the fixed
  parameter vocabulary `sysml coverage` binds (documented / typedUsages /
  reqSatisfied / reqVerified, each 0-100). Import it — or declare your
  own `QualityScore` — and the coverage score's weighting lives in the
  model instead of tool configuration. Pilot-validated with the rest.
- **OMG pilot conformance**: all libraries and examples are now accepted
  by the OMG SysML v2 Pilot Implementation with zero errors and zero
  warnings. `make check-pilot` (scripts/pilot-validate.sh) runs the whole
  repo through the pilot in one session, in dependency order; CI runs it
  on every push alongside `make check`.
- **Conformant quoted names**: members whose names collide with SysML
  keywords are now written in the quoted form the pilot requires —
  `'occurrence'` (FMEA rating and Rpn parameter), `RiskCategory::'use'`,
  `FitType::'transition'` — at declaration and reference. The guide
  explains the rule.
- **Requirement subject binding**: examples no longer bind a requirement
  usage's subject both explicitly and via `satisfy ... by`; the satisfy
  statement is the single binding (the pilot rejects the double bind).
  BatteryFmea's thermal-cutoff control is satisfied by `battery` (the
  subject), matching its declared subject type.

## 0.1.0 — 2026-08-14

First tagged release.

- **Packages**: `Uncertainty` (the analyzer contract: UncertainValue,
  LimitRange, UncertaintyAnalysis), `Tolerancing` (toleranced dimensions,
  GD&T feature control frames, mates, feature-chain stackups),
  `RiskAnalysis` (AIAG/VDA 1-10 FMEA, derived RPN, @Fmea annotations,
  FailureMode occurrences), `HazardAnalysis` (RAAML-Core-aligned
  Harm/Hazard/HazardousSituation/Causation/RiskControl driving FMEA
  severity top-down), `Reporting` (the @TableRendering convention), and
  `StandardViews` (PortTable, AllocationMatrix, RequirementsTraceMatrix,
  ModelStats, ConnectionTable).
- **Examples**: enclosure-gap stackup, hazard-driven battery FMEA, and
  the guide's relief valve — where the travel-gap stackup is the
  evidence behind an inherent-safety risk control.
- **Docs**: ground-up user guide (no SysML v2 experience assumed) and
  the design rationale (semantics in the model, math in the tool).
- **Validation**: every file checks clean under sysml-cli 0.7.0
  (semantic, including evaluated assert constraints via W017) and
  tree-sitter-sysml 0.6.0 (syntactic) via `make check`.

Works with: sysml-cli >= 0.7.0 (analyze/view/W017), any conformant
SysML v2 tool for parsing and navigation.
