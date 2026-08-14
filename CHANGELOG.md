# Changelog

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
