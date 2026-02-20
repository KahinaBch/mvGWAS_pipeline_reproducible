#!/usr/bin/env python3
import argparse
import os
import sys
import subprocess
import pandas as pd

def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)

def detect_sep(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        header = f.readline()
    if header.count(",") > header.count("\t"):
        return ","
    return "\t"

def read_table(path: str) -> pd.DataFrame:
    sep = detect_sep(path)
    try:
        return pd.read_csv(path, sep=sep, dtype=str)
    except Exception:
        return pd.read_csv(path, sep=r"\s+", engine="python", dtype=str)

def run(cmd, dry_run: bool):
    if dry_run:
        print("[dry-run]", " ".join(cmd))
        return ""
    p = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return p.stdout

def main():
    ap = argparse.ArgumentParser(
        description="Normalize covariate/phenotype files to TSV and keep only IDs present in covar, pheno, and VCF samples."
    )
    ap.add_argument("--covar", required=True, help="Covariate file (TSV/CSV/whitespace) with header.")
    ap.add_argument("--pheno", required=True, help="Phenotype file (TSV/CSV/whitespace) with header.")
    ap.add_argument("--vcf", required=True, help="Genotype VCF (.vcf.gz recommended).")
    ap.add_argument("--sample-ids-file", default=None, help="Optional newline-delimited sample IDs file (used instead of bcftools query -l).")
    ap.add_argument("--outdir", required=True, help="Output directory.")
    ap.add_argument("--id-col", default="ID", help="ID column name (default: ID).")
    ap.add_argument("--sex-col", default="sex", help="Sex column name in covariates (default: sex).")
    ap.add_argument("--required-covar-cols", default="ID,age,sex,PC1,PC2,PC3,PC4,PC5",
                    help="Comma-separated required covariate columns (default: ID,age,sex,PC1..PC5).")
    ap.add_argument("--required-pheno-cols", default="ID",
                    help="Comma-separated required phenotype columns (default: ID).")
    ap.add_argument("--dry-run", action="store_true", help="Validate only; print actions; do not write outputs.")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    cov = read_table(args.covar)
    phe = read_table(args.pheno)

    cov.columns = [c.strip() for c in cov.columns]
    phe.columns = [c.strip() for c in phe.columns]

    if args.id_col not in cov.columns:
        die(f"ID column '{args.id_col}' not found in covariates. Columns: {list(cov.columns)}")
    if args.id_col not in phe.columns:
        die(f"ID column '{args.id_col}' not found in phenotypes. Columns: {list(phe.columns)}")

    req_cov = [c.strip() for c in args.required_covar_cols.split(",") if c.strip()]
    req_phe = [c.strip() for c in args.required_pheno_cols.split(",") if c.strip()]
    for c in req_cov:
        if c not in cov.columns:
            die(f"Missing required covariate column: {c}")
    for c in req_phe:
        if c not in phe.columns:
            die(f"Missing required phenotype column: {c}")

    cov[args.id_col] = cov[args.id_col].astype(str).str.strip()
    phe[args.id_col] = phe[args.id_col].astype(str).str.strip()
    cov = cov.dropna(subset=[args.id_col]).drop_duplicates(subset=[args.id_col], keep="first")
    phe = phe.dropna(subset=[args.id_col]).drop_duplicates(subset=[args.id_col], keep="first")

    cov_ids = set(cov[args.id_col].tolist())
    phe_ids = set(phe[args.id_col].tolist())

    # VCF/sample IDs
# Strong dry-run: we DO compute overlap size and fail if 0, but we DO NOT write outputs.
vcf_ids = set()
if args.sample_ids_file:
    with open(args.sample_ids_file, "r", encoding="utf-8") as f:
        vcf_ids = set([ln.strip() for ln in f if ln.strip()])
else:
    vcf_ids_out = run(["bcftools", "query", "-l", args.vcf], dry_run=False)
    # Note: even in dry-run we execute this query; dry-run means "no outputs written", not "no reads".
    vcf_ids = set([x.strip() for x in vcf_ids_out.splitlines() if x.strip()])

common = cov_ids & phe_ids & vcf_ids

if args.dry_run:
    print(f"[dry-run] covariates_unique_ids={len(cov_ids)}")
    print(f"[dry-run] phenotypes_unique_ids={len(phe_ids)}")
    print(f"[dry-run] genotype_unique_ids={len(vcf_ids)}")
    print(f"[dry-run] common_ids={len(common)}")
    if len(common) == 0:
        die("Strong dry-run failed: no overlapping IDs among covariates, phenotypes, and genotype samples.")
    print("[dry-run] Strong dry-run OK: overlap is non-zero. No outputs will be written.")
    return

if len(common) == 0:
    die("No overlapping IDs among covariates, phenotypes, and VCF samples.")

cov_f = cov[cov[args.id_col].isin(common)].copy().sort_values(args.id_col)
phe_f = phe[phe[args.id_col].isin(common)].copy().sort_values(args.id_col)

([x.strip() for x in vcf_ids_out.splitlines() if x.strip()])
    common = cov_ids & phe_ids & vcf_ids
    if len(common) == 0:
        die("No overlapping IDs among covariates, phenotypes, and VCF samples.")

    cov_f = cov[cov[args.id_col].isin(common)].copy().sort_values(args.id_col)
    phe_f = phe[phe[args.id_col].isin(common)].copy().sort_values(args.id_col)

    cov_out = os.path.join(args.outdir, "covariates.filtered.tsv")
    phe_out = os.path.join(args.outdir, "phenotypes.filtered.tsv")
    keep_out = os.path.join(args.outdir, "keep_ids.txt")

    cov_f.to_csv(cov_out, sep="\t", index=False)
    phe_f.to_csv(phe_out, sep="\t", index=False)
    with open(keep_out, "w", encoding="utf-8") as f:
        for _id in sorted(common):
            f.write(f"{_id}\n")

    with open(os.path.join(args.outdir, "harmonization_summary.txt"), "w", encoding="utf-8") as f:
        f.write(f"covariates_unique_ids\t{len(cov_ids)}\n")
        f.write(f"phenotypes_unique_ids\t{len(phe_ids)}\n")
        f.write(f"vcf_unique_ids\t{len(vcf_ids)}\n")
        f.write(f"common_ids\t{len(common)}\n")
        f.write(f"covariates_rows_written\t{len(cov_f)}\n")
        f.write(f"phenotypes_rows_written\t{len(phe_f)}\n")

if __name__ == "__main__":
    main()
