#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source scripts/common.sh

usage() {
  cat <<'EOF'
run_analysis.sh
Runs sex-stratified mvGWAS using SLURM arrays, then merges outputs.

Required:
  --base-dir <DIR>
  --vcf <FILE.vcf.gz>
  --pipeline <DIR>

Optional:
  --male-chrs <LIST>            Chromosomes for male only (overrides --chrs)
  --female-chrs <LIST>          Chromosomes for female only (overrides --chrs)

  --dry-run                      Validate + print sbatch/merge commands without executing
  --chrs <SPEC>                 Default: 1-22 (e.g. 16,18,20)
  --with-singularity <0|1>      Default: 1
  --resume <0|1>                Default: 1
  --window-l <INT>              Default: 500
  --wait                         If set, waits for arrays to finish before merging (uses squeue)

Assumes preprocessing produced:
  <base-dir>/data_male/WMH_phenotypes.tsv
  <base-dir>/data_male/WMH_covariates.tsv
  <base-dir>/data_female/WMH_phenotypes.tsv
  <base-dir>/data_female/WMH_covariates.tsv

Example:
  bash scripts/analysis/run_analysis.sh \
    --base-dir /home/user/mvGWAS_WMHv \
    --vcf /path/geno.vcf.gz \
    --pipeline /home/user/mvgwas-nf \
    --chrs 16,18,20 \
    --wait
EOF
}

BASE_DIR=""; VCF=""; PIPELINE=""; CHRS="1-22"
MALE_CHRS=""
FEMALE_CHRS=""
WITH_SING="1"; RESUME="1"; WINDOW_L="500"; WAIT="0"
DRY_RUN="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) BASE_DIR="$2"; shift 2;;
    --vcf) VCF="$2"; shift 2;;
    --pipeline) PIPELINE="$2"; shift 2;;
    --male-chrs) MALE_CHRS="$2"; shift 2;;
    --female-chrs) FEMALE_CHRS="$2"; shift 2;;
    --chrs) CHRS="$2"; shift 2;;
    --with-singularity) WITH_SING="$2"; shift 2;;
    --resume) RESUME="$2"; shift 2;;
    --window-l) WINDOW_L="$2"; shift 2;;
    --dry-run) DRY_RUN="1"; shift 1;;
    --wait) WAIT="1"; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$BASE_DIR" && -n "$VCF" && -n "$PIPELINE" ]] || { usage; exit 1; }

MP="${BASE_DIR}/data_male/WMH_phenotypes.tsv"
MC="${BASE_DIR}/data_male/WMH_covariates.tsv"
FP="${BASE_DIR}/data_female/WMH_phenotypes.tsv"
FC="${BASE_DIR}/data_female/WMH_covariates.tsv"

[[ -f "$MP" && -f "$MC" && -f "$FP" && -f "$FC" ]] || {
  echo "Missing sex-specific inputs. Did you run preprocessing?" >&2
  echo "Expected: $MP $MC $FP $FC" >&2
  exit 1
}

jid_info=$(run_cmd bash scripts/analysis/submit_gwas_pipeline_sex.sh \
  --base-dir "$BASE_DIR" \
  --vcf "$VCF" \
  --pipeline "$PIPELINE" \
  --male-pheno "$MP" --male-cov "$MC" \
  --female-pheno "$FP" --female-cov "$FC" \
  --chrs "$CHRS" \
  $( [[ -n "$MALE_CHRS" ]] && echo --male-chrs "$MALE_CHRS" ) \
  $( [[ -n "$FEMALE_CHRS" ]] && echo --female-chrs "$FEMALE_CHRS" ) \
  --with-singularity "$WITH_SING" \
  --resume "$RESUME" \
  --window-l "$WINDOW_L" \
  $( [[ "$DRY_RUN" == "1" ]] && echo --dry-run ))

echo "$jid_info"

if [[ "$WAIT" == "1" ]]; then
  if command -v squeue >/dev/null 2>&1; then
    echo "[analysis] Waiting for jobs to finish (Ctrl+C to stop waiting)..."
    # Extract job ids from output lines containing "job id:"
    jids=$(echo "$jid_info" | awk '/job id:/ {print $NF}' | tr '\n' ',' | sed 's/,$//')
    while true; do
      if squeue -j "$jids" 2>/dev/null | awk 'NR>1{exit 0} END{exit 1}'; then
        sleep 30
      else
        echo "[analysis] Jobs finished."
        break
      fi
    done
  else
    echo "[analysis] --wait requested but squeue not available; skipping wait." >&2
  fi
fi

# Merge
run_cmd bash scripts/analysis/merge_results_sex.sh \
  --results-male "${BASE_DIR}/results_male" \
  --results-female "${BASE_DIR}/results_female" \
  --outdir "${BASE_DIR}/results_merged" \
  --chrs "$CHRS"

