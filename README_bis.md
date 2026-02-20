# mvGWAS_WMHv

Scripts to prepare sex-stratified inputs and run mvGWAS (mvgwas-nf) on WMH phenotypes.

## Key directories

- `scr/` : SLURM submission + helper scripts
- `scr/visualization/` : GWAS result visualization scripts
- `summaries/` : procedure notes / reproducibility logs

## Sex-stratified GWAS

Inputs expected on the cluster:
- `/home/kbaouche/mvGWAS_WMHv/data_female/`
- `/home/kbaouche/mvGWAS_WMHv/data_male/`

Outputs:
- `/home/kbaouche/mvGWAS_WMHv/results_female/`
- `/home/kbaouche/mvGWAS_WMHv/results_male/`

Submit:
```bash
bash /home/kbaouche/mvGWAS_WMHv/scr/submit_gwas_pipeline_sex.sh
```

Run selected chromosomes only (example chr3,10,15,16 for both sexes):
```bash
sbatch --array=3,10,15,16,25,32,37,38 /home/kbaouche/mvGWAS_WMHv/scr/run_mvgwas_parallel_sex.sh
```

## Visualization

Default (Manhattan + QQ + tables):
```bash
bash scr/visualization/run_visualization.sh --input <merged.tsv> --outdir <results_dir>
```

Disable QQ:
```bash
bash scr/visualization/run_visualization.sh --input <merged.tsv> --outdir <results_dir> --no-qq
```

## Auto (default non-sex unless sex inputs present)

Submit auto-detect pipeline:
```bash
bash /home/kbaouche/mvGWAS_WMHv/scr/submit_gwas_pipeline_auto.sh
```

Force non-sex run on chr3,10,15,16:
```bash
bash /home/kbaouche/mvGWAS_WMHv/scr/submit_gwas_pipeline_auto.sh --sex none --chrs "3,10,15,16"
```

Force sex-stratified run on chr3,10,15,16:
```bash
bash /home/kbaouche/mvGWAS_WMHv/scr/submit_gwas_pipeline_auto.sh --sex both --chrs "3,10,15,16"
```
