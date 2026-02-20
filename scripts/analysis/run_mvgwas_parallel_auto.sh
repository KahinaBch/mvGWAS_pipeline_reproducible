\
#!/bin/bash
# =============================================================================
# run_mvgwas_parallel_auto.sh
# =============================================================================
# Runs mvGWAS either:
#   (A) non-sex-stratified (default) using BASE_DIR/data/
#   (B) sex-stratified if --sex is provided OR if both data_female/ and data_male/ exist
#
# Non-sex input dir (default):
#   /home/kbaouche/mvGWAS_WMHv/data/
#     geno_ALFA_for_gwas.vcf.gz
#     WMH_phenotypes_complete.tsv
#     WMH_covariates_complete.tsv
#
# Sex-stratified input dirs:
#   /home/kbaouche/mvGWAS_WMHv/data_female/
#   /home/kbaouche/mvGWAS_WMHv/data_male/
#
# Array layout:
#   non-sex: 1..22 (chr)
#   sex:     1..44 (female chr1..22, male chr1..22)
#
# Submit examples:
#   sbatch run_mvgwas_parallel_auto.sh
#   sbatch --array=3,10,15,16 run_mvgwas_parallel_auto.sh                # non-sex selected chr
#   sbatch --array=3,10,15,16,25,32,37,38 run_mvgwas_parallel_auto.sh --sex both  # sex selected chr
# =============================================================================

#SBATCH --job-name=mvgwas_wmhv_auto
#SBATCH --output=logs/mvgwas_wmhv_auto_%A_%a.out
#SBATCH --error=logs/mvgwas_wmhv_auto_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --partition=genoa
# NOTE: we do NOT hard-code --array here so the user can override at submission time.
# If you want defaults, submit script will set the array.

set -euo pipefail

# -----------------------------------------------------------------------------
# CLI (very small): optional --sex {none|female|male|both|auto}
# -----------------------------------------------------------------------------
SEX_MODE="auto"
CHUNK_SIZE=500
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sex) SEX_MODE="$2"; shift 2 ;;
    --l|--chunk|--chunk-size) CHUNK_SIZE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sbatch run_mvgwas_parallel_auto.sh [--sex auto|none|female|male|both] [--l CHUNK]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
PIPELINE_DIR="/home/kbaouche/mvgwas-nf"

DATA_DIR_BASE="${BASE_DIR}/data"
DATA_DIR_F="${BASE_DIR}/data_female"
DATA_DIR_M="${BASE_DIR}/data_male"

RESULTS_BASE="${BASE_DIR}/results"
RESULTS_F="${BASE_DIR}/results_female"
RESULTS_M="${BASE_DIR}/results_male"

VCF_BASENAME="geno_ALFA_for_gwas.vcf.gz"
PHENO_BASENAME="WMH_phenotypes_complete.tsv"
COV_BASENAME="WMH_covariates_complete.tsv"

mkdir -p "${BASE_DIR}/logs"

# Auto-detect if requested
if [[ "${SEX_MODE}" == "auto" ]]; then
  if [[ -d "${DATA_DIR_F}" && -d "${DATA_DIR_M}" ]]; then
    # require expected files exist for both
    if [[ -f "${DATA_DIR_F}/${VCF_BASENAME}" && -f "${DATA_DIR_M}/${VCF_BASENAME}" \
       && -f "${DATA_DIR_F}/${PHENO_BASENAME}" && -f "${DATA_DIR_M}/${PHENO_BASENAME}" \
       && -f "${DATA_DIR_F}/${COV_BASENAME}" && -f "${DATA_DIR_M}/${COV_BASENAME}" ]]; then
      SEX_MODE="both"
    else
      SEX_MODE="none"
    fi
  else
    SEX_MODE="none"
  fi
fi

TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
if [[ "${TASK_ID}" -le 0 ]]; then
  echo "ERROR: This script is intended to be run under SLURM with an array task id." >&2
  echo "Submit with sbatch --array=... run_mvgwas_parallel_auto.sh" >&2
  exit 1
fi

# Determine which run this task represents
SEX="all"
CHR="${TASK_ID}"
DATA_DIR="${DATA_DIR_BASE}"
RESULTS_DIR="${RESULTS_BASE}"

if [[ "${SEX_MODE}" == "both" ]]; then
  if [[ "${TASK_ID}" -le 22 ]]; then
    SEX="female"; CHR="${TASK_ID}"; DATA_DIR="${DATA_DIR_F}"; RESULTS_DIR="${RESULTS_F}"
  else
    SEX="male"; CHR="$((TASK_ID - 22))"; DATA_DIR="${DATA_DIR_M}"; RESULTS_DIR="${RESULTS_M}"
  fi
elif [[ "${SEX_MODE}" == "female" ]]; then
  SEX="female"; CHR="${TASK_ID}"; DATA_DIR="${DATA_DIR_F}"; RESULTS_DIR="${RESULTS_F}"
elif [[ "${SEX_MODE}" == "male" ]]; then
  SEX="male"; CHR="${TASK_ID}"; DATA_DIR="${DATA_DIR_M}"; RESULTS_DIR="${RESULTS_M}"
else
  # none => non-sex
  SEX="all"; CHR="${TASK_ID}"; DATA_DIR="${DATA_DIR_BASE}"; RESULTS_DIR="${RESULTS_BASE}"
fi

VCF_FILE="${DATA_DIR}/${VCF_BASENAME}"
PHENO_FILE="${DATA_DIR}/${PHENO_BASENAME}"
COV_FILE="${DATA_DIR}/${COV_BASENAME}"

TEMP_DIR="${DATA_DIR}/temp_chr_vcf"
CHR_VCF="${TEMP_DIR}/${SEX}_chr${CHR}.vcf.gz"

echo "=========================================="
echo "mvGWAS auto runner"
echo "SEX_MODE: ${SEX_MODE}"
echo "SEX:      ${SEX}"
echo "CHR:      ${CHR}"
echo "DATA_DIR: ${DATA_DIR}"
echo "OUT_DIR:  ${RESULTS_DIR}/chr${CHR}"
echo "Date:     $(date)"
echo "=========================================="

mkdir -p "${RESULTS_DIR}/chr${CHR}" "${TEMP_DIR}"

for f in "${VCF_FILE}" "${PHENO_FILE}" "${COV_FILE}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing required input: $f" >&2
    exit 1
  fi
done

# Modules (adjust to your cluster)
module purge || true
module load 2025 || true
module load BCFtools/1.22-GCC-14.2.0 || true
module load Java/21.0.7 || true

# Create chr VCF if needed
if [[ ! -f "${CHR_VCF}" ]]; then
  bcftools view -r "${CHR}" "${VCF_FILE}" -Oz -o "${CHR_VCF}"
  bcftools index -t "${CHR_VCF}"
fi

OUTPUT_DIR="${RESULTS_DIR}/chr${CHR}"
cd "${OUTPUT_DIR}"

nextflow run "${PIPELINE_DIR}/mvgwas.nf" \
  --geno "${CHR_VCF}" \
  --pheno "${PHENO_FILE}" \
  --cov "${COV_FILE}" \
  --dir "${OUTPUT_DIR}" \
  --out "mvgwas_chr${CHR}.tsv" \
  --l "${CHUNK_SIZE}" \
  -with-singularity \
  -resume
