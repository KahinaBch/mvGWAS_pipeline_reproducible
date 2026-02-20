#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source scripts/common.sh

usage() {
  cat <<'EOF'
run_all.sh
Master entrypoint: preprocessing -> analysis -> visualization.

Required:
  --env <config/paths.env>       Path to env file (copy from config/paths.example.env)

Optional:
  --dry-run                      Check inputs + tool availability; print commands only
  --skip-preprocessing
  --skip-analysis
  --skip-visualization
  --chrs <SPEC>                  Override CHRS from env (e.g. 16,18,20)
  --wait                         Wait for SLURM jobs to finish before merging (analysis stage)

Example:
  cp config/paths.example.env config/paths.env
  # edit config/paths.env
  bash run_all.sh --env config/paths.env --chrs 16,18,20 --wait
EOF
}

ENV_FILE=""
SKIP_PRE=0; SKIP_ANA=0; SKIP_VIZ=0
CHRS_OVERRIDE=""
WAIT_FLAG=""
DRY_RUN="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2;;
    --skip-preprocessing) SKIP_PRE=1; shift 1;;
    --skip-analysis) SKIP_ANA=1; shift 1;;
    --skip-visualization) SKIP_VIZ=1; shift 1;;
    --chrs) CHRS_OVERRIDE="$2"; shift 2;;
    --dry-run) DRY_RUN="1"; shift 1;;
    --wait) WAIT_FLAG="--wait"; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$ENV_FILE" && -f "$ENV_FILE" ]] || { usage; exit 1; }

# shellcheck disable=SC1090
source "$ENV_FILE"

# Defaults / required checks
: "${BASE_DIR:?BASE_DIR missing in env}"
: "${VCF_FILE:=}"
: "${GENO_INPUT:=${VCF_FILE}}"
[[ -n "$GENO_INPUT" ]] || die "GENO_INPUT (or VCF_FILE) missing in env"
: "${PHENOTYPE_FILE:?PHENOTYPE_FILE missing in env}"
: "${COVARIATE_FILE:?COVARIATE_FILE missing in env}"
: "${PIPELINE_DIR:?PIPELINE_DIR missing in env}"

CHRS="${CHRS_OVERRIDE:-${CHRS:-1-22}}"
SEX_COL="${SEX_COL:-sex}"
MALE_CODE="${MALE_CODE:-1}"
FEMALE_CODE="${FEMALE_CODE:-2}"
WITH_SINGULARITY="${WITH_SINGULARITY:-1}"
NEXTFLOW_RESUME="${NEXTFLOW_RESUME:-1}"
WINDOW_L="${WINDOW_L:-500}"

# Basic input checks
[[ -f "$GENO_INPUT" || -f "${GENO_INPUT}.bed" || ( "$GENO_INPUT" == *.bed && -f "$GENO_INPUT" ) ]] || die "GENO_INPUT not found as file or PLINK prefix: $GENO_INPUT"
[[ -f "$PHENOTYPE_FILE" ]] || die "PHENOTYPE_FILE not found: $PHENOTYPE_FILE"
[[ -f "$COVARIATE_FILE" ]] || die "COVARIATE_FILE not found: $COVARIATE_FILE"
[[ -d "$PIPELINE_DIR" ]] || die "PIPELINE_DIR not found: $PIPELINE_DIR"

# Tool availability checks (also in dry-run)
need_cmd python3
need_cmd bash

# Preprocessing dependency
python3 - <<'PY' >/dev/null 2>&1 || die "Python dependency missing: pandas"
import pandas as pd
PY

# Analysis tools (required if analysis stage will run)

# If preprocessing produced a sample-filtered VCF, use it for analysis
FILTERED_VCF="$BASE_DIR/derived/inputs/genotypes.filtered.vcf.gz"
if [[ "$SKIP_PRE" -eq 0 && -f "$FILTERED_VCF" ]]; then
  VCF_FILE="$FILTERED_VCF"
fi
if [[ "$SKIP_ANA" -eq 0 ]]; then
  need_cmd sbatch
  need_cmd bcftools
  need_cmd nextflow
  need_cmd java
fi

# Visualization tools
if [[ "$SKIP_VIZ" -eq 0 ]]; then
  need_cmd Rscript
fi

mkdir -p "$BASE_DIR/logs" "$BASE_DIR/results" "$BASE_DIR/config"

if [[ "$SKIP_PRE" -eq 0 ]]; then
  bash scripts/preprocessing/run_preprocessing.sh \
    --covar "$COVARIATE_FILE" \
    --pheno "$PHENOTYPE_FILE" \
    --outdir "$BASE_DIR" \
    --sex-col "$SEX_COL" \
    --male-code "$MALE_CODE" \
    --female-code "$FEMALE_CODE" \
    $( [[ "$DRY_RUN" == "1" ]] && echo --dry-run )
fi

if [[ "$SKIP_ANA" -eq 0 ]]; then
  bash scripts/analysis/run_analysis.sh \
    --base-dir "$BASE_DIR" \
    --geno "$GENO_INPUT" \
    --pipeline "$PIPELINE_DIR" \
    --chrs "$CHRS" \
    --with-singularity "$WITH_SINGULARITY" \
    --resume "$NEXTFLOW_RESUME" \
    --window-l "$WINDOW_L" \
    $WAIT_FLAG \
    $( [[ "$DRY_RUN" == "1" ]] && echo --dry-run )
fi

if [[ "$SKIP_VIZ" -eq 0 ]]; then
  bash scripts/visualization/run_visualization.sh \
    --merged-male "$BASE_DIR/results_merged/mvgwas_merged_male.tsv" \
    --merged-female "$BASE_DIR/results_merged/mvgwas_merged_female.tsv" \
    --outdir "$BASE_DIR/results/figures" \
    $( [[ "$DRY_RUN" == "1" ]] && echo --dry-run )
fi
