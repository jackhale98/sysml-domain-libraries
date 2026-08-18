package EnclosureGapExample {
    doc
    /*
     * Tolerance stackup example: assembly clearance gap in a sealed
     * enclosure. The gap between the housing floor and the cover,
     * across a compressed gasket, must stay within 0.5..1.5 mm for
     * proper sealing without over-compression.
     *
     * Demonstrates:
     * - toleranced dimensions declared once, on their features
     * - a mate between the cover pilot and the housing bore
     * - a stackup whose contributions reference those dimensions
     *   through feature chains (no value duplication)
     *
     * Evaluate:
     *   sysml analyze run -I libraries examples/EnclosureGap.sysml -n gapAnalysis
     *   sysml analyze run -I libraries examples/EnclosureGap.sysml \
     *       -n gapAnalysis --method monte-carlo --iterations 50000 --seed 12345
     *
     * Report:
     *   sysml view StackupSummary    (library, generic)
     *   sysml view FitTable          (library, generic)
     *   sysml view GapCapability     (declared below, project-specific)
     */

    private import ScalarValues::*;
    private import Uncertainty::*;
    private import Tolerancing::*;
    private import Reporting::*;  // @TableRendering, for the views below

    part def Housing {
        item bore : GeometricFeature {
            :>> form = FeatureForm::hole;
            :>> nature = FeatureNature::internal;
            :>> datum = "B";
            attribute diameter : TolerancedDimension {
                :>> nominal = 60.0;
                :>> plus = 0.05;
                :>> minus = 0.00;
            }
        }
        attribute depth : TolerancedDimension {
            doc /* DWG-001 Rev A */
            :>> nominal = 50.0;
            :>> plus = 0.1;
            :>> minus = 0.1;
        }
    }

    part def Cover {
        item pilot : GeometricFeature {
            :>> form = FeatureForm::shaft;
            :>> nature = FeatureNature::external;
            attribute diameter : TolerancedDimension {
                :>> nominal = 59.9;
                :>> plus = 0.00;
                :>> minus = 0.05;
            }
        }
        attribute height : TolerancedDimension {
            doc /* DWG-002 Rev A */
            :>> nominal = 45.0;
            :>> plus = 0.08;
            :>> minus = 0.08;
        }
    }

    part def Gasket {
        attribute thickness : TolerancedDimension {
            doc /* Vendor spec; only limits are known, so assume uniform. */
            :>> nominal = 2.0;
            :>> plus = 0.15;
            :>> minus = 0.10;
            :>> distribution = Distribution::uniform;
        }
    }

    part enclosure : Enclosure;

    part def Enclosure {
        part housing : Housing;
        part cover : Cover;
        part gasket : Gasket;

        connection pilotFit : Mate connect cover.pilot to housing.bore {
            :>> expectedFit = FitType::clearance;
        }

        analysis gapAnalysis : ToleranceStackup {
            doc
            /*
             * Closing dimension: gap = housing.depth - cover.height
             *                          - gasket.thickness
             */
            attribute :>> target {
                :>> nominal = 3.0;
                :>> lower = 2.5;
                :>> upper = 3.5;
            }
            attribute :>> critical = true;
            attribute :>> meanShiftK = 1.5;

            attribute housingDepth :> contributions {
                :>> dim = housing.depth;
                :>> sense = Sense::positive;
                :>> source = "DWG-001 Rev A";
            }
            attribute coverHeight :> contributions {
                :>> dim = cover.height;
                :>> sense = Sense::negative;
                :>> source = "DWG-002 Rev A";
            }
            attribute gasketThickness :> contributions {
                :>> dim = gasket.thickness;
                :>> sense = Sense::negative;
                :>> source = "Vendor spec VS-114";
            }
        }
    }

    // --- Project-specific view -----------------------------------------
    //
    // The library's StackupSummary reports every column; this is the
    // gate this project actually reviews. Writing a `view def` is the
    // whole extension mechanism — no tool change is needed.

    view def GapCapability {
        doc
        /*
         * Process capability gate: stackups whose Cpk falls short of the
         * 1.33 target, worst first. An empty table is the passing
         * result.
         */
        @TableRendering {
            rows = "uncertainty";
            columns = "case; nominal; wcMin; wcMax; margin; cp; cpk; result";
            where = "cpk < 1.33";
            sortBy = "cpk";
        }
    }
}
