\
#!/bin/bash
# =============================================================================
# merge_results_auto.sh
# =============================================================================
# Merges chromosome results into a single TSV.
# Default: merges non-sex results from BASE_DIR/results/chr*/mvgwas_chr*.tsv
# If --sex is provided (female|male|both|auto), merges sex-stratified outputs too.
# =============================================================================

#SBATCH --job-name=merge_gwas_auto
#SBATCH --output=logs/merge_gwas_auto_%j.out
#SBATCH --error=logs/merge_gwas_auto_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

set -euo pipefail

SEX_MODE="auto"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sex) SEX_MODE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sbatch merge_results_auto.sh [--sex auto|none|female|male|both]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
DATA_DIR_F="${BASE_DIR}/data_female"
DATA_DIR_M="${BASE_DIR}/data_male"

RESULTS_BASE="${BASE_DIR}/results"
RESULTS_F="${BASE_DIR}/results_female"
RESULTS_M="${BASE_DIR}/results_male"

mkdir -p "${BASE_DIR}/logs"

auto_detect_both() {
  [[ -d "${DATA_DIR_F}" && -d "${DATA_DIR_M}" ]] || return 1
  [[ -d "${RESULTS_F}" && -d "${RESULTS_M}" ]] || return 1
  return 0
}

if [[ "${SEX_MODE}" == "auto" ]]; then
  if auto_detect_both; then SEX_MODE="both"; else SEX_MODE="none"; fi
fi

merge_one () {
  local label="$1"
  local dir="$2"
  local out="${dir}/mvgwas_wmh_${label}.tsv"

  rm -f "${out}"
  # header
  for chr in $(seq 1 22); do
    f="${dir}/chr${chr}/mvgwas_chr${chr}.tsv"
    if [[ -f "$f" ]]; then head -1 "$f" > "${out}"; break; fi
  done
  # data
  for chr in $(seq 1 22); do
    f="${dir}/chr${chr}/mvgwas_chr${chr}.tsv"
    if [[ -f "$f" ]]; then tail -n +2 "$f" >> "${out}"; fi
  done
  echo "Merged: ${out}"
}

echo "Merging mode: ${SEX_MODE}"
if [[ "${SEX_MODE}" == "both" ]]; then
  merge_one "female" "${RESULTS_F}"
  merge_one "male"   "${RESULTS_M}"
elif [[ "${SEX_MODE}" == "female" ]]; then
  merge_one "female" "${RESULTS_F}"
elif [[ "${SEX_MODE}" == "male" ]]; then
  merge_one "male" "${RESULTS_M}"
else
  merge_one "all" "${RESULTS_BASE}"
fi
