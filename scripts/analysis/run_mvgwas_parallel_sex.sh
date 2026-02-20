#!/usr/bin/env bash
set -euo pipefail

# SLURM array task runner for sex-stratified mvgwas-nf.
# Expects environment variables exported by submit_gwas_pipeline_sex.sh:
#   BASE_DIR, VCF, PIPELINE, TASK_FILE, CHR_PREFIX,
#   MALE_PHENO, MALE_COV, FEMALE_PHENO, FEMALE_COV,
#   WITH_SING, RESUME, WINDOW_L

# shellcheck source=scripts/analysis/utils.sh
source scripts/analysis/utils.sh

: "${BASE_DIR:?missing BASE_DIR}"
: "${VCF:?missing VCF}"
: "${PIPELINE:?missing PIPELINE}"
: "${TASK_FILE:?missing TASK_FILE}"
: "${CHR_PREFIX:=}"
: "${WITH_SING:=1}"
: "${RESUME:=1}"
: "${WINDOW_L:=500}"

TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
(( TASK_ID > 0 )) || die "SLURM_ARRAY_TASK_ID is not set (are you running under sbatch --array?)"

# Read the Nth task (skip header)
LINE="$(awk -v n="$TASK_ID" 'NR==n+1{print; exit}' "$TASK_FILE")"
[[ -n "$LINE" ]] || die "No task line for TASK_ID=$TASK_ID in $TASK_FILE"

SEX="$(echo "$LINE" | awk -F'\t' '{print $1}')"
CHR="$(echo "$LINE" | awk -F'\t' '{print $2}')"

case "$SEX" in
  male)
    PHENO="${MALE_PHENO:?missing MALE_PHENO}"
    COV="${MALE_COV:?missing MALE_COV}"
    RESULTS_DIR="${BASE_DIR}/results_male"
    ;;
  female)
    PHENO="${FEMALE_PHENO:?missing FEMALE_PHENO}"
    COV="${FEMALE_COV:?missing FEMALE_COV}"
    RESULTS_DIR="${BASE_DIR}/results_female"
    ;;
  *) die "Invalid sex in task file: '$SEX'";;
esac

need_cmd bcftools
need_cmd nextflow
need_cmd java

mkdir -p "${RESULTS_DIR}/chr${CHR}"
TMP_DIR="${BASE_DIR}/derived/tmp_chr_vcf/${SEX}"
mkdir -p "$TMP_DIR"

# Extract chromosome VCF
REGION="${CHR_PREFIX}${CHR}"
CHR_VCF="${TMP_DIR}/chr${CHR}.vcf.gz"

echo "=========================================="
echo "[task] sex=${SEX} chr=${CHR}"
echo "[task] VCF=${VCF}"
echo "[task] region=${REGION}"
echo "[task] pheno=${PHENO}"
echo "[task] cov=${COV}"
echo "=========================================="

# Note: we always re-create chr VCF to avoid subtle contamination; user can clear TMP_DIR if needed.
bcftools view -r "$REGION" "$VCF" -Oz -o "$CHR_VCF"
bcftools index -t "$CHR_VCF"

OUTPUT_DIR="${RESULTS_DIR}/chr${CHR}"
OUT_TSV="mvgwas_chr${CHR}.tsv"

NF_CMD=(nextflow run "${PIPELINE}/mvgwas.nf"
  --geno "$CHR_VCF"
  --pheno "$PHENO"
  --cov "$COV"
  --dir "$OUTPUT_DIR"
  --out "$OUT_TSV"
  --l "$WINDOW_L"
)

if [[ "$WITH_SING" == "1" ]]; then
  NF_CMD+=(-with-singularity)
fi
if [[ "$RESUME" == "1" ]]; then
  NF_CMD+=(-resume)
fi

echo "[task] nextflow cmd: ${NF_CMD[*]}"
cd "$OUTPUT_DIR"
"${NF_CMD[@]}"

echo "[task] done. results: ${OUTPUT_DIR}/${OUT_TSV}"
