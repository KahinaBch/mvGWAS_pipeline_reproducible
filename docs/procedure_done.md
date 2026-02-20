```text
MULTIVARIATE GWAS OF WHITE MATTER HYPERINTENSITY (WMH) VOLUMES COMPLETE
ANALYTICAL PROCEDURE LOG Date generated: 2026-02-20

============================================================ 1. PROJECT
OVERVIEW ============================================================

Objective: To perform a multivariate genome-wide association study
(mvGWAS) on white matter hyperintensity (WMH) volumetric phenotypes,
including sex-stratified analyses.

Scientific rationale: WMH burden is a neuroimaging marker of cerebral
small vessel disease and is associated with aging, stroke risk, and
cognitive decline. Multivariate GWAS increases statistical power by
jointly modeling correlated phenotypes.

============================================================ 2. DATA
PREPARATION ============================================================

2.1 Phenotypic Data - Extract WMH volumetric phenotypes - Perform
quality control (missingness, outliers) - Harmonize subject IDs

2.2 Covariate File Construction File: WMH_covariates_complete.tsv
Columns: ID, age, education, TIV, sex, PC1–PC5

Steps: - Merge demographic and imaging covariates - Include top
principal components (to control population stratification) - Encode sex
numerically (e.g., 1=male, 2=female) - Verify no missing covariate
values

2.3 Sex Stratification Dataset divided into: - data_male/ - data_female/

Filtering performed based on sex column in covariate file.

============================================================ 3. GENOTYPE
DATA PROCESSING
============================================================

3.1 Input - Imputed genotype data in VCF format (bgzipped)

3.2 Chromosome Extraction Using bcftools: bcftools view -r CHR
input.vcf.gz -Oz -o chr_CHR.vcf.gz

3.3 Indexing bcftools index chr_CHR.vcf.gz

============================================================ 4.
MULTIVARIATE GWAS EXECUTION
============================================================

4.1 Parallelization SLURM job array used: #SBATCH –array=1-22

Restricted run example: sbatch –array=16,18,20 run_mvgwas_parallel.sh

4.2 Per-Chromosome Workflow For each chromosome: - Extract chromosome
VCF - Index VCF - Run mvGWAS model - Store output in appropriate results
directory

Directories: /home/kbaouche/mvGWAS_WMHv/data_male
/home/kbaouche/mvGWAS_WMHv/data_female
/home/kbaouche/mvGWAS_WMHv/results_male
/home/kbaouche/mvGWAS_WMHv/results_female

============================================================ 5. RESULT
MERGING ============================================================

After chromosome-level analyses complete: - Concatenate results - Ensure
correct chromosome ordering - Verify header consistency

============================================================ 6.
POST-GWAS QUALITY CONTROL
============================================================

-   Compute genomic inflation factor (lambda GC)
-   Generate QQ plot
-   Generate Manhattan plot
-   Identify genome-wide significant loci

============================================================ 7.
REPRODUCIBILITY PRACTICES
============================================================

-   Maintain script version control
-   Archive SLURM logs
-   Record software versions
-   Document directory structure
-   Preserve raw and processed datasets

============================================================ END OF
PROCEDURE LOG
============================================================
```
