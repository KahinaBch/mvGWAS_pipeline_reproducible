#!/bin/bash
# =============================================================================
# Merge GWAS Results from All Chromosomes
# =============================================================================
# Run this after all chromosome jobs have completed
# Usage: bash merge_results.sh
# =============================================================================

#SBATCH --job-name=merge_gwas
#SBATCH --output=logs/merge_gwas_%j.out
#SBATCH --error=logs/merge_gwas_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/GWAS_bbb/2025_12_17_sex_strat"
RESULTS_DIR="${BASE_DIR}/results_men"
TEMP_DIR="${BASE_DIR}/temp_chr"

echo "=========================================="
echo "Merging GWAS Results from All Chromosomes"
echo "Date: $(date)"
echo "=========================================="

# -----------------------------------------------------------------------------
# Check that all chromosome results exist
# -----------------------------------------------------------------------------
echo ""
echo "Checking chromosome results..."

MISSING_CHR=""
for CHR in $(seq 1 22); do
    RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
    if [ ! -f "${RESULT_FILE}" ]; then
        echo "✗ Missing: chr${CHR}"
        MISSING_CHR="${MISSING_CHR} ${CHR}"
    else
        echo "✓ Found: chr${CHR} ($(wc -l < ${RESULT_FILE}) variants)"
    fi
done

if [ -n "${MISSING_CHR}" ]; then
    echo ""
    echo "WARNING: Missing results for chromosomes:${MISSING_CHR}"
    echo "Some chromosome jobs may have failed. Check logs."
    read -p "Continue with available results? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Merge results
# -----------------------------------------------------------------------------
echo ""
echo "Merging results..."

MERGED_FILE="${RESULTS_DIR}/mvgwas_whole_genome_BBB_men.tsv"

# Get header from first available result file
for CHR in $(seq 1 22); do
    RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
    if [ -f "${RESULT_FILE}" ]; then
        head -1 ${RESULT_FILE} > ${MERGED_FILE}
        break
    fi
done

# Concatenate all results (without headers)
for CHR in $(seq 1 22); do
    RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
    if [ -f "${RESULT_FILE}" ]; then
        tail -n +2 ${RESULT_FILE} >> ${MERGED_FILE}
    fi
done

echo "✓ Merged file created: ${MERGED_FILE}"
echo "  Total variants: $(tail -n +2 ${MERGED_FILE} | wc -l)"

# -----------------------------------------------------------------------------
# Create summary statistics
# -----------------------------------------------------------------------------
echo ""
echo "Creating summary statistics..."

SUMMARY_FILE="${RESULTS_DIR}/mvgwas_summary.txt"

cat > ${SUMMARY_FILE} << EOF
=============================================================================
MVGWAS Whole Genome Analysis - Summary
=============================================================================
Date: $(date)
Phenotype: BBB Selected Proteins
=============================================================================

Total variants tested: $(tail -n +2 ${MERGED_FILE} | wc -l)

Variants per chromosome:
EOF

for CHR in $(seq 1 22); do
    RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
    if [ -f "${RESULT_FILE}" ]; then
        COUNT=$(tail -n +2 ${RESULT_FILE} | wc -l)
        printf "  chr%-2s: %s variants\n" ${CHR} ${COUNT} >> ${SUMMARY_FILE}
    else
        printf "  chr%-2s: MISSING\n" ${CHR} >> ${SUMMARY_FILE}
    fi
done

echo "" >> ${SUMMARY_FILE}
echo "Output files:" >> ${SUMMARY_FILE}
echo "  - ${MERGED_FILE}" >> ${SUMMARY_FILE}

cat ${SUMMARY_FILE}

# -----------------------------------------------------------------------------
# Cleanup temporary files (optional)
# -----------------------------------------------------------------------------
echo ""
read -p "Delete temporary chromosome VCF files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleaning up temporary files..."
    rm -rf ${TEMP_DIR}
    echo "✓ Temporary files deleted"
else
    echo "Temporary files kept in: ${TEMP_DIR}"
fi

echo ""
echo "=========================================="
echo "Merge completed!"
echo "=========================================="
echo "Main output: ${MERGED_FILE}"
echo "Summary: ${SUMMARY_FILE}"
