#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/stubs"
bash "$ROOT/tests/stubs/make_stubs.sh" "$TD/stubs"
export PATH="$TD/stubs:$PATH"

mkdir -p "$TD/geno"
touch "$TD/geno/prefix.bed" "$TD/geno/prefix.bim" "$TD/geno/prefix.fam"

printf "ID\tage\tsex\tPC1\tPC2\tPC3\tPC4\tPC5\n1\t50\t1\t0\t0\t0\t0\t0\n" > "$TD/covar.tsv"
printf "ID\tWMH\n1\t0.1\n" > "$TD/pheno.tsv"

bash "$ROOT/scripts/preprocessing/run_preprocessing.sh" \
  --geno "$TD/geno/prefix" \
  --covar "$TD/covar.tsv" \
  --pheno "$TD/pheno.tsv" \
  --outdir "$TD/base" \
  --dry-run

echo "OK: plink dry-run preprocessing completed"
