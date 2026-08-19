package BatteryFmeaExample {
    doc
    /*
     * Hazard-driven FMEA for a high-voltage battery pack: six hazards,
     * each with its own causal chain to a harm, and worksheet lines in
     * every risk category traced to the controls that address them.
     *
     * The example is deliberately broad, because the interesting part of
     * a risk model is not any single line — it is that the same
     * vocabulary covers a design defect, a manufacturing escape, a
     * software error, and a misuse, and that severity comes from one
     * place no matter which route you arrive by.
     *
     * Demonstrates:
     * - top-down hazard analysis: Harm (carries severity) <- Hazardous
     *   Situation (P1/P2) <- Hazard <- FailureMode, linked by Causation.
     *   Harms span the whole SeverityScale, from a service interruption
     *   to a fatality
     * - bottom-up @Fmea worksheet annotations across all four
     *   RiskCategory values (design, process, use, software), each
     *   naming the hazard it precipitates. Severity is not chosen per
     *   line: it is the anchor of the harm at the end of that hazard's
     *   chain, which is what keeps a bottom-up worksheet and a top-down
     *   analysis from drifting apart
     * - risk controls at all three levels of the ISO 14971 hierarchy —
     *   inherent safety, protective measures, information for safety —
     *   each implemented by a Mitigation action and closed by
     *   satisfy/verify
     * - two hazards (fire and overcharge) leading to the same harm, and
     *   one failure mode (busbar weld) feeding a hazard it does not own
     *
     * Report:
     *   sysml view FmeaWorksheet     (library, generic)
     *   sysml view RiskMatrix        (library, generic)
     *   sysml view HazardLog         (library, generic)
     *   sysml view RiskReduction     (declared below, project-specific)
     *   sysml view ActionableRisks   (declared below, project-specific)
     *   sysml view SoftwareRisks     (declared below, project-specific)
     *   sysml view ControlCoverage   (declared below, project-specific)
     *
     * Trace a chain end to end:
     *   sysml deps -I libraries examples/BatteryFmea.sysml \
     *       thermalRunawayFm --forward --transitive
     */

    private import ScalarValues::*;
    private import HazardAnalysis::*;
    private import RiskAnalysis::*;
    private import Reporting::*;  // @TableRendering, for the views below

    part def BatteryPack;
    part def Bms;
    part def Busbar;
    part def HvConnector;
    part def CellStack;
    part def VentPort;

    // --- Harms: the severity anchors ------------------------------------
    //
    // Every number in the worksheet below traces back to one of these.
    // Between them they span the SeverityScale.

    occurrence operatorFatality : Harm {
        :>> description = "Electrocution of a person servicing the pack";
        :>> severity = SeverityScale::catastrophic;
    }

    occurrence burnAndPropertyLoss : Harm {
        :>> description = "Burn injury to operator; loss of vehicle";
        :>> severity = SeverityScale::critical;
    }

    occurrence chemicalBurn : Harm {
        :>> description = "Chemical burn from electrolyte contact";
        :>> severity = SeverityScale::serious;
    }

    occurrence respiratoryIrritation : Harm {
        :>> description = "Respiratory irritation from vented cell gas";
        :>> severity = SeverityScale::minor;
    }

    occurrence serviceInterruption : Harm {
        :>> description = "Mission cut short; unscheduled pack replacement";
        :>> severity = SeverityScale::negligible;
    }

    // --- Hazards and the situations that expose people to them ----------

    occurrence fireHazard : Hazard {
        :>> description = "Lithium cell fire during charge or discharge";
    }

    occurrence overchargeHazard : Hazard {
        :>> description = "Cell driven above its upper voltage limit";
    }

    occurrence shockHazard : Hazard {
        :>> description = "Exposed high-voltage DC conductor";
    }

    occurrence electrolyteLeakHazard : Hazard {
        :>> description = "Electrolyte escaping a breached cell seal";
    }

    occurrence ventGasHazard : Hazard {
        :>> description = "Toxic gas released through the pack vent";
    }

    occurrence capacityLossHazard : Hazard {
        :>> description = "Usable capacity below the dispatch threshold";
    }

    occurrence fireInOperation : HazardousSituation {
        :>> description = "Cell fire while the vehicle is airborne near people";
        :>> p1 = 0.001;
        :>> p2 = 0.7;
    }

    occurrence chargingUnattended : HazardousSituation {
        :>> description = "Pack left on charge overnight with no one present";
        :>> p1 = 0.02;
        :>> p2 = 0.4;
    }

    occurrence packOpenedForService : HazardousSituation {
        :>> description = "Technician working inside an energised pack";
        :>> p1 = 0.05;
        :>> p2 = 0.3;
    }

    occurrence handlingBreachedCell : HazardousSituation {
        :>> description = "Damaged cell handled without gloves";
        :>> p1 = 0.01;
        :>> p2 = 0.5;
    }

    occurrence ventingInEnclosedSpace : HazardousSituation {
        :>> description = "Pack vents inside a closed hangar";
        :>> p1 = 0.005;
        :>> p2 = 0.6;
    }

    occurrence dispatchWithWeakPack : HazardousSituation {
        :>> description = "Vehicle dispatched on a pack past its usable life";
        :>> p1 = 0.1;
        :>> p2 = 0.9;
    }

    // --- Failure modes with structure worth modelling -------------------

    occurrence thermalRunawayFm : FailureMode {
        :>> cause = "Internal short from dendrite growth";
        :>> effect = "Cell fire propagating through the pack";
        :>> likelihood = 2;
        :>> detection = 4;
    }

    occurrence busbarWeldFm : FailureMode {
        :>> cause = "Porosity in the ultrasonic weld at the busbar joint";
        :>> effect = "Resistive heating at the joint; local ignition";
        :>> likelihood = 3;
        :>> detection = 5;
    }

    occurrence socDriftFm : FailureMode {
        :>> cause = "State-of-charge estimator diverges from true charge";
        :>> effect = "Charging continues past the cell voltage limit";
        :>> likelihood = 2;
        :>> detection = 3;
    }

    // --- Causal chains ---------------------------------------------------
    //
    // Two chains converge on burnAndPropertyLoss: a cell that fails on
    // its own, and a charger that is allowed to overcharge a healthy one.
    // The harm is the same, so the severity is the same, and both
    // worksheet lines below rate at 8 without anyone coordinating.

    connection f1 : Causation connect thermalRunawayFm to fireHazard;
    connection f2 : Causation connect busbarWeldFm to fireHazard;
    connection f3 : Causation connect fireHazard to fireInOperation;
    connection f4 : Causation connect fireInOperation to burnAndPropertyLoss;

    connection o1 : Causation connect socDriftFm to overchargeHazard;
    connection o2 : Causation connect overchargeHazard to chargingUnattended;
    connection o3 : Causation connect chargingUnattended to burnAndPropertyLoss;

    connection s1 : Causation connect shockHazard to packOpenedForService;
    connection s2 : Causation connect packOpenedForService to operatorFatality;

    connection e1 : Causation connect electrolyteLeakHazard to handlingBreachedCell;
    connection e2 : Causation connect handlingBreachedCell to chemicalBurn;

    connection v1 : Causation connect ventGasHazard to ventingInEnclosedSpace;
    connection v2 : Causation connect ventingInEnclosedSpace to respiratoryIrritation;

    connection c1 : Causation connect capacityLossHazard to dispatchWithWeakPack;
    connection c2 : Causation connect dispatchWithWeakPack to serviceInterruption;

    // --- The worksheet ---------------------------------------------------
    //
    // Severity on each line is the anchor of the harm its hazard leads
    // to. The lines differ in category, in likelihood, and in how
    // detectable they are — not in how severity was decided.

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
            severity = 2;
            likelihood = 6;
            detection = 3;
            hazard = capacityLossHazard;
        }
    }

    part cells : CellStack {
        @Fmea {
            failureMode = "Electrolyte seepage at the cell seal";
            cause = "Seal crimp force below specification";
            effect = "Electrolyte on adjacent surfaces; corrosion";
            category = RiskCategory::process;
            severity = 6;
            likelihood = 3;
            detection = 4;
            initialSeverity = 6;
            initialLikelihood = 5;
            initialDetection = 6;
            hazard = electrolyteLeakHazard;
        }
    }

    part busbar : Busbar {
        @Fmea {
            failureMode = "Porosity in the busbar weld";
            cause = "Ultrasonic weld energy drift across the shift";
            effect = "Joint resistance rises; local heating and ignition";
            category = RiskCategory::process;
            severity = 8;
            likelihood = 3;
            detection = 5;
            initialSeverity = 8;
            initialLikelihood = 6;
            initialDetection = 8;
            hazard = fireHazard;
        }
    }

    part hvConnector : HvConnector {
        @Fmea {
            failureMode = "Creepage breakdown across the connector face";
            cause = "Condensation bridging an under-dimensioned creepage path";
            effect = "Live surface reachable during service";
            category = RiskCategory::design;
            severity = 10;
            likelihood = 1;
            detection = 6;
            initialSeverity = 10;
            initialLikelihood = 3;
            initialDetection = 8;
            hazard = shockHazard;
        }
    }

    part bms : Bms {
        @Fmea {
            failureMode = "State-of-charge estimate drifts high";
            cause = "Coulomb-counting error accumulates without a rest recalibration";
            effect = "Charge continues past the cell voltage limit";
            category = RiskCategory::software;
            severity = 8;
            likelihood = 2;
            detection = 3;
            initialSeverity = 8;
            initialLikelihood = 4;
            initialDetection = 7;
            hazard = overchargeHazard;
        }
        @Fmea {
            failureMode = "Cell-voltage sample dropped on the CAN bus";
            cause = "Bus arbitration loss under peak load";
            effect = "Protection acts on a stale voltage";
            category = RiskCategory::software;
            severity = 8;
            likelihood = 3;
            detection = 2;
            hazard = overchargeHazard;
        }
    }

    part vent : VentPort {
        @Fmea {
            failureMode = "Vent port obstructed";
            cause = "Debris or paint ingress during field service";
            effect = "Vent gas escapes into the cabin instead of overboard";
            category = RiskCategory::'use';
            severity = 4;
            likelihood = 2;
            detection = 5;
            hazard = ventGasHazard;
        }
    }

    // --- Risk controls: all three levels of the hierarchy ----------------
    //
    // ISO 14971 prefers controls in this order: design the hazard out,
    // then guard against it, then tell people about it. The `hierarchy`
    // attribute records which one a control is, so a review can ask
    // whether a serious hazard is resting on a label.

    requirement def <'R-BATT-01'> PropagationBarrierReq :> RiskControl {
        doc
        /*
         * A single cell in thermal runaway shall not ignite its
         * neighbours: barriers and spacing shall contain the event to
         * the originating cell.
         */
        subject pack : BatteryPack;
    }

    requirement def <'R-BATT-02'> ThermalCutoffReq :> RiskControl {
        doc
        /*
         * The BMS shall disconnect the pack within 500 ms when any cell
         * exceeds 60 degrees C.
         */
        subject pack : BatteryPack;
    }

    requirement def <'R-BATT-03'> HvInterlockReq :> RiskControl {
        doc
        /*
         * Opening the service panel shall isolate the high-voltage bus
         * and discharge it below 60 V within 5 s.
         */
        subject connector : HvConnector;
    }

    requirement def <'R-BATT-04'> ChargeLimitReq :> RiskControl {
        doc
        /*
         * An independent hardware comparator shall terminate charge on
         * cell overvoltage, without reference to the state-of-charge
         * estimate.
         */
        subject controller : Bms;
    }

    requirement def <'R-BATT-05'> VentPathReq :> RiskControl {
        doc
        /*
         * The pack shall route vent gas overboard through a path that
         * cannot be closed by field service.
         */
        subject ventPort : VentPort;
    }

    requirement def <'R-BATT-06'> ServiceWarningReq :> RiskControl {
        doc
        /*
         * The pack shall carry a durable marking stating the electrolyte
         * hazard and the protective equipment required to handle a
         * damaged cell.
         */
        subject pack : BatteryPack;
    }

    requirement def <'R-BATT-07'> CycleLifeReq {
        doc
        /*
         * The pack shall retain at least 80% of rated capacity after
         * 800 full charge-discharge cycles. Not a risk control: a
         * performance obligation whose failure is a dispatch problem,
         * which is why the harm at the end of its chain is negligible.
         */
        subject stack : CellStack;
    }

    requirement propagationBarrier : PropagationBarrierReq {
        :>> hierarchy = ControlHierarchy::inherentSafety;
        :>> rationale = "Geometry and materials, with nothing to fail or be maintained";
        :>> hazard = fireHazard;
    }

    requirement thermalCutoff : ThermalCutoffReq {
        :>> hierarchy = ControlHierarchy::protectiveMeasure;
        :>> rationale = "Interrupts thermal runaway before propagation";
        :>> hazard = fireHazard;
    }

    requirement hvInterlock : HvInterlockReq {
        :>> hierarchy = ControlHierarchy::protectiveMeasure;
        :>> rationale = "Removes the energy before a person can reach the conductor";
        :>> hazard = shockHazard;
    }

    requirement chargeLimit : ChargeLimitReq {
        :>> hierarchy = ControlHierarchy::protectiveMeasure;
        :>> rationale = "Independent of the software whose error it guards against";
        :>> hazard = overchargeHazard;
    }

    requirement ventPath : VentPathReq {
        :>> hierarchy = ControlHierarchy::inherentSafety;
        :>> rationale = "An unclosable path cannot be obstructed by service error";
        :>> hazard = ventGasHazard;
    }

    requirement serviceWarning : ServiceWarningReq {
        :>> hierarchy = ControlHierarchy::informationForSafety;
        :>> rationale = "Last resort: the residual risk after handling controls";
        :>> hazard = electrolyteLeakHazard;
    }

    requirement cycleLife : CycleLifeReq;

    // --- The work that implements the controls ---------------------------

    action cellSpacingDesign : Mitigation {
        doc /* Barrier and spacing design for propagation containment. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::verified;
        :>> owner = "Pack mechanical";
    }

    action overTempCutoff : Mitigation {
        doc /* Work item implementing the thermal cutoff risk control. */
        :>> kind = MitigationKind::detection;
        :>> status = MitigationStatus::verified;
        :>> owner = "BMS team";
    }

    action interlockCircuit : Mitigation {
        doc /* Service-panel interlock and active discharge circuit. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::completed;
        :>> owner = "HV electrical";
    }

    action redundantOvpComparator : Mitigation {
        doc /* Hardware overvoltage comparator independent of the estimator. */
        :>> kind = MitigationKind::detection;
        :>> status = MitigationStatus::inProgress;
        :>> owner = "BMS team";
    }

    action ventDuctRouting : Mitigation {
        doc /* Overboard vent duct with no serviceable closure. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::completed;
        :>> owner = "Pack mechanical";
    }

    action hazardPlacard : Mitigation {
        doc /* Durable electrolyte-hazard marking and handling instructions. */
        :>> kind = MitigationKind::prevention;
        :>> status = MitigationStatus::proposed;
        :>> owner = "Technical publications";
    }

    satisfy propagationBarrier by battery;
    satisfy thermalCutoff by battery;
    satisfy hvInterlock by hvConnector;
    satisfy chargeLimit by bms;
    satisfy ventPath by vent;
    satisfy serviceWarning by battery;
    satisfy cycleLife by cells;

    // --- Evidence ---------------------------------------------------------

    verification def PropagationTest {
        doc
        /*
         * Force a single cell into runaway with a nail penetration and
         * confirm that no neighbouring cell reaches onset temperature.
         */
        subject pack : BatteryPack;
        objective {
            verify propagationBarrier;
        }
    }

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

    verification def HvSafetyTest {
        doc
        /*
         * Open the service panel under load and measure bus voltage
         * decay, then confirm no reachable conductor stays above 60 V.
         */
        subject connector : HvConnector;
        objective {
            verify hvInterlock;
        }
    }

    verification def OverchargeTest {
        doc
        /*
         * Inject a falsified state-of-charge estimate and confirm the
         * hardware comparator terminates charge regardless.
         */
        subject controller : Bms;
        objective {
            verify chargeLimit;
        }
    }

    verification def VentFlowTest {
        doc
        /*
         * Discharge a gas volume into the pack and measure the fraction
         * reaching the cabin, with the vent path as delivered to service.
         */
        subject ventPort : VentPort;
        objective {
            verify ventPath;
        }
    }

    verification def MarkingInspection {
        doc
        /*
         * Inspect the placard after the environmental and abrasion
         * sequence and confirm it is still legible — information for
         * safety only works while it can be read.
         */
        subject pack : BatteryPack;
        objective {
            verify serviceWarning;
        }
    }

    verification def CycleLifeTest {
        doc
        /*
         * Cycle a sample pack to 800 cycles at rated depth and measure
         * retained capacity.
         */
        subject stack : CellStack;
        objective {
            verify cycleLife;
        }
    }

    verification propagationTest : PropagationTest {
        subject pack = battery;
    }

    verification thermalCutoffTest : ThermalCutoffTest {
        subject pack = battery;
    }

    verification hvSafetyTest : HvSafetyTest {
        subject connector = hvConnector;
    }

    verification overchargeTest : OverchargeTest {
        subject controller = bms;
    }

    verification ventFlowTest : VentFlowTest {
        subject ventPort = vent;
    }

    verification markingInspection : MarkingInspection {
        subject pack = battery;
    }

    verification cycleLifeTest : CycleLifeTest {
        subject stack = cells;
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

    view def SoftwareRisks {
        doc
        /*
         * One category's lines, for the review that owns them. The same
         * view with a different category is another team's agenda —
         * which is the argument for filtering in the model rather than
         * asking a tool for a `--category` flag.
         */
        @TableRendering {
            rows = "@Fmea";
            columns = "element; failureMode; cause; severity; likelihood; detection; rpn = severity*likelihood*detection";
            where = "category == \"software\"";
            sortBy = "-rpn";
        }
    }

    view def UndetectableRisks {
        doc
        /*
         * Lines the pack cannot detect on its own (detection rating 5 or
         * worse), regardless of how likely they are. A high-severity
         * failure nobody can see coming is a different problem from a
         * high-RPN one, and it does not surface on an RPN-sorted sheet.
         */
        @TableRendering {
            rows = "@Fmea";
            columns = "element; failureMode; category; severity; detection";
            where = "detection >= 5";
            sortBy = "-severity";
        }
    }

    view def ControlCoverage {
        doc
        /*
         * Every risk control with the hazard it addresses and where it
         * sits in the ISO 14971 hierarchy, so a review can see what is
         * carried by design and what is carried by a label.
         */
        @TableRendering {
            rows = "type:RiskControl";
            columns = "element; type; hierarchy; hazard; rationale";
            sortBy = "hierarchy";
        }
    }
}
