#!/usr/bin/env python3

import argparse
import os
import pandas as pd

def main():
    ap = argparse.ArgumentParser(description="Split phenotype/covariate TSVs into male/female datasets by a sex column.")
    ap.add_argument("--covar", required=True, help="Covariate TSV with header including ID column and sex column.")
    ap.add_argument("--pheno", required=True, help="Phenotype TSV with header including ID column.")
    ap.add_argument("--outdir", required=True, help="Output directory (will create data_male/ and data_female/ inside).")
    ap.add_argument("--id-col", default="ID", help="ID column name (default: ID).")
    ap.add_argument("--sex-col", default="sex", help="Sex column name in covariates (default: sex).")
    ap.add_argument("--male-code", type=str, default="1", help="Value meaning male (default: 1).")
    ap.add_argument("--female-code", type=str, default="2", help="Value meaning female (default: 2).")
    ap.add_argument("--keep-unspecified", action="store_true",
                    help="If set, will also write data_unknown/ for IDs with other/NA sex codes.")
    args = ap.parse_args()

    cov = pd.read_csv(args.covar, sep="\t", dtype=str)
    phe = pd.read_csv(args.pheno, sep="\t", dtype=str)

    for col, name in [(args.id_col, "ID column"), (args.sex_col, "sex column")]:
        if col not in cov.columns:
            raise SystemExit(f"{name} '{col}' not found in covariate file columns: {list(cov.columns)}")
    if args.id_col not in phe.columns:
        raise SystemExit(f"ID column '{args.id_col}' not found in phenotype file columns: {list(phe.columns)}")

    # Strip whitespace
    cov[args.id_col] = cov[args.id_col].str.strip()
    phe[args.id_col] = phe[args.id_col].str.strip()
    cov[args.sex_col] = cov[args.sex_col].astype(str).str.strip()

    male_ids = set(cov.loc[cov[args.sex_col] == str(args.male_code), args.id_col])
    female_ids = set(cov.loc[cov[args.sex_col] == str(args.female_code), args.id_col])
    unknown_ids = set(cov[args.id_col]) - male_ids - female_ids

    os.makedirs(args.outdir, exist_ok=True)
    out_m = os.path.join(args.outdir, "data_male")
    out_f = os.path.join(args.outdir, "data_female")
    os.makedirs(out_m, exist_ok=True)
    os.makedirs(out_f, exist_ok=True)

    cov_m = cov[cov[args.id_col].isin(male_ids)].copy()
    cov_f = cov[cov[args.id_col].isin(female_ids)].copy()

    phe_m = phe[phe[args.id_col].isin(male_ids)].copy()
    phe_f = phe[phe[args.id_col].isin(female_ids)].copy()

    cov_m.to_csv(os.path.join(out_m, "WMH_covariates.tsv"), sep="\t", index=False)
    cov_f.to_csv(os.path.join(out_f, "WMH_covariates.tsv"), sep="\t", index=False)
    phe_m.to_csv(os.path.join(out_m, "WMH_phenotypes.tsv"), sep="\t", index=False)
    phe_f.to_csv(os.path.join(out_f, "WMH_phenotypes.tsv"), sep="\t", index=False)

    # Small summary
    with open(os.path.join(args.outdir, "sex_split_summary.txt"), "w", encoding="utf-8") as f:
        f.write(f"Total covariate rows: {len(cov)}\n")
        f.write(f"Male ({args.male_code}) IDs: {len(male_ids)}\n")
        f.write(f"Female ({args.female_code}) IDs: {len(female_ids)}\n")
        f.write(f"Unknown/other IDs: {len(unknown_ids)}\n")
        f.write(f"Male phenotypes rows: {len(phe_m)}\n")
        f.write(f"Female phenotypes rows: {len(phe_f)}\n")

    if args.keep_unspecified and len(unknown_ids) > 0:
        out_u = os.path.join(args.outdir, "data_unknown")
        os.makedirs(out_u, exist_ok=True)
        cov_u = cov[cov[args.id_col].isin(unknown_ids)].copy()
        phe_u = phe[phe[args.id_col].isin(unknown_ids)].copy()
        cov_u.to_csv(os.path.join(out_u, "WMH_covariates.tsv"), sep="\t", index=False)
        phe_u.to_csv(os.path.join(out_u, "WMH_phenotypes.tsv"), sep="\t", index=False)

if __name__ == "__main__":
    main()
