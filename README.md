# mvGWAS_pipeline_reproducible

A **reproducible, end-to-end** pipeline to run **sex-stratified multivariate GWAS** (mvGWAS) with **MANTA / mvgwas-nf**:
1) **Preprocessing**: validate + normalize inputs, harmonize subject IDs across genotype/phenotype/covariate files, optionally convert PLINK → bgzipped VCF, and create sex-split datasets.
2) **Analysis (SLURM + Nextflow)**: submit per-chromosome mvGWAS jobs (female/male) via a single SLURM job array.
3) **Merge + visualization**: merge per-chromosome results and generate Manhattan/QQ plots.

---

## Repository structure

- `run_all.sh` — main entrypoint (preprocess → analysis → visualization)
- `config/paths.example.env` — template to configure paths
- `scripts/preprocessing/` — format checks, ID harmonization, sex split
- `scripts/analysis/` — SLURM submission + chromosome-parallel Nextflow runs + merge
- `scripts/visualization/` — plotting wrappers
- `tests/` — lightweight unit tests (where applicable)
- `docs/` — extra documentation

---

## Requirements

### Core tools
- Bash
- `python3` (with `pandas`)
- `bcftools` (for VCF conversion/indexing and region extraction)
- SLURM (`sbatch`, and optionally `squeue` if you want `--wait`)
- Nextflow + Java
- R (`Rscript`) for visualization

### Optional
- `plink2` (preferred) or `plink` — only needed if your genotype input is PLINK (`.bed/.bim/.fam`)

---

## Quickstart

### 1) Configure paths
Copy the example env file and edit it:

```bash
cp config/paths.example.env config/paths.env
nano config/paths.env
```

At minimum you must set:

- `BASE_DIR` — working directory where all outputs will be written
- `GENO_INPUT` — genotype input (see below)
- `PHENOTYPE_FILE` — phenotype TSV
- `COVARIATE_FILE` — covariate TSV (must include sex column)
- `PIPELINE_DIR` — directory containing `mvgwas.nf` (from mvgwas-nf)

### 2) Run everything (recommended)
```bash
bash run_all.sh --env config/paths.env --wait
```

### 3) Do a strong dry-run (recommended before spending compute)
```bash
bash run_all.sh --env config/paths.env --dry-run
```

Dry-run checks:
- tools available in PATH
- file formats are readable
- overlap of subject IDs across genotype / phenotype / covariates (where possible without full computation)
- prints the commands that would run

---

## Inputs

### Genotypes (`GENO_INPUT`)
Supported:
- `*.vcf.gz` (bgzipped) + `*.tbi`
- `*.vcf` or `*.bcf` (will be converted/indexed)
- PLINK prefix (either `prefix` where `prefix.bed/.bim/.fam` exist, or a direct `*.bed` path)

Preprocessing will produce:
- `BASE_DIR/derived/inputs/genotypes.vcf.gz` (+ index)
- `BASE_DIR/derived/inputs/genotypes.filtered.vcf.gz` (+ index), filtered to subjects present in **all three** (geno/pheno/covar)

### Phenotypes (`PHENOTYPE_FILE`)
- TSV file with an ID column (default column name: `ID`)

### Covariates (`COVARIATE_FILE`)
- TSV file with an ID column (default `ID`)
- must contain a sex column (default `sex`) coded as:
  - male: `1` (default)
  - female: `2` (default)

You can override column names/codes via env or CLI.

---

## What preprocessing produces

After preprocessing (`scripts/preprocessing/run_preprocessing.sh`) you should have:

- `BASE_DIR/derived/inputs/`
  - `covariates.filtered.tsv`
  - `phenotypes.filtered.tsv`
  - `genotypes.filtered.vcf.gz` (+ `.tbi`)
- `BASE_DIR/data_female/`
  - `WMH_covariates.tsv`
  - `WMH_phenotypes.tsv`
- `BASE_DIR/data_male/`
  - `WMH_covariates.tsv`
  - `WMH_phenotypes.tsv`

These sex-specific TSVs are what the analysis stage consumes.

---

## Running stages separately

### Preprocessing only
```bash
bash scripts/preprocessing/run_preprocessing.sh   --geno "$GENO_INPUT"   --covar "$COVARIATE_FILE"   --pheno "$PHENOTYPE_FILE"   --outdir "$BASE_DIR"   --sex-col sex --male-code 1 --female-code 2
```

### Analysis only (requires preprocessing outputs)
```bash
bash scripts/analysis/run_analysis.sh   --base-dir "$BASE_DIR"   --vcf "$BASE_DIR/derived/inputs/genotypes.filtered.vcf.gz"   --pipeline "$PIPELINE_DIR"   --chrs 1-22   --with-singularity 1   --resume 1   --window-l 500   --wait
```

### Run different chromosomes per sex (example)
Female chromosome 13 only, male chromosomes 10 and 16 only:
```bash
bash scripts/analysis/run_analysis.sh   --base-dir "$BASE_DIR"   --vcf "$BASE_DIR/derived/inputs/genotypes.filtered.vcf.gz"   --pipeline "$PIPELINE_DIR"   --female-chrs 13   --male-chrs 10,16   --with-singularity 1   --resume 1   --window-l 500
```

---

## Outputs

### Per-chromosome mvGWAS results
- `BASE_DIR/results_female/chr<CHR>/mvgwas_chr<CHR>.tsv`
- `BASE_DIR/results_male/chr<CHR>/mvgwas_chr<CHR>.tsv`

### Merged results
- `BASE_DIR/results_merged/mvgwas_merged_female.tsv`
- `BASE_DIR/results_merged/mvgwas_merged_male.tsv`

### Figures (if visualization enabled)
- `BASE_DIR/results/figures/` (Manhattan/QQ, etc.)

---

## Notes on SLURM + Nextflow

- The analysis stage submits **one SLURM array** where each task corresponds to one `(sex, chromosome)` pair.
- Chromosome extraction uses `bcftools view -r <region>` and auto-detects whether your VCF contigs are `chr1` vs `1`.

---

## Troubleshooting

- **Missing sex-specific TSVs**: run preprocessing first; analysis expects:
  - `BASE_DIR/data_male/WMH_phenotypes.tsv`, `BASE_DIR/data_male/WMH_covariates.tsv`
  - `BASE_DIR/data_female/WMH_phenotypes.tsv`, `BASE_DIR/data_female/WMH_covariates.tsv`

- **Contig naming issues** (`chr1` vs `1`): the submission wrapper auto-detects contig prefix from the VCF header. If your contigs are non-standard, you may need to normalize them upstream.

---

## License
See `LICENSE`.
