#!/bin/sh
# Validate all libraries and examples with two independent implementations:
#   1. sysml check       — semantic: name resolution, constraints, lints
#   2. tree-sitter parse — independent syntax check (runs when a built
#                          tree-sitter-sysml checkout is available)
#
# Fails on any error[] or warning[] diagnostic; note[] diagnostics are
# allowed (library defs are legitimately unreferenced within this repo).
set -u
cd "$(dirname "$0")/.."

fail=0

if ! command -v sysml >/dev/null 2>&1; then
    echo "error: sysml not found on PATH (https://github.com/jackhale98/sysml-cli)" >&2
    exit 1
fi

out=$(sysml check -I libraries libraries/*.sysml examples/*.sysml 2>&1)
status=$?
echo "$out"
if [ $status -ne 0 ]; then
    fail=1
fi
if echo "$out" | grep -qE 'error\[|warning\['; then
    echo "validate: sysml check reported errors or warnings" >&2
    fail=1
fi

TS_DIR="${TREE_SITTER_SYSML_DIR:-../tree-sitter-sysml}"
TS_BIN="$TS_DIR/node_modules/.bin/tree-sitter"
if [ -x "$TS_BIN" ]; then
    for f in libraries/*.sysml examples/*.sysml; do
        if ! (cd "$TS_DIR" && "$TS_BIN" parse "$OLDPWD/$f" --quiet >/dev/null 2>&1); then
            echo "validate: tree-sitter parse failed: $f" >&2
            fail=1
        fi
    done
    echo "tree-sitter: all files parsed"
else
    echo "tree-sitter: skipped (no built checkout at $TS_DIR; set TREE_SITTER_SYSML_DIR)"
fi

if [ $fail -eq 0 ]; then
    echo "validate: OK"
fi
exit $fail
