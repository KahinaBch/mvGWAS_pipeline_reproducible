#!/bin/bash
# =============================================================================
# Submit GWAS Pipeline - Master Script
# =============================================================================
# This script submits the parallel GWAS jobs and sets up a dependency
# for the merge job to run after all chromosomes complete
#
# Usage: bash submit_gwas_pipeline.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/GWAS_bbb/2025_12_17_sex_strat"
SCR_DIR="${BASE_DIR}/scr"

echo "=========================================="
echo "Submitting MVGWAS Pipeline"
echo "Date: $(date)"
echo "=========================================="

# Create logs directory
mkdir -p ${BASE_DIR}/logs

# -----------------------------------------------------------------------------
# Step 1: Submit parallel chromosome jobs
# -----------------------------------------------------------------------------
echo ""
echo "Submitting parallel jobs for chromosomes 1-22..."

# Submit the job array and capture the job ID
JOB_ID=$(sbatch --parsable ${SCR_DIR}/run_mvgwas_parallel.sh)

if [ -z "${JOB_ID}" ]; then
    echo "ERROR: Failed to submit job array"
    exit 1
fi

echo "✓ Submitted job array: ${JOB_ID}"
echo "  - 22 parallel jobs (one per chromosome)"

# -----------------------------------------------------------------------------
# Step 2: Submit merge job with dependency
# -----------------------------------------------------------------------------
echo ""
echo "Submitting merge job (will run after all chromosomes complete)..."

MERGE_JOB_ID=$(sbatch --parsable --dependency=afterok:${JOB_ID} ${SCR_DIR}/merge_results.sh)

if [ -z "${MERGE_JOB_ID}" ]; then
    echo "WARNING: Failed to submit merge job"
    echo "You can run it manually after all chromosome jobs complete:"
    echo "  bash ${SCR_DIR}/merge_results.sh"
else
    echo "✓ Submitted merge job: ${MERGE_JOB_ID}"
    echo "  - Will run after all chromosome jobs complete successfully"
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
echo "  - Chromosome jobs (array): ${JOB_ID}"
echo "  - Merge job: ${MERGE_JOB_ID:-'Not submitted'}"
echo ""
echo "Monitor progress:"
echo "  squeue -u kbaouche"
echo ""
echo "Check logs in:"
echo "  ${BASE_DIR}/logs/"
echo ""
echo "After completion, results will be in:"
echo "  ${BASE_DIR}/results/mvgwas_whole_genome_BBB_men.tsv"
