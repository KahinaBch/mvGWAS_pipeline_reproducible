# mvGWAS-WMHv

Sex-stratified **multivariate GWAS** pipeline for **White Matter Hyperintensity (WMH) volumes**, designed for HPC execution using **SLURM job arrays** and **mvgwas-nf (Nextflow)**.

## Repository structure

- `scripts/preprocessing/` — build analysis-ready male/female inputs
- `scripts/analysis/` — run mvGWAS per chromosome in parallel (SLURM arrays) + merge results
- `scripts/visualization/` — QQ and Manhattan plots from merged outputs
- `run_all.sh` — master script (preprocessing → analysis → visualization)
- `config/` — path and parameter configuration templates
- `docs/` — procedure log + reproduction guide

## Requirements

- `bcftools` (VCF slicing + indexing)
- `java` and `nextflow`
- optional: `singularity` if you run `-with-singularity`
- `python3` (preprocessing splitter)
- `R` (plots)

Cluster module hints: see `environment/modules_slurm.txt`.

## Inputs

Set `GENO_INPUT` (preferred) or `VCF_FILE` (legacy) in `config/paths.env`.

1. **Whole-genome VCF** (bgzipped): `VCF_FILE`
   - **PLINK** prefix (`.bed/.bim/.fam`) — converted to `.vcf.gz` during preprocessing (requires `plink2` or `plink`).

2. **Phenotypes TSV** with header and an `ID` column: `PHENOTYPE_FILE`
3. **Covariates TSV** with header including `ID`, `sex` and PCs: `COVARIATE_FILE`

Sex coding is configurable (default `1=male`, `2=female`).

## Quickstart (recommended)

1) Copy config and edit paths:

```bash
cp config/paths.example.env config/paths.env
nano config/paths.env
```

2) Run everything:

```bash
bash run_all.sh --env config/paths.env
```

3) Run only some chromosomes:

```bash
bash run_all.sh --env config/paths.env --chrs 16,18,20 --wait
```

> Tip: You can also restrict chromosomes at submission time for each sex:
> `sbatch --array=16,18,20 scripts/analysis/run_mvgwas_parallel_sex.sh ...`

## Running stages separately

### Preprocessing

Preprocessing will:
- convert covariates/phenotypes to TSV if needed
- ensure genotype is bgzipped VCF (`.vcf.gz`) with a `.tbi` index
- compute the intersection of IDs across **covariates**, **phenotypes**, and **VCF samples**
- write filtered covariates/phenotypes and a sample-filtered VCF
- then split filtered tables by sex


Creates:
- `<BASE_DIR>/data_male/WMH_phenotypes.tsv`
- `<BASE_DIR>/data_male/WMH_covariates.tsv`
- `<BASE_DIR>/data_female/WMH_phenotypes.tsv`
- `<BASE_DIR>/data_female/WMH_covariates.tsv`

```bash
bash scripts/preprocessing/run_preprocessing.sh \
  --covar "$COVARIATE_FILE" \
  --pheno "$PHENOTYPE_FILE" \
  --outdir "$BASE_DIR"
```

### Analysis (SLURM arrays)

Submits male and female arrays, then merges outputs:

```bash
bash scripts/analysis/run_analysis.sh \
  --base-dir "$BASE_DIR" \
  --vcf "$VCF_FILE" \
  --pipeline "$PIPELINE_DIR" \
  --chrs 1-22 --wait
```

Outputs:
- `<BASE_DIR>/results_male/chr*/...`
- `<BASE_DIR>/results_female/chr*/...`
- `<BASE_DIR>/results_merged/mvgwas_merged_male.tsv`
- `<BASE_DIR>/results_merged/mvgwas_merged_female.tsv`

### Visualization

```bash
bash scripts/visualization/run_visualization.sh \
  --merged-male "$BASE_DIR/results_merged/mvgwas_merged_male.tsv" \
  --merged-female "$BASE_DIR/results_merged/mvgwas_merged_female.tsv" \
  --outdir "$BASE_DIR/results/figures"
```

## Notes on chromosome naming

The analysis script auto-detects whether your VCF contigs use `16` or `chr16` and chooses the correct bcftools region accordingly.

## Docs

- `docs/procedure_done.md` — narrative log of what was done
- `docs/reproduce.md` — step-by-step reproduction guide

## License

MIT (see `LICENSE`).
## Dry-run mode

Dry-run is **strong** by default:
- it reads genotype sample IDs (from VCF via `bcftools query -l`, or from PLINK `.fam`)
- computes overlap with covariate/phenotype IDs
- fails early if overlap is **zero**
- does not write outputs or submit jobs


All stage scripts and `run_all.sh` support `--dry-run`.

- Checks **input paths** and **tool availability**
- Prints commands that would be executed
- Does not submit jobs or generate outputs

Example:

```bash
bash run_all.sh --env config/paths.env --chrs 16,18,20 --dry-run
```

## Unit tests

Tests live in `tests/` and are designed to run without a full HPC stack.

Run:

```bash
make test
```



### Sex-specific chromosome selection

If you want different chromosome sets per sex, use:

```bash
bash scripts/analysis/run_analysis.sh \
  --base-dir "$BASE_DIR" \
  --vcf "$VCF_FILE" \
  --pipeline "$PIPELINE_DIR" \
  --male-chrs 10,16 \
  --female-chrs 13
```

You can still use `--chrs` to apply the same set to both sexes.
