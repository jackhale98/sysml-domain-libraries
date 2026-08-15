package ReliefValveExample {
    doc
    /*
     * The guide's running example (docs/guide.md): a spring-loaded
     * pressure relief valve where the tolerancing and safety analyses
     * meet. The piston must have travel clearance to open the valve;
     * losing that clearance is not just a fit problem but a hazard
     * (vessel overpressure), so the travel-gap stackup is the evidence
     * behind a risk control.
     *
     * Covers, ground up: toleranced dimensions, features with datums,
     * a mate with expected fit, a critical stackup, an @Fmea worksheet
     * line driven by a hazard chain, and a RiskControl satisfied by the
     * design and verified by test.
     */

    private import ScalarValues::*;
    private import Uncertainty::*;
    private import Tolerancing::*;
    private import HazardAnalysis::*;
    private import RiskAnalysis::*;
    private import ModelQuality::*;

    // --- Parts and their toleranced geometry ---------------------------

    part def ValveBody {
        item bore : GeometricFeature {
            :>> form = FeatureForm::hole;
            :>> nature = FeatureNature::internal;
            :>> datum = "A";
            attribute diameter : TolerancedDimension {
                :>> nominal = 12.0;
                :>> plus = 0.05;
                :>> minus = 0.00;
            }
        }
        attribute seatDepth : TolerancedDimension {
            doc /* Seat face to spring shoulder. DWG-RV-001 */
            :>> nominal = 30.0;
            :>> plus = 0.1;
            :>> minus = 0.1;
        }
    }

    part def Piston {
        item od : GeometricFeature {
            :>> form = FeatureForm::shaft;
            :>> nature = FeatureNature::external;
            attribute diameter : TolerancedDimension {
                :>> nominal = 11.95;
                :>> plus = 0.00;
                :>> minus = 0.03;
            }
        }
        attribute length : TolerancedDimension {
            doc /* DWG-RV-002 */
            :>> nominal = 28.0;
            :>> plus = 0.05;
            :>> minus = 0.05;
        }
    }

    part def Spring {
        attribute solidHeight : TolerancedDimension {
            doc /* Vendor limits only - assume uniform. VS-SPR-9 */
            :>> nominal = 1.5;
            :>> plus = 0.1;
            :>> minus = 0.1;
            :>> distribution = Distribution::uniform;
        }
    }

    // --- Assembly: mate and stackup -------------------------------------

    part relief : ReliefValveAsm;

    part def ReliefValveAsm {
        part body : ValveBody;
        part piston : Piston {
            @Fmea {
                doc
                /*
                 * Worksheet line for the same failure the structural
                 * valveStuckClosed occurrence models - two views of one
                 * failure, ratings kept identical.
                 */
                failureMode = "Piston seizure in bore";
                cause = "Insufficient travel clearance at tolerance extremes";
                effect = "Valve fails to open; overpressure";
                category = RiskCategory::design;
                severity = 8;
                likelihood = 3;
                detection = 6;
                hazard = overpressure;
            }
        }
        part spring : Spring;

        connection pistonFit : Mate connect piston.od to body.bore {
            :>> expectedFit = FitType::clearance;
        }

        analysis travelGap : ToleranceStackup {
            doc
            /*
             * Piston travel at spring-solid: the clearance that lets the
             * valve open. gap = body.seatDepth - piston.length
             *                   - spring.solidHeight
             * Lower limit 0.2: full relief flow requires at least this
             * lift. Upper limit 0.8: beyond it the piston loses guided
             * engagement in the bore and can cock.
             */
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
    }

    // --- Safety: the stackup is the evidence behind a risk control ------

    occurrence vesselRupture : Harm {
        :>> description = "Vessel rupture; injury to nearby personnel";
        :>> severity = SeverityScale::critical;
    }

    occurrence overpressure : Hazard {
        :>> description = "System pressure exceeds vessel rating";
    }

    occurrence pressurizedOperation : HazardousSituation {
        :>> description = "Overpressure while the system is manned";
        :>> p1 = 0.01;
        :>> p2 = 0.3;
    }

    occurrence valveStuckClosed : FailureMode {
        :>> cause = "Piston seizes in bore; no travel clearance";
        :>> effect = "Valve cannot relieve pressure";
        :>> likelihood = 3;
        :>> detection = 6;
    }

    connection h1 : Causation connect valveStuckClosed to overpressure;
    connection h2 : Causation connect overpressure to pressurizedOperation;
    connection h3 : Causation connect pressurizedOperation to vesselRupture;

    requirement def <'SYS-01'> OverpressureProtectionReq {
        doc
        /*
         * The assembly shall relieve system pressure such that vessel
         * pressure never exceeds the maximum allowable accumulation
         * (110% of rated pressure) under all specified failure
         * conditions.
         */
        subject valve : ReliefValveAsm;
    }

    requirement def <'RV-01'> MinTravelReq :> RiskControl {
        doc
        /*
         * The piston shall retain at least 0.2 mm travel clearance at
         * worst-case tolerances with the spring at solid height.
         */
        subject valve : ReliefValveAsm;
    }

    requirement overpressureProtection : OverpressureProtectionReq {
        doc
        /*
         * The system obligation. Its verifiable slice is the nested
         * travel-clearance requirement: sub-requirements decompose a
         * requirement into the pieces evidence can actually close.
         */
        requirement minTravel : MinTravelReq {
            :>> hierarchy = ControlHierarchy::inherentSafety;
            :>> rationale = "Clearance by geometry - no moving parts to fail";
            :>> hazard = overpressure;
        }
    }

    satisfy overpressureProtection by relief;
    satisfy overpressureProtection.minTravel by relief;

    verification def TravelClearanceTest {
        doc /* Measure piston travel at spring solid on 30 assemblies. */
        subject valve : ReliefValveAsm;
        objective {
            verify overpressureProtection.minTravel;
        }
    }

    verification travelClearanceTest : TravelClearanceTest {
        subject valve = relief;
    }

    verification def PopTest {
        doc
        /*
         * Functional proof of the system obligation: pressurize five
         * assemblies past the set point and confirm full relief with
         * peak pressure below the maximum allowable accumulation.
         */
        subject valve : ReliefValveAsm;
        objective {
            verify overpressureProtection;
        }
    }

    verification popTest : PopTest {
        subject valve = relief;
    }

    // --- CI gate: the quality threshold lives in the model --------------

    constraint qualityGate : QualityGate {
        doc
        /*
         * `sysml coverage --check` evaluates this gate: the model, not a
         * CLI flag, decides what score ships.
         */
        :>> minScore = 80.0;
    }

    constraint traceGate : TraceGate {
        doc
        /*
         * `sysml trace --check` gate at the defaults: every requirement
         * satisfied AND verified - this model has earned strictness.
         * During development, relax with `:>> minVerified = 60.0;` and
         * raise it back for release.
         */
    }
}
