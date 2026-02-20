# Troubleshooting

## SLURM output logs
Check:
- `logs/analysis/`
- `logs/preprocessing/`
- SLURM `*.out` and `*.err` files

## Common issues

### VCF contig naming mismatch (`16` vs `chr16`)
The analysis script auto-detects this using the VCF header contigs, but if your VCF lacks contig lines,
you may need to edit `scripts/analysis/run_mvgwas_parallel_sex.sh` to set `CHR_PREFIX`.

### Nextflow / Singularity
If you don't use Singularity, set `WITH_SINGULARITY=0` in `config/paths.env`.

### Missing tools
Ensure `bcftools`, `java`, and `nextflow` are available in your environment.

## Dry-run

Use `--dry-run` to validate inputs and tool availability without submitting jobs or writing outputs.

## Tests

Run `make test` to execute the unit tests and the dry-run smoke test.

## Sex-specific chromosomes

Use `--male-chrs` and `--female-chrs` with `run_analysis.sh` (or `submit_gwas_pipeline_sex.sh`) to submit different chromosome arrays for each sex.
