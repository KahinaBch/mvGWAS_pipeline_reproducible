#!/bin/bash
# =============================================================================
# Run mvgwas-nf Pipeline on Whole Genome Data - Sex-stratified
# =============================================================================
# This script runs mvgwas-nf in parallel by chromosome AND sex using one SLURM job array.
#
# Layout of the array:
#   - Task  1..22  => female, chr = task_id
#   - Task 23..44  => male,   chr = task_id - 22
#
# Expected input layout (can be adjusted below):
#   /home/kbaouche/mvGWAS_WMHv/data_female/
#       geno_ALFA_for_gwas.vcf.gz
#       WMH_phenotypes_complete.tsv
#       WMH_covariates_complete.tsv
#
#   /home/kbaouche/mvGWAS_WMHv/data_male/
#       geno_ALFA_for_gwas.vcf.gz
#       WMH_phenotypes_complete.tsv
#       WMH_covariates_complete.tsv
#
# Output:
#   /home/kbaouche/mvGWAS_WMHv/results_female/chr{CHR}/mvgwas_chr{CHR}.tsv
#   /home/kbaouche/mvGWAS_WMHv/results_male/chr{CHR}/mvgwas_chr{CHR}.tsv
#
# Usage:
#   sbatch run_mvgwas_parallel_sex.sh
# =============================================================================

#SBATCH --job-name=mvgwas_wmhv_sex
#SBATCH --output=logs/mvgwas_wmhv_sex_%A_%a.out
#SBATCH --error=logs/mvgwas_wmhv_sex_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1-44
#SBATCH --partition=genoa
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=kbaouche@barcelonabeta.org

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
PIPELINE_DIR="/home/kbaouche/mvgwas-nf"

FEMALE_DATA_DIR="${BASE_DIR}/data_female"
MALE_DATA_DIR="${BASE_DIR}/data_male"

FEMALE_RESULTS_DIR="${BASE_DIR}/results_female"
MALE_RESULTS_DIR="${BASE_DIR}/results_male"

# Input filenames expected inside each data_* directory
VCF_BASENAME="geno_ALFA_for_gwas.vcf.gz"
PHENO_BASENAME="WMH_phenotypes_complete.tsv"
COV_BASENAME="WMH_covariates_complete.tsv"

# Variants per chunk (Nextflow param --l)
CHUNK_SIZE=500

# -----------------------------------------------------------------------------
# Decode SLURM array task into SEX and CHR
# -----------------------------------------------------------------------------
TASK_ID=${SLURM_ARRAY_TASK_ID}

if [ "${TASK_ID}" -le 22 ]; then
    SEX="female"
    CHR="${TASK_ID}"
    DATA_DIR="${FEMALE_DATA_DIR}"
    RESULTS_DIR="${FEMALE_RESULTS_DIR}"
else
    SEX="male"
    CHR="$((TASK_ID - 22))"
    DATA_DIR="${MALE_DATA_DIR}"
    RESULTS_DIR="${MALE_RESULTS_DIR}"
fi

# Input files
VCF_FILE="${DATA_DIR}/${VCF_BASENAME}"
PHENOTYPE_FILE="${DATA_DIR}/${PHENO_BASENAME}"
COVARIATE_FILE="${DATA_DIR}/${COV_BASENAME}"

# Temporary directory for chromosome-specific VCFs (sex-specific)
TEMP_DIR="${DATA_DIR}/temp_chr_vcf"

echo "=========================================="
echo "mvgwas-nf Sex-stratified Whole Genome Analysis"
echo "Sex: ${SEX}"
echo "Chromosome: ${CHR}"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Date: $(date)"
echo "=========================================="

# -----------------------------------------------------------------------------
# Create directories
# -----------------------------------------------------------------------------
mkdir -p "${RESULTS_DIR}/chr${CHR}"
mkdir -p "${TEMP_DIR}"
mkdir -p "${BASE_DIR}/logs"

# -----------------------------------------------------------------------------
# Check input files
# -----------------------------------------------------------------------------
echo ""
echo "Checking input files..."

if [ ! -f "${VCF_FILE}" ]; then
    echo "ERROR: VCF file not found: ${VCF_FILE}"
    exit 1
fi
echo "✓ VCF file: ${VCF_FILE}"

if [ ! -f "${PHENOTYPE_FILE}" ]; then
    echo "ERROR: Phenotype file not found: ${PHENOTYPE_FILE}"
    exit 1
fi
echo "✓ Phenotype file: ${PHENOTYPE_FILE}"

if [ ! -f "${COVARIATE_FILE}" ]; then
    echo "ERROR: Covariate file not found: ${COVARIATE_FILE}"
    exit 1
fi
echo "✓ Covariate file: ${COVARIATE_FILE}"

# -----------------------------------------------------------------------------
# Load modules (adapt to your cluster)
# -----------------------------------------------------------------------------
echo ""
echo "Loading modules..."

module purge
module load 2025
module load BCFtools/1.22-GCC-14.2.0
module load Java/21.0.7

echo "Checking required tools..."
which java && java -version 2>&1 | head -1
which bcftools && bcftools --version | head -1
which nextflow && nextflow -version | head -2

# -----------------------------------------------------------------------------
# Extract chromosome-specific VCF (if not already done)
# -----------------------------------------------------------------------------
CHR_VCF="${TEMP_DIR}/${SEX}_chr${CHR}.vcf.gz"

echo ""
echo "Preparing ${SEX} chromosome ${CHR} VCF..."

if [ ! -f "${CHR_VCF}" ]; then
    echo "Extracting chromosome ${CHR} from ${SEX} whole genome VCF..."
    bcftools view -r "${CHR}" "${VCF_FILE}" -Oz -o "${CHR_VCF}"
    bcftools index -t "${CHR_VCF}"
    echo "✓ Created: ${CHR_VCF}"
else
    echo "✓ Using existing: ${CHR_VCF}"
fi

# -----------------------------------------------------------------------------
# Run mvgwas-nf pipeline for this chromosome
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Running mvgwas-nf pipeline for ${SEX}, chromosome ${CHR}"
echo "=========================================="

OUTPUT_DIR="${RESULTS_DIR}/chr${CHR}"
cd "${OUTPUT_DIR}"

nextflow run "${PIPELINE_DIR}/mvgwas.nf"     --geno "${CHR_VCF}"     --pheno "${PHENOTYPE_FILE}"     --cov "${COVARIATE_FILE}"     --dir "${OUTPUT_DIR}"     --out "mvgwas_chr${CHR}.tsv"     --l "${CHUNK_SIZE}"     -with-singularity     -resume

# -----------------------------------------------------------------------------
# Check results
# -----------------------------------------------------------------------------
echo ""
if [ $? -eq 0 ]; then
    echo "=========================================="
    echo "${SEX} chr${CHR} completed successfully!"
    echo "=========================================="
    echo "Results: ${OUTPUT_DIR}/mvgwas_chr${CHR}.tsv"
else
    echo "=========================================="
    echo "ERROR: ${SEX} chr${CHR} failed"
    echo "=========================================="
    echo "Check logs in: ${OUTPUT_DIR}/.nextflow.log"
    exit 1
fi

echo ""
echo "Done ${SEX} chr${CHR}: $(date)"
