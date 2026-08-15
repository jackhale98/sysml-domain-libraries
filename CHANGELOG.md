# Changelog

## Unreleased

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
