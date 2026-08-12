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
     *   references the hazard (hazardRef), so its severity of 8 is checked
     *   against the harm's `critical` anchor
     * - a RiskControl obligation implemented by a Mitigation action,
     *   satisfied by the BMS and verified by test
     *
     * Report:
     *   sysml view FmeaWorksheet
     *   sysml view RiskMatrix
     *   sysml view HazardLog
     */

    private import ScalarValues::*;
    private import HazardAnalysis::*;
    private import RiskAnalysis::*;

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
        :>> occurrence = 2;
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
            occurrence = 2;
            detection = 4;
            initialSeverity = 8;
            initialOccurrence = 4;
            initialDetection = 7;
            hazardRef = "BatteryFmeaExample::fireHazard";
        }
        @Fmea {
            failureMode = "Capacity fade below 80% before design life";
            cause = "Deep-discharge cycling beyond rated depth";
            effect = "Mission duration shortfall";
            category = RiskCategory::use;
            severity = 5;
            occurrence = 6;
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
        subject pack = battery;
        :>> hierarchy = ControlHierarchy::protectiveMeasure;
        :>> rationale = "Interrupts thermal runaway before propagation";
    }

    action overTempCutoff : Mitigation {
        doc /* Work item implementing the thermal cutoff risk control. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::verified;
        :>> owner = "BMS team";
    }

    satisfy thermalCutoff by bms;

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
}
