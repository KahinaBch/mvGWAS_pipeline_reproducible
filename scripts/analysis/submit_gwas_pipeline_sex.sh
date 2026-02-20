#!/usr/bin/env bash
set -euo pipefail

# Sex-stratified SLURM submission wrapper for mvgwas-nf.
# Creates a task table (sex,chr) and submits a single SLURM array job.
# Prints submitted job ids to stdout.

# shellcheck source=scripts/analysis/utils.sh
source scripts/analysis/utils.sh

usage() {
  cat <<'EOF'
submit_gwas_pipeline_sex.sh

Required:
  --base-dir <DIR>
  --vcf <FILE.vcf.gz>
  --pipeline <DIR>                 Directory that contains mvgwas.nf

  --male-pheno <TSV> --male-cov <TSV>
  --female-pheno <TSV> --female-cov <TSV>

Optional:
  --chrs <SPEC>                     Chromosomes for both sexes (default: 1-22)
  --male-chrs <SPEC>                Override chromosomes for male
  --female-chrs <SPEC>              Override chromosomes for female
  --with-singularity <0|1>          Default: 1
  --resume <0|1>                    Default: 1
  --window-l <INT>                  Nextflow --l parameter (default: 500)
  --dry-run                         Validate and print sbatch commands only

Example:
  bash scripts/analysis/submit_gwas_pipeline_sex.sh \
    --base-dir work --vcf work/derived/inputs/genotypes.filtered.vcf.gz --pipeline /path/to/mvgwas-nf \
    --male-pheno work/data_male/WMH_phenotypes.tsv --male-cov work/data_male/WMH_covariates.tsv \
    --female-pheno work/data_female/WMH_phenotypes.tsv --female-cov work/data_female/WMH_covariates.tsv \
    --male-chrs 10,16 --female-chrs 13
EOF
}

BASE_DIR=""
VCF=""
PIPELINE=""
MALE_PHENO=""; MALE_COV=""
FEMALE_PHENO=""; FEMALE_COV=""
CHRS="1-22"
MALE_CHRS=""; FEMALE_CHRS=""
WITH_SING="1"
RESUME="1"
WINDOW_L="500"
DRY_RUN="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) BASE_DIR="$2"; shift 2;;
    --vcf) VCF="$2"; shift 2;;
    --pipeline) PIPELINE="$2"; shift 2;;

    --male-pheno) MALE_PHENO="$2"; shift 2;;
    --male-cov) MALE_COV="$2"; shift 2;;
    --female-pheno) FEMALE_PHENO="$2"; shift 2;;
    --female-cov) FEMALE_COV="$2"; shift 2;;

    --chrs) CHRS="$2"; shift 2;;
    --male-chrs) MALE_CHRS="$2"; shift 2;;
    --female-chrs) FEMALE_CHRS="$2"; shift 2;;
    --with-singularity) WITH_SING="$2"; shift 2;;
    --resume) RESUME="$2"; shift 2;;
    --window-l) WINDOW_L="$2"; shift 2;;
    --dry-run) DRY_RUN="1"; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$BASE_DIR" && -n "$VCF" && -n "$PIPELINE" ]] || { usage; exit 1; }
[[ -f "$VCF" ]] || die "VCF not found: $VCF"
[[ -d "$PIPELINE" ]] || die "PIPELINE dir not found: $PIPELINE"
[[ -f "${PIPELINE}/mvgwas.nf" ]] || die "Expected ${PIPELINE}/mvgwas.nf"
[[ -f "$MALE_PHENO" && -f "$MALE_COV" && -f "$FEMALE_PHENO" && -f "$FEMALE_COV" ]] || die "Missing male/female pheno/cov TSVs."

need_cmd sbatch
need_cmd bcftools
need_cmd nextflow
need_cmd java

mkdir -p "${BASE_DIR}/logs" "${BASE_DIR}/config"

MALE_SPEC="${MALE_CHRS:-$CHRS}"
FEMALE_SPEC="${FEMALE_CHRS:-$CHRS}"

TASK_FILE="${BASE_DIR}/config/tasks_sex.tsv"
{
  echo -e "sex\tchr"
  while read -r c; do echo -e "female\t${c}"; done < <(expand_chrs "$FEMALE_SPEC")
  while read -r c; do echo -e "male\t${c}"; done < <(expand_chrs "$MALE_SPEC")
} > "$TASK_FILE"

N_TASKS=$(( $(wc -l < "$TASK_FILE") - 1 ))
(( N_TASKS > 0 )) || die "No tasks generated from CHRS specs."

CHR_PREFIX="$(detect_chr_prefix "$VCF")"

SBATCH_CMD=(sbatch
  --job-name=mvgwas_sex
  --output="${BASE_DIR}/logs/mvgwas_sex_%A_%a.out"
  --error="${BASE_DIR}/logs/mvgwas_sex_%A_%a.err"
  --array="1-${N_TASKS}"
  --export=ALL,BASE_DIR="${BASE_DIR}",VCF="${VCF}",PIPELINE="${PIPELINE}",TASK_FILE="${TASK_FILE}",CHR_PREFIX="${CHR_PREFIX}",MALE_PHENO="${MALE_PHENO}",MALE_COV="${MALE_COV}",FEMALE_PHENO="${FEMALE_PHENO}",FEMALE_COV="${FEMALE_COV}",WITH_SING="${WITH_SING}",RESUME="${RESUME}",WINDOW_L="${WINDOW_L}"
  scripts/analysis/run_mvgwas_parallel_sex.sh
)

echo "[submit] task file: $TASK_FILE"
echo "[submit] tasks: $N_TASKS"
echo "[submit] chr prefix: '${CHR_PREFIX}'"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] would run: ${SBATCH_CMD[*]}"
  echo "job id: DRYRUN_ARRAY"
  exit 0
fi

ARRAY_OUT="$("${SBATCH_CMD[@]}")"
echo "$ARRAY_OUT"
ARRAY_JID=$(echo "$ARRAY_OUT" | awk '{print $NF}')
echo "job id: $ARRAY_JID"
