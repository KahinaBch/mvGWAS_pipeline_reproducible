```text
REPRODUCING THE MULTIVARIATE GWAS OF WMH VOLUMES Date generated:
2026-02-20

============================================================ STEP 1 —
SET UP ENVIRONMENT
============================================================

1.  Ensure access to:
    -   SLURM cluster
    -   bcftools
    -   plink (if required)
    -   R or Python mvGWAS environment
2.  Create directory structure:

/home/kbaouche/mvGWAS_WMHv/ ├── data_male ├── data_female ├──
results_male ├── results_female └── logs

============================================================ STEP 2 —
PREPARE PHENOTYPES AND COVARIATES
============================================================

1.  Generate WMH_covariates_complete.tsv
2.  Check ID matching with genotype file
3.  Remove individuals with missing covariates
4.  Split dataset by sex into male and female folders

============================================================ STEP 3 —
PROCESS GENOTYPE DATA
============================================================

For chromosome CHR:

bcftools view -r CHR input.vcf.gz -Oz -o chr_CHR.vcf.gz bcftools index
chr_CHR.vcf.gz

Repeat for chromosomes 1–22 or a subset.

============================================================ STEP 4 —
RUN MULTIVARIATE GWAS
============================================================

Submit full genome:

sbatch run_mvgwas_parallel.sh

Submit selected chromosomes:

sbatch –array=16,18,20 run_mvgwas_parallel.sh

Run separately for: - male dataset - female dataset

============================================================ STEP 5 —
MERGE CHROMOSOME RESULTS
============================================================

After completion:

bash merge_results_sex.sh

Confirm: - All chromosomes present - No failed jobs

============================================================ STEP 6 —
PERFORM POST-GWAS QC
============================================================

1.  Calculate lambda GC
2.  Generate QQ plot
3.  Generate Manhattan plot
4.  Annotate genome-wide significant variants

============================================================ STEP 7 —
ARCHIVE FOR REPRODUCIBILITY
============================================================

-   Save merged results
-   Record software versions
-   Save SLURM logs
-   Archive scripts and configuration files

============================================================ END OF
REPRODUCTION GUIDE
============================================================
```
