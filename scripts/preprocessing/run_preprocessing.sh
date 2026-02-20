#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/common.sh
source scripts/common.sh

usage() {
  cat <<'EOF'
run_preprocessing.sh
Validates + normalizes inputs, harmonizes IDs across genotype/covariates/phenotypes, then splits by sex into data_male/ and data_female/.

Required:
  --geno <PATH>        Genotype input: .vcf.gz/.vcf/.bcf OR PLINK prefix (.bed/.bim/.fam). Converted to .vcf.gz + indexed.
  --covar <TSV>        Covariates TSV (must contain ID and sex columns)
  --pheno <TSV>        Phenotypes TSV (must contain ID column)
  --outdir <DIR>       Base output directory (creates <outdir>/data_male and <outdir>/data_female)

Optional:
  --dry-run            Validate inputs and print commands without executing
  --id-col <NAME>      Default: ID
  --sex-col <NAME>     Default: sex
  --male-code <VAL>    Default: 1
  --female-code <VAL>  Default: 2
  --logdir <DIR>       Default: <outdir>/logs/preprocessing

Example:
  bash scripts/preprocessing/run_preprocessing.sh \
    --covar data/WMH_covariates_complete.tsv \
    --pheno data/WMH_phenotypes_complete.tsv \
    --outdir /home/user/mvGWAS_WMHv
EOF
}

ID_COL="ID"; SEX_COL="sex"; MALE_CODE="1"; FEMALE_CODE="2"
GENO=""; VCF=""; COVAR=""; PHENO=""; OUTDIR=""; LOGDIR=""
DRY_RUN="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --geno) GENO="$2"; shift 2;;
    --vcf) VCF="$2"; shift 2;;  # legacy alias
    --covar) COVAR="$2"; shift 2;;
    --pheno) PHENO="$2"; shift 2;;
    --outdir) OUTDIR="$2"; shift 2;;
    --id-col) ID_COL="$2"; shift 2;;
    --sex-col) SEX_COL="$2"; shift 2;;
    --male-code) MALE_CODE="$2"; shift 2;;
    --female-code) FEMALE_CODE="$2"; shift 2;;
    --dry-run) DRY_RUN="1"; shift 1;;
    --logdir) LOGDIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "${GENO:-$VCF}" && -n "$COVAR" && -n "$PHENO" && -n "$OUTDIR" ]] || { usage; exit 1; }
GENO_INPUT="${GENO:-$VCF}"
if [[ -z "$GENO_INPUT" ]]; then
  echo "Missing genotype: use --geno (preferred) or --vcf (legacy)" >&2; exit 1;
fi
if [[ -f "$GENO_INPUT" ]]; then
  :
elif [[ -f "${GENO_INPUT}.bed" && -f "${GENO_INPUT}.bim" && -f "${GENO_INPUT}.fam" ]]; then
  :
elif [[ "$GENO_INPUT" == *.bed && -f "$GENO_INPUT" && -f "${GENO_INPUT%.bed}.bim" && -f "${GENO_INPUT%.bed}.fam" ]]; then
  :
elif [[ "$GENO_INPUT" == *.bim && -f "$GENO_INPUT" && -f "${GENO_INPUT%.bim}.bed" && -f "${GENO_INPUT%.bim}.fam" ]]; then
  :
elif [[ "$GENO_INPUT" == *.fam && -f "$GENO_INPUT" && -f "${GENO_INPUT%.fam}.bed" && -f "${GENO_INPUT%.fam}.bim" ]]; then
  :
else
  echo "Missing genotype input as file or PLINK trio: $GENO_INPUT" >&2; exit 1;
fi
[[ -f "$COVAR" ]] || { echo "Missing covariates: $COVAR" >&2; exit 1; }
[[ -f "$PHENO" ]] || { echo "Missing phenotypes: $PHENO" >&2; exit 1; }

LOGDIR="${LOGDIR:-$OUTDIR/logs/preprocessing}"
mkdir -p "$LOGDIR"

