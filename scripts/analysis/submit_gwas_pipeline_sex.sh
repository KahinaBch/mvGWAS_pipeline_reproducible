#!/bin/bash
# =============================================================================
# Submit GWAS Pipeline - Sex-stratified (female + male)
# =============================================================================
# This master script submits:
#   1) one SLURM job array with 44 tasks (22 chr x 2 sexes)
#   2) a merge job that runs after the array completes successfully
#
# Usage:
#   bash submit_gwas_pipeline_sex.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
SCR_DIR="${BASE_DIR}/scr"

echo "=========================================="
echo "Submitting MVGWAS Pipeline (Sex-stratified)"
echo "Date: $(date)"
echo "=========================================="

mkdir -p "${BASE_DIR}/logs"

# -----------------------------------------------------------------------------
# Step 1: Submit parallel chromosome+sex jobs
# -----------------------------------------------------------------------------
echo ""
echo "Submitting parallel jobs (female+male) for chromosomes 1-22..."

JOB_ID=$(sbatch --parsable "${SCR_DIR}/run_mvgwas_parallel_sex.sh")

if [ -z "${JOB_ID}" ]; then
    echo "ERROR: Failed to submit job array"
    exit 1
fi

echo "✓ Submitted job array: ${JOB_ID}"
echo "  - 44 tasks total (22 chromosomes x 2 sexes)"

# -----------------------------------------------------------------------------
# Step 2: Submit merge job with dependency
# -----------------------------------------------------------------------------
echo ""
echo "Submitting merge job (will run after array completes)..."

MERGE_JOB_ID=$(sbatch --parsable --dependency=afterok:${JOB_ID} "${SCR_DIR}/merge_results_sex.sh")

if [ -z "${MERGE_JOB_ID}" ]; then
    echo "WARNING: Failed to submit merge job"
    echo "You can run it manually after all jobs complete:"
    echo "  bash ${SCR_DIR}/merge_results_sex.sh"
else
    echo "✓ Submitted merge job: ${MERGE_JOB_ID}"
    echo "  - Will run after all chromosome+sex jobs complete successfully"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Pipeline Submitted Successfully!"
echo "=========================================="
echo ""
echo "Job IDs:"
echo "  - Chromosome+sex jobs (array): ${JOB_ID}"
echo "  - Merge job: ${MERGE_JOB_ID:-'Not submitted'}"
echo ""
echo "Monitor progress:"
echo "  squeue -u ${USER}"
echo ""
echo "Check logs in:"
echo "  ${BASE_DIR}/logs/"
echo ""
echo "After completion, results will be in:"
echo "  ${BASE_DIR}/results_female/mvgwas_wmh_female.tsv"
echo "  ${BASE_DIR}/results_male/mvgwas_wmh_male.tsv"
