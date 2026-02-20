\
#!/bin/bash
# =============================================================================
# submit_gwas_pipeline_auto.sh
# =============================================================================
# Submits the GWAS pipeline with a sensible default:
#   - If sex-stratified inputs exist in data_female/ and data_male/, run both sexes
#   - Otherwise run non-sex (single analysis) using data/
#
# You can override with:
#   --sex none|female|male|both
#   --chrs "3,10,15,16"   (comma-separated list; default: 1-22)
#
# Usage:
#   bash submit_gwas_pipeline_auto.sh
#   bash submit_gwas_pipeline_auto.sh --sex none --chrs "3,10,15,16"
# =============================================================================

set -euo pipefail

SEX_MODE="auto"
CHRS="1-22"
CHUNK_SIZE=500

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sex) SEX_MODE="$2"; shift 2 ;;
    --chrs) CHRS="$2"; shift 2 ;;
    --l|--chunk|--chunk-size) CHUNK_SIZE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash submit_gwas_pipeline_auto.sh [--sex auto|none|female|male|both] [--chrs \"3,10,15,16\"] [--l 500]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
SCR_DIR="${BASE_DIR}/scr"

RUN="${SCR_DIR}/run_mvgwas_parallel_auto.sh"
MERGE="${SCR_DIR}/merge_results_auto.sh"

if [[ ! -f "${RUN}" ]]; then
  echo "ERROR: missing ${RUN}. Copy scr/* into ${SCR_DIR} first." >&2
  exit 1
fi
if [[ ! -f "${MERGE}" ]]; then
  echo "ERROR: missing ${MERGE}. Copy scr/* into ${SCR_DIR} first." >&2
  exit 1
fi

mkdir -p "${BASE_DIR}/logs"

# Build SLURM array spec from CHRS
# - If CHRS already includes dash, keep it; if comma list, keep it.
ARRAY_SPEC="${CHRS}"

# If sex=both, we need to add +22 offset for male tasks
if [[ "${SEX_MODE}" == "both" || "${SEX_MODE}" == "auto" ]]; then
  # If auto, run script will auto-detect, but array size should support both.
  # Expand comma list for offset; if it's a range, just use 1-44.
  if [[ "${CHRS}" == "1-22" ]]; then
    ARRAY_SPEC="1-44"
  else
    # comma list case
    IFS=',' read -r -a chr_list <<< "${CHRS}"
    male_list=()
    for c in "${chr_list[@]}"; do
      c_trim="$(echo "$c" | tr -d ' ')"
      male_list+=("$((c_trim+22))")
    done
    ARRAY_SPEC="$(printf "%s," "${chr_list[@]}")$(printf "%s," "${male_list[@]}")"
    ARRAY_SPEC="${ARRAY_SPEC%,}"
  fi
fi

echo "Submitting mvGWAS pipeline"
echo "  sex mode:  ${SEX_MODE}"
echo "  chrs:      ${CHRS}"
echo "  array:     ${ARRAY_SPEC}"
echo "  chunk:     ${CHUNK_SIZE}"

JOB_ID=$(sbatch --parsable --array="${ARRAY_SPEC}" "${RUN}" --sex "${SEX_MODE}" --l "${CHUNK_SIZE}")
echo "Submitted array job: ${JOB_ID}"

MERGE_ID=$(sbatch --parsable --dependency=afterok:${JOB_ID} "${MERGE}" --sex "${SEX_MODE}")
echo "Submitted merge job: ${MERGE_ID}"
