#!/bin/bash
# =============================================================================
# Run mvgwas-nf Pipeline on Whole Genome Data - Parallel by Chromosome
# =============================================================================
# This script splits the VCF by chromosome and runs the pipeline in parallel
# for each chromosome using SLURM job arrays
# 
# Usage: sbatch run_mvgwas_parallel.sh
# =============================================================================

#SBATCH --job-name=mvgwas_wmhv
#SBATCH --output=logs/mvgwas_wmhv_%A_%a.out
#SBATCH --error=logs/mvgwas_wmhv_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1-22
#SBATCH --partition=genoa
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=kbaouche@barcelonabeta.org

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/mvGWAS_WMHv"
DATA_DIR="${BASE_DIR}/data"
RESULTS_DIR="${BASE_DIR}/results"
PIPELINE_DIR="/home/kbaouche/mvgwas-nf"

# Input files
VCF_FILE="${DATA_DIR}/whole_genome_alfaids_men.vcf.gz"
PHENOTYPE_FILE="${DATA_DIR}/phenotypes_selected_bbb_vcf_filtered_men.tsv"
COVARIATE_FILE="${DATA_DIR}/covariate_alfa_id_age_gender_vcf_filtered_men.tsv"
CHROMOSOMES_FILE="${DATA_DIR}/chromosomes.txt"

# Temporary directory for chromosome-specific VCFs
TEMP_DIR="${DATA_DIR}/temp_chr_vcf"

# Get chromosome number from SLURM array task ID
CHR=${SLURM_ARRAY_TASK_ID}

echo "=========================================="
echo "mvgwas-nf Whole Genome Analysis"
echo "Chromosome: ${CHR}"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Date: $(date)"
echo "=========================================="

# -----------------------------------------------------------------------------
# Create directories
# -----------------------------------------------------------------------------
mkdir -p ${RESULTS_DIR}/chr${CHR}
mkdir -p ${TEMP_DIR}
mkdir -p ${BASE_DIR}/logs

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
# Load modules
# -----------------------------------------------------------------------------
echo ""
echo "Loading modules..."

# Load required modules - adjust module names for your cluster
# Run 'module avail' to see available modules
module purge
module load 2025

# Load BCFtools
module load BCFtools/1.22-GCC-14.2.0

# Load Java 17+ for Nextflow (check available versions with: module avail java)
module load Java/21.0.7

# Check if commands are available
echo "Checking required tools..."
which java && java -version 2>&1 | head -1
which bcftools && bcftools --version | head -1

# -----------------------------------------------------------------------------
# Extract chromosome-specific VCF (if not already done)
# -----------------------------------------------------------------------------
CHR_VCF="${TEMP_DIR}/chr${CHR}.vcf.gz"

echo ""
echo "Preparing chromosome ${CHR} VCF..."

if [ ! -f "${CHR_VCF}" ]; then
    echo "Extracting chromosome ${CHR} from whole genome VCF..."
    bcftools view -r ${CHR} ${VCF_FILE} -Oz -o ${CHR_VCF}
    bcftools index -t ${CHR_VCF}
    echo "✓ Created: ${CHR_VCF}"
else
    echo "✓ Using existing: ${CHR_VCF}"
fi

# -----------------------------------------------------------------------------
# Run mvgwas-nf pipeline for this chromosome
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Running mvgwas-nf pipeline for chromosome ${CHR}"
echo "=========================================="

OUTPUT_DIR="${RESULTS_DIR}/chr${CHR}"
cd ${OUTPUT_DIR}


nextflow run ${PIPELINE_DIR}/mvgwas.nf \
    --geno ${CHR_VCF} \
    --pheno ${PHENOTYPE_FILE} \
    --cov ${COVARIATE_FILE} \
    --dir ${OUTPUT_DIR} \
    --out mvgwas_chr${CHR}.tsv \
    --l 500 \
    -with-singularity \
    -resume

# -----------------------------------------------------------------------------
# Check results
# -----------------------------------------------------------------------------
echo ""
if [ $? -eq 0 ]; then
    echo "=========================================="
    echo "Chromosome ${CHR} completed successfully!"
    echo "=========================================="
    echo "Results: ${OUTPUT_DIR}/result/mvgwas_chr${CHR}.tsv"
else
    echo "=========================================="
    echo "ERROR: Chromosome ${CHR} failed"
    echo "=========================================="
    echo "Check logs in: ${OUTPUT_DIR}/.nextflow.log"
    exit 1
fi

echo ""
echo "Done chromosome ${CHR}: $(date)"
