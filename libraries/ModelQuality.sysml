package ModelQuality {
    doc
    /*
     * Model-completeness scoring vocabulary.
     *
     * `sysml coverage` computes four metric percentages and looks for a
     * calc named QualityScore in the loaded model. When one is present
     * (import this package, or declare your own), its return expression
     * is evaluated for the overall score; otherwise the tool falls back
     * to equal weighting. The parameter vocabulary is fixed — the tool
     * binds these four names, each 0-100 — but the expression may use
     * any subset with any weighting, so scoring policy lives in the
     * model, not in tool configuration:
     *
     *   calc def QualityScore {
     *       in documented : Real;
     *       in typedUsages : Real;
     *       in reqSatisfied : Real;
     *       in reqVerified : Real;
     *       return : Real = documented * 0.1 + typedUsages * 0.1
     *                     + reqSatisfied * 0.4 + reqVerified * 0.4;
     *   }
     *
     * Gate CI on the result with:
     *   sysml coverage --check --min-score 80 -I libraries src/*.sysml
     */

    private import ScalarValues::*;

    calc def QualityScore {
        doc
        /*
         * Overall model quality score, 0-100: the default equal
         * weighting of documentation coverage, usage typing, and
         * requirement satisfaction/verification.
         */
        in documented : Real;
        in typedUsages : Real;
        in reqSatisfied : Real;
        in reqVerified : Real;
        return : Real = documented * 0.25 + typedUsages * 0.25
                      + reqSatisfied * 0.25 + reqVerified * 0.25;
    }
}