echo "[preprocessing] $(date) starting"
need_cmd bcftools

# -----------------------------
# 1) Normalize genotype to bgzipped VCF + index
# -----------------------------
INPUT_VCF="$GENO_INPUT"
GENO_DIR="$OUTDIR/derived/inputs"
mkdir -p "$GENO_DIR"
HARM_DIR="$OUTDIR/derived/inputs"
mkdir -p "$HARM_DIR"
STD_VCF="$GENO_DIR/genotypes.vcf.gz"

echo "[preprocessing] Preparing genotype VCF (+index)..." | tee -a "$LOGDIR/run_preprocessing.log"
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "[dry-run] would create: $STD_VCF and $STD_VCF.tbi" | tee -a "$LOGDIR/run_preprocessing.log"
else
  # If input is PLINK, convert to bgzipped VCF via plink2 (preferred) or plink+bcftools.
PLINK_PREFIX=""
if [[ -f "${INPUT_VCF}.bed" && -f "${INPUT_VCF}.bim" && -f "${INPUT_VCF}.fam" ]]; then
  PLINK_PREFIX="$INPUT_VCF"
elif [[ "$INPUT_VCF" == *.bed && -f "$INPUT_VCF" && -f "${INPUT_VCF%.bed}.bim" && -f "${INPUT_VCF%.bed}.fam" ]]; then
  PLINK_PREFIX="${INPUT_VCF%.bed}"
elif [[ "$INPUT_VCF" == *.bim && -f "$INPUT_VCF" && -f "${INPUT_VCF%.bim}.bed" && -f "${INPUT_VCF%.bim}.fam" ]]; then
  PLINK_PREFIX="${INPUT_VCF%.bim}"
elif [[ "$INPUT_VCF" == *.fam && -f "$INPUT_VCF" && -f "${INPUT_VCF%.fam}.bed" && -f "${INPUT_VCF%.fam}.bim" ]]; then
  PLINK_PREFIX="${INPUT_VCF%.fam}"
fi

if [[ -n "$PLINK_PREFIX" ]]; then
  echo "[preprocessing] Detected PLINK input: ${PLINK_PREFIX}.bed/.bim/.fam" | tee -a "$LOGDIR/run_preprocessing.log"
  if command -v plink2 >/dev/null 2>&1; then
    plink2 --bfile "$PLINK_PREFIX" --export vcf bgz id-paste=iid --out "$GENO_DIR/genotypes"
    STD_VCF="$GENO_DIR/genotypes.vcf.gz"
  elif command -v plink >/dev/null 2>&1; then
    plink --bfile "$PLINK_PREFIX" --recode vcf-iid --out "$GENO_DIR/genotypes"
    bcftools view "$GENO_DIR/genotypes.vcf" -Oz -o "$GENO_DIR/genotypes.vcf.gz"
    rm -f "$GENO_DIR/genotypes.vcf"
    STD_VCF="$GENO_DIR/genotypes.vcf.gz"
  else
    echo "ERROR: PLINK input provided but neither plink2 nor plink is available in PATH." >&2
    exit 1
  fi
elif [[ "$INPUT_VCF" == *.vcf.gz ]]; then
  if [[ ! -f "$STD_VCF" ]]; then
    ln -s "$(realpath "$INPUT_VCF")" "$STD_VCF"
  fi
else
  bcftools view "$INPUT_VCF" -Oz -o "$STD_VCF"
fi

  if [[ ! -f "${STD_VCF}.tbi" ]]; then
    bcftools index -t "$STD_VCF"
  fi
fi

