package ShaftFitsExample {
    doc
    /*
     * Fits and material conditions: one Ø20 H7 bore size mated to three
     * different shaft grades, giving a clearance, a transition, and an
     * interference fit from the same hole.
     *
     * The point of the example is that the fit type is not declared, it
     * is computed. Each mate has a `expectedFit` stating design intent;
     * beside it a ToleranceStackup subtracts the shaft dimension from the
     * bore dimension, and the worst-case range of that chain IS the fit:
     *
     *   wcMin = smallest bore - largest shaft   = clearance at MMC
     *   wcMax = largest bore  - smallest shaft  = clearance at LMC
     *
     * MMC (maximum material condition) is the most material in both
     * parts, so it is the tightest the fit can be; LMC is the loosest.
     * The library's MinClearance / MaxClearance calcs are these two
     * expressions. Classification then follows from the signs:
     *
     *   clearance     wcMin > 0        loose at both extremes
     *   transition    wcMin < 0 < wcMax  either, depending on the parts
     *   interference  wcMax < 0        tight at both extremes
     *
     * Limits are ISO 286 for the 18..30 mm step. A drawing states them
     * as a basic size with deviations (Ø20 H7 is +0.021/0); each
     * dimension here carries that callout in its doc and states the
     * value as the mid-size with a symmetric half-tolerance
     * (20.0105 +/-0.0105). The limits are identical either way, so the
     * worst-case fit is unchanged — but `nominal` is the distribution
     * mean for RSS and Monte Carlo, and only the mid-size makes that
     * mean true. Stating an ISO grade at its basic size instead would
     * leave the worst-case numbers right and every capability number
     * wrong.
     *
     * Evaluate:
     *   sysml analyze run -I libraries examples/ShaftFits.sysml -n guideFit
     *
     * Report:
     *   sysml view StackupSummary -I libraries examples/ShaftFits.sysml
     *   sysml view FitTable       -I libraries examples/ShaftFits.sysml
     *   sysml view ToleranceAnalysis -I libraries examples/ShaftFits.sysml
     */

    private import ScalarValues::*;
    private import Uncertainty::*;
    private import Tolerancing::*;
    private import Reporting::*;

    // --- The common bore ------------------------------------------------
    //
    // All three bores are Ø20 H7 (+0.021/0) — one reamer, one size. Only
    // the shaft grade changes, so the fit type is the shaft's doing.

    part def Housing {
        doc /* Carrier plate with three Ø20 H7 bores. DWG-SF-001 */

        item guideBore : GeometricFeature {
            :>> form = FeatureForm::hole;
            :>> nature = FeatureNature::internal;
            :>> datum = "A";
            attribute diameter : TolerancedDimension {
                doc /* Ø20 H7 (+0.021/0), limits 20.000..20.021 */
                :>> nominal = 20.0105;
                :>> plus = 0.0105;
                :>> minus = 0.0105;
            }
        }

        item dowelBore : GeometricFeature {
            :>> form = FeatureForm::hole;
            :>> nature = FeatureNature::internal;
            attribute diameter : TolerancedDimension {
                doc /* Ø20 H7 (+0.021/0), limits 20.000..20.021 */
                :>> nominal = 20.0105;
                :>> plus = 0.0105;
                :>> minus = 0.0105;
            }
        }

        item sleeveBore : GeometricFeature {
            :>> form = FeatureForm::hole;
            :>> nature = FeatureNature::internal;
            attribute diameter : TolerancedDimension {
                doc /* Ø20 H7 (+0.021/0), limits 20.000..20.021 */
                :>> nominal = 20.0105;
                :>> plus = 0.0105;
                :>> minus = 0.0105;
            }
        }

        attribute thickness : TolerancedDimension {
            doc /* Plate thickness. DWG-SF-001 */
            :>> nominal = 12.0;
            :>> plus = 0.1;
            :>> minus = 0.1;
        }
    }

    // --- Three shafts, three grades -------------------------------------

    part def GuidePin {
        doc
        /*
         * Ø20 g6 (-0.007/-0.020): a running clearance fit. The pin must
         * slide, so the bore must be larger than the pin at every
         * combination of limits.
         */
        item od : GeometricFeature {
            :>> form = FeatureForm::shaft;
            :>> nature = FeatureNature::external;
            attribute diameter : TolerancedDimension {
                doc /* Ø20 g6 (-0.007/-0.020), limits 19.980..19.993. DWG-SF-002 */
                :>> nominal = 19.9865;
                :>> plus = 0.0065;
                :>> minus = 0.0065;
            }
        }
        attribute length : TolerancedDimension {
            doc /* DWG-SF-002 */
            :>> nominal = 30.0;
            :>> plus = 0.1;
            :>> minus = 0.1;
        }
    }

    part def LocatingDowel {
        doc
        /*
         * Ø20 k6 (+0.015/+0.002): a transition fit. Whether an individual
         * pair ends up tight or loose depends on where each part falls in
         * its tolerance — that is the defining property of a transition
         * fit, and the reason it is used for location rather than for
         * torque transmission or for sliding.
         */
        item od : GeometricFeature {
            :>> form = FeatureForm::shaft;
            :>> nature = FeatureNature::external;
            attribute diameter : TolerancedDimension {
                doc /* Ø20 k6 (+0.015/+0.002), limits 20.002..20.015. DWG-SF-003 */
                :>> nominal = 20.0085;
                :>> plus = 0.0065;
                :>> minus = 0.0065;
            }
        }
    }

    part def BearingSleeve {
        doc
        /*
         * Ø20 p6 (+0.035/+0.022): a press fit. The sleeve is always
         * larger than the bore, so it is retained by interference alone.
         */
        item od : GeometricFeature {
            :>> form = FeatureForm::shaft;
            :>> nature = FeatureNature::external;
            attribute diameter : TolerancedDimension {
                doc /* Ø20 p6 (+0.035/+0.022), limits 20.022..20.035. DWG-SF-004 */
                :>> nominal = 20.0285;
                :>> plus = 0.0065;
                :>> minus = 0.0065;
            }
        }
        attribute flangeThickness : TolerancedDimension {
            doc /* Seats against the plate face. DWG-SF-004 */
            :>> nominal = 4.0;
            :>> plus = 0.05;
            :>> minus = 0.05;
        }
    }

    part def RetainingRing {
        doc /* Snap ring in a groove on the far side of the plate. */
        attribute thickness : TolerancedDimension {
            doc /* DIN 471 Ø20, vendor limits only. VS-RING-20 */
            :>> nominal = 1.2;
            :>> plus = 0.05;
            :>> minus = 0.05;
            :>> distribution = Distribution::uniform;
        }
    }

    // --- Acceptance policy for the fits that matter --------------------
    //
    // PASS / MARGINAL / FAIL is not arithmetic, it is a project's
    // judgement about how close to a limit is too close, so it lives in
    // the model. `UncertaintyAnalysis::marginalFraction` defaults to
    // 0.10; a fit whose loss is a safety or retention problem is held to
    // a wider band here, and every analysis typed by this def inherits
    // it. Nothing in the tooling changes.

    analysis def CriticalFit :> ToleranceStackup {
        doc
        /*
         * A fit on the critical-to-quality list: report MARGINAL while
         * the worst case sits within a quarter of the tolerance band of
         * a limit, rather than the default tenth.
         */
        attribute :>> marginalFraction = 0.25;
    }

    // --- The assembly: mates and the analyses that classify them --------

    part carrier : CarrierAssembly;

    part def CarrierAssembly {
        part housing : Housing;
        part guide : GuidePin;
        part dowel : LocatingDowel;
        part sleeve : BearingSleeve;
        part ring : RetainingRing;

        connection guideMate : Mate connect guide.od to housing.guideBore {
            :>> expectedFit = FitType::clearance;
        }
        connection dowelMate : Mate connect dowel.od to housing.dowelBore {
            :>> expectedFit = FitType::'transition';
        }
        connection sleeveMate : Mate connect sleeve.od to housing.sleeveBore {
            :>> expectedFit = FitType::interference;
        }

        // A fit is a two-term stackup: bore minus shaft. The worst-case
        // range of that chain is the fit at MMC and at LMC, so the same
        // generic uncertainty analyzer that runs an assembly stackup
        // classifies a fit — no fit-specific machinery.

        analysis guideFit : CriticalFit {
            doc
            /*
             * Ø20 H7/g6. MMC clearance = 20.000 - 19.993 = +0.007;
             * LMC clearance = 20.021 - 19.980 = +0.041. Both positive,
             * so the pin always slides: a clearance fit.
             *
             * Lower limit 0: any interference seizes the pin. Upper
             * limit 0.05: beyond it the guide rattles enough to lose
             * positional accuracy.
             *
             * Typed CriticalFit, so 7 microns of guaranteed clearance
             * reads as MARGINAL: it clears every limit, but not by
             * enough that a review should wave it through. Under the
             * library default it would report a clean PASS.
             */
            attribute :>> target {
                :>> nominal = 0.024;
                :>> lower = 0.0;
                :>> upper = 0.05;
            }
            attribute :>> critical = true;

            attribute bore :> contributions {
                :>> dim = housing.guideBore.diameter;
                :>> sense = Sense::positive;
                :>> source = "DWG-SF-001";
            }
            attribute pin :> contributions {
                :>> dim = guide.od.diameter;
                :>> sense = Sense::negative;
                :>> source = "DWG-SF-002";
            }
        }

        analysis dowelFit : ToleranceStackup {
            doc
            /*
             * Ø20 H7/k6. MMC clearance = 20.000 - 20.015 = -0.015
             * (interference); LMC clearance = 20.021 - 20.002 = +0.019
             * (clearance). The range straddles zero, which is what makes
             * it a transition fit: some pairs press, some slip.
             */
            attribute :>> target {
                :>> nominal = 0.002;
                :>> lower = -0.025;
                :>> upper = 0.025;
            }

            attribute bore :> contributions {
                :>> dim = housing.dowelBore.diameter;
                :>> sense = Sense::positive;
                :>> source = "DWG-SF-001";
            }
            attribute pin :> contributions {
                :>> dim = dowel.od.diameter;
                :>> sense = Sense::negative;
                :>> source = "DWG-SF-003";
            }
        }

        analysis sleeveFit : CriticalFit {
            doc
            /*
             * Ø20 H7/p6. MMC clearance = 20.000 - 20.035 = -0.035;
             * LMC clearance = 20.021 - 20.022 = -0.001. Never positive,
             * so the sleeve is always gripped: an interference fit. Note
             * how little margin LMC leaves — a bore at its high limit
             * against a sleeve at its low limit holds by one micron, and
             * that is the case the press-out force requirement has to
             * survive.
             */
            attribute :>> target {
                :>> nominal = -0.018;
                :>> lower = -0.05;
                :>> upper = 0.0;
            }
            attribute :>> critical = true;

            attribute bore :> contributions {
                :>> dim = housing.sleeveBore.diameter;
                :>> sense = Sense::positive;
                :>> source = "DWG-SF-001";
            }
            attribute sleeveOd :> contributions {
                :>> dim = sleeve.od.diameter;
                :>> sense = Sense::negative;
                :>> source = "DWG-SF-004";
            }
        }

        // An axial chain alongside the diametral ones, so the example
        // shows a stackup that is not a fit.
        analysis ringGap : ToleranceStackup {
            doc
            /*
             * Axial clearance behind the retaining ring:
             *   gap = plate thickness - sleeve flange - ring thickness
             * Too little and the ring will not seat in its groove; too
             * much and the stack rattles.
             */
            attribute :>> target {
                :>> nominal = 6.8;
                :>> lower = 6.5;
                :>> upper = 7.1;
            }
            attribute :>> meanShiftK = 1.5;

            attribute plate :> contributions {
                :>> dim = housing.thickness;
                :>> sense = Sense::positive;
                :>> source = "DWG-SF-001";
            }
            attribute flange :> contributions {
                :>> dim = sleeve.flangeThickness;
                :>> sense = Sense::negative;
                :>> source = "DWG-SF-004";
            }
            attribute snapRing :> contributions {
                :>> dim = ring.thickness;
                :>> sense = Sense::negative;
                :>> source = "VS-RING-20";
            }
        }
    }

    // --- What the fits have to deliver ----------------------------------

    requirement def <'SF-01'> GuideSlidesReq {
        doc
        /*
         * The guide pin shall retain positive clearance in its bore at
         * all combinations of limits, so it slides without seizing.
         */
        subject asm : CarrierAssembly;
    }

    requirement def <'SF-02'> SleeveRetainedReq {
        doc
        /*
         * The bearing sleeve shall remain in interference with its bore
         * at all combinations of limits, so it is retained without a
         * secondary feature.
         */
        subject asm : CarrierAssembly;
    }

    requirement guideSlides : GuideSlidesReq;
    requirement sleeveRetained : SleeveRetainedReq;

    satisfy guideSlides by carrier;
    satisfy sleeveRetained by carrier;

    verification def FitGaugeTest {
        doc
        /*
         * Gauge the bores and the mating diameters on a sample spanning
         * the tolerance range, then confirm assembly behaviour: the
         * guide slides by hand, the sleeve requires the press.
         */
        subject asm : CarrierAssembly;
        objective {
            verify guideSlides;
            verify sleeveRetained;
        }
    }

    verification fitGaugeTest : FitGaugeTest {
        subject asm = carrier;
    }

    // --- Project-specific views -----------------------------------------

    view def ToleranceAnalysis {
        doc
        /*
         * Every chain in the model against the limits it is held to.
         * `nominal`, `lower` and `upper` are the declared target — what
         * the design asked for — and `wcMin`/`wcMax` are what the
         * tolerances deliver, so a row is readable without opening the
         * source.
         *
         * For the three fits, `wcMin` is the clearance at MMC and
         * `wcMax` the clearance at LMC, so the pair of signs reads off
         * the fit type directly: both positive is clearance, both
         * negative is interference, and a sign change is a transition.
         * `ringGap` is an axial chain rather than a fit, which is why it
         * sits at millimetre scale.
         *
         * The two CriticalFit rows are judged against a wider marginal
         * band than the others — see the acceptance policy above. Every
         * row here passes its worst-case limits; MARGINAL means "review
         * this", not "out of tolerance".
         */
        @TableRendering {
            rows = "uncertainty";
            columns = "case; critical; nominal; lower; upper; wcMin; wcMax; margin; cpk; result";
            sortBy = "wcMin";
        }
    }

    view def PressFits {
        doc
        /*
         * Every chain that is in interference at MMC — the ones needing
         * a press, a temperature differential, or a retention
         * calculation. Filtering on the computed value rather than on a
         * declared label means a retolerancing that turns a transition
         * fit into a press fit shows up here without anyone editing a
         * list.
         */
        @TableRendering {
            rows = "uncertainty";
            columns = "case; wcMin; wcMax; result";
            where = "wcMin < 0";
            sortBy = "wcMin";
        }
    }
}
