package BatteryFmeaExample {
    doc
    /*
     * Hazard-driven FMEA example: battery pack failure modes wired into a
     * causal risk chain, with mitigations traced through standard
     * satisfy/verify relationships.
     *
     * Demonstrates:
     * - top-down hazard analysis: Harm (carries severity) <- Hazardous
     *   Situation (P1/P2) <- Hazard <- FailureMode, linked by Causation
     * - bottom-up @Fmea worksheet annotations; the thermal-runaway line
     *   references the hazard (a typed ref), so its severity of 8 is checked
     *   against the harm's `critical` anchor
     * - a RiskControl obligation implemented by a Mitigation action,
     *   satisfied by the BMS and verified by test
     *
     * Report:
     *   sysml view FmeaWorksheet     (library, generic)
     *   sysml view RiskMatrix        (library, generic)
     *   sysml view HazardLog         (library, generic)
     *   sysml view RiskReduction     (declared below, project-specific)
     *   sysml view ActionableRisks   (declared below, project-specific)
     */

    private import ScalarValues::*;
    private import HazardAnalysis::*;
    private import RiskAnalysis::*;
    private import Reporting::*;  // @TableRendering, for the views below

    part def BatteryPack;
    part def Bms;

    // --- Top-down hazard analysis -------------------------------------

    occurrence burnAndPropertyLoss : Harm {
        :>> description = "Burn injury to operator; loss of vehicle";
        :>> severity = SeverityScale::critical;
    }

    occurrence fireHazard : Hazard {
        :>> description = "Lithium cell fire during charge or discharge";
    }

    occurrence fireInOperation : HazardousSituation {
        :>> description = "Cell fire while the vehicle is airborne near people";
        :>> p1 = 0.001;
        :>> p2 = 0.7;
    }

    // --- Bottom-up failure mode, joined to the chain ------------------

    occurrence thermalRunawayFm : FailureMode {
        :>> cause = "Internal short from dendrite growth";
        :>> effect = "Cell fire propagating through the pack";
        :>> likelihood = 2;
        :>> detection = 4;
    }

    connection c1 : Causation connect thermalRunawayFm to fireHazard;
    connection c2 : Causation connect fireHazard to fireInOperation;
    connection c3 : Causation connect fireInOperation to burnAndPropertyLoss;

    // --- FMEA worksheet -----------------------------------------------

    part battery : BatteryPack {
        @Fmea {
            failureMode = "Thermal runaway";
            cause = "Internal short from dendrite growth";
            effect = "Fire; loss of vehicle";
            category = RiskCategory::design;
            severity = 8;
            likelihood = 2;
            detection = 4;
            initialSeverity = 8;
            initialLikelihood = 4;
            initialDetection = 7;
            hazard = fireHazard;
        }
        @Fmea {
            failureMode = "Capacity fade below 80% before design life";
            cause = "Deep-discharge cycling beyond rated depth";
            effect = "Mission duration shortfall";
            category = RiskCategory::'use';
            severity = 5;
            likelihood = 6;
            detection = 3;
        }
    }

    part bms : Bms;

    // --- Risk control: obligation, implementation, evidence -----------

    requirement def <'R-BATT-01'> ThermalCutoffReq :> RiskControl {
        doc
        /*
         * The BMS shall disconnect the pack within 500 ms when any cell
         * exceeds 60 degrees C.
         */
        subject pack : BatteryPack;
    }

    requirement thermalCutoff : ThermalCutoffReq {
        :>> hierarchy = ControlHierarchy::protectiveMeasure;
        :>> rationale = "Interrupts thermal runaway before propagation";
        :>> hazard = fireHazard;
    }

    action overTempCutoff : Mitigation {
        doc /* Work item implementing the thermal cutoff risk control. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::verified;
        :>> owner = "BMS team";
    }

    satisfy thermalCutoff by battery;

    verification def ThermalCutoffTest {
        doc
        /*
         * Heat one cell past the threshold in a controlled fixture and
         * measure disconnect latency.
         */
        subject pack : BatteryPack;
        objective {
            verify thermalCutoff;
        }
    }

    verification thermalCutoffTest : ThermalCutoffTest {
        subject pack = battery;
    }

    // --- Project-specific views ---------------------------------------
    //
    // The libraries ship generic views; a project tailors its own by
    // writing `view def`s here. No tool change is needed for either.

    view def RiskReduction {
        doc
        /*
         * What mitigation bought us. The library's FmeaWorksheet reports
         * current risk only; this pairs it with the pre-mitigation
         * numbers a line item records in `initialSeverity` /
         * `initialLikelihood` / `initialDetection`, so the reduction is
         * visible per failure mode. Line items with no initial values
         * are unmitigated and drop out of the filter.
         */
        @TableRendering {
            rows = "@Fmea";
            columns = "failureMode; initialRpn = initialSeverity*initialLikelihood*initialDetection; rpn = severity*likelihood*detection; reduction = initialSeverity*initialLikelihood*initialDetection - severity*likelihood*detection";
            where = "initialSeverity > 0";
            sortBy = "-reduction";
        }
    }

    view def ActionableRisks {
        doc
        /*
         * The review agenda: line items above this project's RPN action
         * threshold of 80, worst first.
         */
        @TableRendering {
            rows = "@Fmea";
            columns = "element; failureMode; category; detection; rpn = severity*likelihood*detection";
            where = "severity*likelihood*detection >= 80";
            sortBy = "-rpn";
        }
    }
}
