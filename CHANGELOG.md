# Changelog

## Unreleased

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
