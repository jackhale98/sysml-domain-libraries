# User guide: tolerancing and risk analysis in SysML v2, from the ground up

This guide builds one model — a spring-loaded pressure relief valve — from an
empty directory to a validated design where a tolerance stackup is the
evidence behind a safety risk control. Every snippet comes from
[`examples/ReliefValve.sysml`](../examples/ReliefValve.sysml), which is
checked by CI, so everything here parses and resolves.

No prior SysML v2 experience is assumed; section 2 covers the five language
ideas the libraries rely on.

## 1. Setup

Install the [sysml CLI](https://github.com/jackhale98/sysml-cli), then:

```sh
mkdir relief-valve && cd relief-valve
cp -r /path/to/sysml-domain-libraries/libraries .
sysml init          # detects libraries/ and adds it to the import path
```

Any conformant SysML v2 tool can read these models — the libraries are plain
`.sysml` files. This guide uses the sysml CLI for validation and analysis.

Create `valve.sysml` with a package and the imports you'll need:

```sysml
package ReliefValveExample {
    private import ScalarValues::*;
    private import Uncertainty::*;
    private import Tolerancing::*;
    private import HazardAnalysis::*;
    private import RiskAnalysis::*;

    // everything below goes in here
}
```

Check it as you go — this is the loop you'll live in:

```sh
sysml check valve.sysml
```

## 2. Five language ideas

**Definitions and usages.** A `def` is a reusable type; a usage is a named
instance of one. `part def Piston` defines what a piston is;
`part piston : Piston` puts one in your assembly. The same pattern holds for
`attribute`, `item`, `connection`, `analysis`, `requirement`, `occurrence`.

**Nesting is structure.** A part's features, dimensions, and sub-parts are
declared inside its body — the model tree *is* the product structure.

**`:>>` redefines.** Inside a usage, `:>> nominal = 30.0;` sets a value for
an attribute the type already declares. You'll use this constantly.

**`:>` subsets.** `attribute seatDepth :> contributions { ... }` declares a
new member *and* adds it to an inherited collection. This is how stackup
contributors join a stackup.

**References, not copies.** `:>> dim = body.seatDepth;` binds through a
*feature chain* — the stackup contributor points at the dimension where it
lives. Change the tolerance on the part and every analysis that references
it updates. This single idea is why the model beats a spreadsheet.

## 3. Toleranced dimensions

A `ToleratedDimension` is a value with a nominal, asymmetric bounds, and a
statistical distribution (from the `Uncertainty` package — `normal` by
default). Declare dimensions on the parts that own them:

```sysml
part def Spring {
    attribute solidHeight : ToleratedDimension {
        doc /* Vendor limits only - assume uniform. VS-SPR-9 */
        :>> nominal = 1.5;
        :>> plus = 0.1;
        :>> minus = 0.1;
        :>> distribution = Distribution::uniform;
    }
}
```

Reading it: `1.5 +0.1/-0.1`, uniformly distributed. `plus` and `minus` are
magnitudes — both non-negative (the library enforces this with a
constraint). Values are interpreted in the dimension's `unit` attribute,
default `"mm"`; keep one unit per chain.

Distribution guidance: `normal` for stable machining processes, `uniform`
when you only know vendor limits, `triangular` for skilled manual assembly.

**Definition or usage?** Put dimension values on the `part def` — they are
what the drawing says, and every usage inherits them, exactly as every
physical part is governed by its drawing. Redefine a dimension on a part
*usage* only when the context genuinely changes the number: a variant
configuration, selective assembly (a hand-fitted pin), or a lot-specific
vendor part. Usage values win over definition values when analyses
resolve a dimension. (A usage-level override currently restates the whole
dimension — nominal, plus, and minus — rather than merging with the
definition's values.) Properties that only exist in context, like a
spring's *installed* length, belong on the usage from the start; the
spring's *solid height* stays on the def.

## 4. Features, datums, and GD&T

Dimensions that participate in fits belong on a `GeometricFeature` — an
item that knows its form (hole, shaft, plane…) and its nature (`internal`
when material surrounds the feature, `external` when the feature is
surrounded — this determines which side of a fit it is on):

```sysml
part def ValveBody {
    item bore : GeometricFeature {
        :>> form = FeatureForm::hole;
        :>> nature = FeatureNature::internal;
        :>> datum = "A";
        attribute diameter : ToleratedDimension {
            :>> nominal = 12.0;
            :>> plus = 0.05;
            :>> minus = 0.00;
        }
    }
    attribute seatDepth : ToleratedDimension {
        :>> nominal = 30.0;
        :>> plus = 0.1;
        :>> minus = 0.1;
    }
}
```

`datum = "A"` marks the bore as datum A. For GD&T callouts, add
`FeatureControlFrame` entries to the feature's `controls` collection —
characteristic (the 14 ASME Y14.5 symbols), zone, material condition
modifier, and up to three datum references.

Note the two homes: `diameter` lives on the *bore* (it's part of the fit);
`seatDepth` lives on the *body* (it's a body dimension). Put dimensions
where a drawing would put them.

## 5. Mates

A mate is a `connection def` between two features. State your design
intent with `expectedFit`; tools compute the actual worst-case fit from the
mated dimensions and flag disagreement:

```sysml
part def ReliefValveAsm {
    part body : ValveBody;
    part piston : Piston;
    part spring : Spring;

    connection pistonFit : Mate connect piston.od to body.bore {
        :>> expectedFit = FitType::clearance;
    }
}
```

The fit math is in the library itself as calcs (`MinClearance`,
`MaxClearance`: smallest hole minus largest shaft, and vice versa), so any
tool that evaluates calcs gets the same numbers.

## 6. Tolerance stackups

A stackup answers: does a gap that depends on several toleranced dimensions
stay within its limits? Declare one as an `analysis` inside the assembly it
measures. Three pieces: a **target** (the spec limits), **contributions**
(which dimensions, in which direction), and optional settings inherited
from `UncertaintyAnalysis` (sigma level, Bender mean shift, Monte Carlo
iterations/seed).

```sysml
analysis travelGap : ToleranceStackup {
    doc /* Piston travel at spring-solid: the clearance that lets
         * the valve open. */
    attribute :>> target {
        :>> nominal = 0.5;
        :>> lower = 0.2;
        :>> upper = 0.8;
    }
    attribute :>> critical = true;

    attribute seatDepth :> contributions {
        :>> dim = body.seatDepth;
        :>> sense = Sense::positive;
        :>> source = "DWG-RV-001";
    }
    attribute pistonLength :> contributions {
        :>> dim = piston.length;
        :>> sense = Sense::negative;
        :>> source = "DWG-RV-002";
    }
    attribute springSolid :> contributions {
        :>> dim = spring.solidHeight;
        :>> sense = Sense::negative;
        :>> source = "VS-SPR-9";
    }
}
```

Walk the chain like a loop diagram: dimensions that open the gap are
`positive`, dimensions that close it are `negative`. Sanity-check the
nominals by hand: 30.0 − 28.0 − 1.5 = 0.5 ✓ (the target nominal).

Each contribution's `dim` is a feature-chain reference — no values are
restated. Retolerance `spring.solidHeight` on the Spring and this stackup
sees it immediately. `source` records where each tolerance comes from, for
the humans reading the report later.

Now evaluate it:

```sh
sysml analyze run -I libraries valve.sysml -n travelGap
```

This runs all three methods defined by the `Uncertainty` package —
worst-case interval arithmetic, RSS variance propagation (Cp/Cpk,
per-contribution sensitivity), and Monte Carlo — and exits non-zero if
any evaluated method misses the target, so a failing stackup fails CI.
Useful variations:

```sh
sysml analyze run -I libraries valve.sysml -n travelGap --method worst-case
sysml analyze run -I libraries valve.sysml -n travelGap \
    --method monte-carlo --iterations 50000 --seed 12345
sysml -f json analyze run -I libraries valve.sysml -n travelGap
```

Monte Carlo runs are seeded: the same seed gives bit-for-bit identical
results, and the seed used is always printed — rerunning any past
analysis exactly is a one-flag affair (audit trails care about this).
The RSS sensitivity column tells you which dimension to tighten first
when a stackup is marginal.

## 7. FMEA worksheet lines

The lightweight risk style: annotate the element whose failure you're
analyzing with `@Fmea`. Ratings are the AIAG/VDA 1–10 ordinal scales;
RPN = S × O × D is *derived* by the library's `Rpn` calc, so you never
write it (and it can never disagree with its factors):

```sysml
part pistonTracked : Piston {
    @Fmea {
        failureMode = "Piston seizure in bore";
        cause = "Insufficient travel clearance at tolerance extremes";
        effect = "Valve fails to open; overpressure";
        category = RiskCategory::design;
        severity = 8;
        occurrence = 3;
        detection = 6;
        hazardRef = "ReliefValveExample::overpressure";
    }
}
```

`hazardRef` is the bridge to the safety model — next section. The optional
`initialSeverity`/`initialOccurrence`/`initialDetection` fields record the
pre-mitigation baseline so risk reduction stays visible.

## 8. Hazard-driven safety analysis

Hazard analysis runs top-down: what harm can occur, what hazard produces
it, what situation exposes people to it. Model each as an occurrence and
join them with `Causation` links:

```sysml
occurrence vesselRupture : Harm {
    :>> description = "Vessel rupture; injury to nearby personnel";
    :>> severity = SeverityScale::critical;
}

occurrence overpressure : Hazard {
    :>> description = "System pressure exceeds vessel rating";
}

occurrence pressurizedOperation : HazardousSituation {
    :>> description = "Overpressure while the system is manned";
    :>> p1 = 0.01;    // probability the situation arises
    :>> p2 = 0.3;     // probability it leads to the harm
}

occurrence valveStuckClosed : FailureMode {
    :>> cause = "Piston seizes in bore; no travel clearance";
    :>> effect = "Valve cannot relieve pressure";
    :>> occurrence = 3;
    :>> detection = 6;
}

connection h1 : Causation connect valveStuckClosed to overpressure;
connection h2 : Causation connect overpressure to pressurizedOperation;
connection h3 : Causation connect pressurizedOperation to vesselRupture;
```

Two rules make this rigorous:

- **Severity lives on the harm, once.** `SeverityScale` anchors each class
  to the FMEA severity line (negligible = 2, minor = 4, serious = 6,
  critical = 8, catastrophic = 10). The `@Fmea` line above says
  `severity = 8` because its `hazardRef` chain ends at a `critical` harm —
  tools flag the line if those disagree. Occurrence and detection stay
  bottom-up on the failure mode, where the knowledge actually is.
- **The chain is data.** P1 × P2 gives probability of harm (the
  `HarmProbability` calc), and the causation graph is the future substrate
  for fault trees.

## 9. Risk controls: closing the loop

A `RiskControl` is a requirement whose satisfaction reduces a risk. Declare
the obligation, say where it sits in the ISO 14971 hierarchy, `satisfy` it
by the design element that implements it, and `verify` it with evidence:

```sysml
requirement def <'RV-01'> MinTravelReq :> RiskControl {
    doc /* The piston shall retain at least 0.2 mm travel clearance
         * at worst-case tolerances with the spring at solid height. */
    subject valve : ReliefValveAsm;
}

requirement minTravel : MinTravelReq {
    subject valve = relief;
    :>> hierarchy = ControlHierarchy::inherentSafety;
    :>> rationale = "Clearance by geometry - no moving parts to fail";
}

satisfy minTravel by relief;

verification def TravelClearanceTest {
    subject valve : ReliefValveAsm;
    objective {
        verify minTravel;
    }
}
```

Notice what just happened across sections 6–9: the stackup's lower limit
(0.2 mm) *is* requirement RV-01, the requirement is a risk control against
the overpressure hazard, and the whole chain — dimension → stackup →
requirement → hazard → harm — is connected model structure. "Which
high-severity hazards have unverified controls?" is now a traceability
query (`sysml trace`), not an audit-week archaeology project.

The hierarchy matters: `inherentSafety` (safe by geometry/physics) beats
`protectiveMeasure` (add a guard/interlock) beats `informationForSafety`
(warn the user). Reviewers will ask why you didn't use a higher level —
`rationale` is where that answer lives.

## 10. Validating

```sh
sysml check -I libraries valve.sysml
```

What the checks give you (beyond syntax):

- Unresolved names (W004/W005) — typos in feature chains and `hazardRef`.
- Library constraints — negative tolerance bounds, ratings outside 1–10,
  P1/P2 outside 0..1, inverted target limits.
- Requirement coverage (W002/W003/W014) — risk controls that nothing
  satisfies or verifies. Coverage is project-wide and understands
  specialization: satisfying `MinTravelReq :> RiskControl` satisfies
  `RiskControl`.
- Notes (W001 unused, etc.) are hints, not failures.

In CI, fail on errors/warnings but allow notes — see `scripts/validate.sh`
in this repo for a ready-made harness that also runs the independent
tree-sitter syntax check.

## 11. Reports and analysis (what runs today vs. next)

Today, with sysml-cli from source (0.6 + unreleased):

- `sysml check` — validation, including the cross-file resolution and
  requirement-coverage semantics this guide relies on.
- `sysml analyze run -I libraries <file> -n <case>` — generic uncertainty
  propagation (section 6) over any analysis with `UncertainValue` inputs.
- `sysml trace` — requirement/verification coverage over the
  satisfy/verify graph, which covers risk controls too.
- `sysml diagram`, `sysml list`/`show`/`find`.

Landing next (the models above are already in the right shape):

- `sysml view FmeaWorksheet` / `RiskMatrix` / `HazardLog` /
  `StackupSummary` / `FitTable` — the `view def`s each library ships,
  rendered as tables by the generic view primitive.

## 12. Quick reference

| You want to say | Use |
|---|---|
| "This dimension is 30 ±0.1" | `ToleratedDimension` attribute on the part |
| "This is a hole / shaft / datum A" | `GeometricFeature` item (`form`, `nature`, `datum`) |
| "⌖ Ø0.2 Ⓜ A B" | `FeatureControlFrame` in the feature's `controls` |
| "These two features mate, clearance fit" | `Mate` connection with `expectedFit` |
| "Does this gap stay in spec?" | `ToleranceStackup` analysis; contributors subset `contributions` |
| "How could this part fail?" | `@Fmea` annotation (S/O/D; RPN derived) |
| "What harm can the system cause?" | `Harm` / `Hazard` / `HazardousSituation` + `Causation` |
| "What are we doing about it?" | `RiskControl` requirement + `Mitigation` action |
| "Prove it" | `satisfy` by the design, `verify` by the test |

Severity anchors: negligible 2 · minor 4 · serious 6 · critical 8 ·
catastrophic 10. RPN thresholds: 1–50 low, 51–150 medium, 151–400 high,
401+ critical.

The complete model is [`examples/ReliefValve.sysml`](../examples/ReliefValve.sysml);
the other examples show the same machinery on an enclosure stackup and a
battery FMEA. Design rationale lives in [`design.md`](design.md).
