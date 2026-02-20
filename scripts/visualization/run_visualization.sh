#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source scripts/common.sh

usage() {
  cat <<'EOF'
run_visualization.sh
Generates basic QQ and Manhattan plots for merged male/female outputs.

Required:
  --dry-run            Validate inputs and print Rscript commands only (optional)

Required:
  --merged-male <TSV>
  --merged-female <TSV>
  --outdir <DIR>

Example:
  bash scripts/visualization/run_visualization.sh \
    --merged-male /home/user/mvGWAS_WMHv/results_merged/mvgwas_merged_male.tsv \
    --merged-female /home/user/mvGWAS_WMHv/results_merged/mvgwas_merged_female.tsv \
    --outdir /home/user/mvGWAS_WMHv/results/figures
EOF
}

MM=""; MF=""; OUTDIR=""
DRY_RUN="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --merged-male) MM="$2"; shift 2;;
    --merged-female) MF="$2"; shift 2;;
    --dry-run) DRY_RUN="1"; shift 1;;
    --outdir) OUTDIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$MM" && -n "$MF" && -n "$OUTDIR" ]] || { usage; exit 1; }
[[ -f "$MM" ]] || { echo "Missing: $MM" >&2; exit 1; }
[[ -f "$MF" ]] || { echo "Missing: $MF" >&2; exit 1; }
mkdir -p "$OUTDIR"

run_cmd Rscript scripts/visualization/qqplot.R "$MM" "${OUTDIR}/qq_male.png"
run_cmd Rscript scripts/visualization/qqplot.R "$MF" "${OUTDIR}/qq_female.png"
run_cmd Rscript scripts/visualization/manhattan.R "$MM" "${OUTDIR}/manhattan_male.png"
run_cmd Rscript scripts/visualization/manhattan.R "$MF" "${OUTDIR}/manhattan_female.png"

echo "[viz] Wrote plots to: $OUTDIR"
