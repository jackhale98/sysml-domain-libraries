#!/bin/sh
# Validate the libraries and examples against the OMG SysML v2 Pilot
# Implementation — the reference implementation is the conformance
# oracle, so our models must satisfy ITS parser and semantic checks,
# not just our own tooling's.
#
# Requirements:
#   - Java 21+
#   - PILOT_JAR: the jupyter-sysml-kernel all-in-one jar
#     (conda-forge jupyter-sysml-kernel package, share/jupyter/kernels/
#     sysml/jupyter-sysml-kernel-<ver>-all.jar)
#   - SYSML_STDLIB: path to the release's sysml.library directory
#
# Each file is squashed to one line (the console is line-oriented) with
# `//` comments stripped; files are fed in dependency order in ONE pilot
# session so cross-library references resolve. Any ERROR line fails.
set -u
cd "$(dirname "$0")/.."

PILOT_JAR="${PILOT_JAR:?set PILOT_JAR to the jupyter-sysml-kernel all jar}"
SYSML_STDLIB="${SYSML_STDLIB:?set SYSML_STDLIB to the sysml.library directory}"

# Dependency order: Reporting and Uncertainty first, then the packages
# that import them, then the examples.
FILES="libraries/Reporting.sysml
libraries/ModelQuality.sysml
libraries/Uncertainty.sysml
libraries/Tolerancing.sysml
libraries/HazardAnalysis.sysml
libraries/RiskAnalysis.sysml
examples/EnclosureGap.sysml
examples/BatteryFmea.sysml
examples/ReliefValve.sysml
examples/ShaftFits.sysml"

INPUT=$(mktemp); OUTPUT=$(mktemp); MAP=$(mktemp)
trap 'rm -f "$INPUT" "$OUTPUT" "$MAP"' EXIT

n=1
for f in $FILES; do
    sed 's|//.*$||' "$f" | tr '\n' ' ' >> "$INPUT"
    printf '\n' >> "$INPUT"
    printf '%s %s\n' "$n" "$f" >> "$MAP"
    n=$((n+1))
done
printf '%%exit\n' >> "$INPUT"

java -cp "$PILOT_JAR" org.omg.sysml.interactive.SysMLInteractive \
    "$SYSML_STDLIB" < "$INPUT" > "$OUTPUT" 2>&1

STATUS=0
sed 's/^[0-9]*> //' "$OUTPUT" | grep -E "^(ERROR|WARNING)" | while IFS= read -r line; do
    # Error lines reference the input index as "<n>.sysml"
    idx=$(printf '%s' "$line" | grep -oE '\(([0-9]+)\.sysml' | grep -oE '[0-9]+' | head -1)
    file=$(awk -v i="$idx" '$1 == i {print $2}' "$MAP")
    printf 'PILOT %s [%s]\n' "$line" "${file:-unknown}"
done > "$OUTPUT.errs"
cat "$OUTPUT.errs"
if grep -q "^PILOT ERROR" "$OUTPUT.errs"; then
    STATUS=1
fi
rm -f "$OUTPUT.errs"

if [ "$STATUS" -eq 0 ]; then
    echo "pilot-validate: all files accepted by the OMG pilot implementation"
else
    echo "pilot-validate: FAILURES (see PILOT ERROR lines above)"
fi
exit $STATUS
