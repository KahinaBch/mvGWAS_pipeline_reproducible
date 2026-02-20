#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/base" "$TD/pipeline"
touch "$TD/geno.vcf.gz"
printf "ID\tWMH\n1\t0.1\n" > "$TD/pheno.tsv"
printf "ID\tsex\tage\tPC1\n1\t1\t50\t0\n" > "$TD/covar.tsv"
touch "$TD/pipeline/mvgwas.nf"

mkdir -p "$TD/stubs"
bash "$ROOT/tests/stubs/make_stubs.sh" "$TD/stubs"
export PATH="$TD/stubs:$PATH"

# Create expected sex-specific files for analysis stage
mkdir -p "$TD/base/data_male" "$TD/base/data_female"
cp "$TD/pheno.tsv" "$TD/base/data_male/WMH_phenotypes.tsv"
cp "$TD/covar.tsv" "$TD/base/data_male/WMH_covariates.tsv"
cp "$TD/pheno.tsv" "$TD/base/data_female/WMH_phenotypes.tsv"
cp "$TD/covar.tsv" "$TD/base/data_female/WMH_covariates.tsv"

bash "$ROOT/scripts/analysis/run_analysis.sh" \
  --base-dir "$TD/base" \
  --vcf "$TD/geno.vcf.gz" \
  --pipeline "$TD/pipeline" \
  --chrs 16,18,20 \
  --male-chrs 10,16 \
  --female-chrs 13 \
  --dry-run

echo "OK: dry-run analysis completed"