# -----------------------------
# 2) Normalize covariates/phenotypes to TSV and keep only common IDs with VCF samples
# -----------------------------
echo "[preprocessing] Harmonizing IDs across covar/pheno/vcf..." | tee -a "$LOGDIR/run_preprocessing.log"
# If strong dry-run and genotype input is PLINK, derive sample IDs from .fam (IID column)
SAMPLE_IDS_FILE=""
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  # Determine PLINK prefix similarly to conversion step
  PLINK_PREFIX=""
  if [[ -f "${INPUT_VCF}.bed" && -f "${INPUT_VCF}.bim" && -f "${INPUT_VCF}.fam" ]]; then
    PLINK_PREFIX="$INPUT_VCF"
  elif [[ "$INPUT_VCF" == *.bed && -f "$INPUT_VCF" && -f "${INPUT_VCF%.bed}.bim" && -f "${INPUT_VCF%.bed}.fam" ]]; then
    PLINK_PREFIX="${INPUT_VCF%.bed}"
  elif [[ "$INPUT_VCF" == *.bim && -f "$INPUT_VCF" && -f "${INPUT_VCF%.bim}.bed" && -f "${INPUT_VCF%.bim}.fam" ]]; then
    PLINK_PREFIX="${INPUT_VCF%.bim}"
  elif [[ "$INPUT_VCF" == *.fam && -f "$INPUT_VCF" && -f "${INPUT_VCF%.fam}.bed" && -f "${INPUT_VCF%.fam}.bim" ]]; then
    PLINK_PREFIX="${INPUT_VCF%.fam}"
  fi

  if [[ -n "$PLINK_PREFIX" ]]; then
    SAMPLE_IDS_FILE="$HARM_DIR/genotype_sample_ids.txt"
    # IID is column 2 in .fam
    awk '{print $2}' "${PLINK_PREFIX}.fam" | sed '/^$/d' > "$SAMPLE_IDS_FILE"
    echo "[preprocessing] (dry-run) Derived $(wc -l < "$SAMPLE_IDS_FILE") sample IDs from ${PLINK_PREFIX}.fam" | tee -a "$LOGDIR/run_preprocessing.log"
  fi
fi


run_cmd python3 scripts/preprocessing/prepare_inputs.py \
  --covar "$COVAR" \
  --pheno "$PHENO" \
  --vcf "$STD_VCF" \
  --outdir "$HARM_DIR" \
  --id-col "$ID_COL" \
  --sex-col "$SEX_COL" \
  $( [[ -n "$SAMPLE_IDS_FILE" ]] && echo --sample-ids-file "$SAMPLE_IDS_FILE" ) \
  $( [[ "${DRY_RUN:-0}" == "1" ]] && echo --dry-run )

COV_F="$HARM_DIR/covariates.filtered.tsv"
PHE_F="$HARM_DIR/phenotypes.filtered.tsv"
KEEP_IDS="$HARM_DIR/keep_ids.txt"

# -----------------------------
# 3) Subset VCF to common IDs
# -----------------------------
SUB_VCF="$HARM_DIR/genotypes.filtered.vcf.gz"
echo "[preprocessing] Subsetting genotype to common IDs..." | tee -a "$LOGDIR/run_preprocessing.log"
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "[dry-run] would run: bcftools view -S $KEEP_IDS $STD_VCF -Oz -o $SUB_VCF" | tee -a "$LOGDIR/run_preprocessing.log"
  echo "[dry-run] would run: bcftools index -t $SUB_VCF" | tee -a "$LOGDIR/run_preprocessing.log"
else
  bcftools view -S "$KEEP_IDS" "$STD_VCF" -Oz -o "$SUB_VCF"
  bcftools index -t "$SUB_VCF"
fi

# Use filtered cov/pheno for sex split
COVAR="$COV_F"
PHENO="$PHE_F"
run_cmd python3 scripts/preprocessing/split_by_sex.py \
  --covar "$COVAR" \
  --pheno "$PHENO" \
  --outdir "$OUTDIR" \
  --id-col "$ID_COL" \
  --sex-col "$SEX_COL" \
  $( [[ -n "$SAMPLE_IDS_FILE" ]] && echo --sample-ids-file "$SAMPLE_IDS_FILE" ) \
  --male-code "$MALE_CODE" \
  --female-code "$FEMALE_CODE" \
  | tee -a "$LOGDIR/run_preprocessing.log"

echo "[preprocessing] $(date) done" | tee -a "$LOGDIR/run_preprocessing.log"

