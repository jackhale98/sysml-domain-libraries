package BatteryFmeaExample {
    doc
    /*
     * FMEA example: battery pack failure modes with mitigations traced
     * through standard satisfy/verify relationships.
     *
     * Demonstrates:
     * - @Fmea worksheet annotations, including a pre-mitigation baseline
     * - a structural Hazard for the safety case
     * - mitigations linked with `satisfy`, evidence linked with `verify`,
     *   so generic traceability answers "which high-RPN risks lack
     *   verified mitigations"
     *
     * Report:
     *   sysml report FmeaWorksheet
     *   sysml report RiskMatrix
     */

    private import ScalarValues::*;
    private import RiskAnalysis::*;

    part def BatteryPack;
    part def Bms;

    occurrence fireHazard : Hazard {
        :>> description = "Lithium cell fire during charge or discharge";
    }

    part battery : BatteryPack {
        @Fmea {
            failureMode = "Thermal runaway";
            cause = "Internal short from dendrite growth";
            effect = "Fire; loss of vehicle";
            category = RiskCategory::design;
            severity = 9;
            occurrence = 2;
            detection = 4;
            initialSeverity = 9;
            initialOccurrence = 4;
            initialDetection = 7;
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

    requirement def <'R-BATT-01'> ThermalCutoffReq {
        doc
        /*
         * The BMS shall disconnect the pack within 500 ms when any cell
         * exceeds 60 degrees C.
         */
        subject pack : BatteryPack;
    }

    requirement thermalCutoff : ThermalCutoffReq {
        subject pack = battery;
    }

    action overTempCutoff : Mitigation {
        doc /* BMS over-temperature disconnect covering thermal runaway. */
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
