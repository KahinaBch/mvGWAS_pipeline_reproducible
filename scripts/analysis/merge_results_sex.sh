#!/usr/bin/env bash
set -euo pipefail

# Merge mvgwas results across chromosomes, separately for male and female.
# Assumes per-chromosome results live at:
#   <results_dir>/chr<CHR>/mvgwas_chr<CHR>.tsv

# shellcheck source=scripts/analysis/utils.sh
source scripts/analysis/utils.sh

usage() {
  cat <<'EOF'
merge_results_sex.sh

Required:
  --results-male <DIR>
  --results-female <DIR>
  --outdir <DIR>

Optional:
  --chrs <SPEC>                 Chromosomes for both sexes (default: 1-22)
  --male-chrs <SPEC>            Override chromosomes for male
  --female-chrs <SPEC>          Override chromosomes for female

Outputs:
  <outdir>/mvgwas_merged_male.tsv
  <outdir>/mvgwas_merged_female.tsv
EOF
}

RM=""; RF=""; OUT=""
CHRS="1-22"; MALE_CHRS=""; FEMALE_CHRS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --results-male) RM="$2"; shift 2;;
    --results-female) RF="$2"; shift 2;;
    --outdir) OUT="$2"; shift 2;;
    --chrs) CHRS="$2"; shift 2;;
    --male-chrs) MALE_CHRS="$2"; shift 2;;
    --female-chrs) FEMALE_CHRS="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$RM" && -n "$RF" && -n "$OUT" ]] || { usage; exit 1; }
mkdir -p "$OUT"

merge_one() {
  local sex="$1"
  local resdir="$2"
  local spec="$3"
  local outfile="$4"

  local first=1
  : > "$outfile"

  while read -r chr; do
    local f="${resdir}/chr${chr}/mvgwas_chr${chr}.tsv"
    [[ -f "$f" ]] || die "Missing result for ${sex} chr${chr}: $f"
    if [[ "$first" == "1" ]]; then
      cat "$f" >> "$outfile"
      first=0
    else
      # skip header
      awk 'NR>1{print}' "$f" >> "$outfile"
    fi
  done < <(expand_chrs "$spec")

  echo "[merge] wrote: $outfile"
}

MALE_SPEC="${MALE_CHRS:-$CHRS}"
FEMALE_SPEC="${FEMALE_CHRS:-$CHRS}"

merge_one "male" "$RM" "$MALE_SPEC" "${OUT}/mvgwas_merged_male.tsv"
merge_one "female" "$RF" "$FEMALE_SPEC" "${OUT}/mvgwas_merged_female.tsv"
