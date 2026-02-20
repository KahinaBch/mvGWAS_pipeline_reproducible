#!/bin/bash
# =============================================================================
# Merge GWAS Results from All Chromosomes - Sex-stratified
# =============================================================================
# Run this after all chromosome jobs (female + male) have completed.
#
# Usage:
#   sbatch merge_results_sex.sh
#   or
#   bash  merge_results_sex.sh
# =============================================================================

#SBATCH --job-name=merge_gwas_sex
#SBATCH --output=logs/merge_gwas_sex_%j.out
#SBATCH --error=logs/merge_gwas_sex_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR="/home/kbaouche/mvGWAS_WMHv"

FEMALE_RESULTS_DIR="${BASE_DIR}/results_female"
MALE_RESULTS_DIR="${BASE_DIR}/results_male"

FEMALE_TEMP_DIR="${BASE_DIR}/data_female/temp_chr_vcf"
MALE_TEMP_DIR="${BASE_DIR}/data_male/temp_chr_vcf"

mkdir -p "${BASE_DIR}/logs"

echo "=========================================="
echo "Merging GWAS Results (Sex-stratified)"
echo "Date: $(date)"
echo "=========================================="

merge_one_sex () {
    local SEX="$1"
    local RESULTS_DIR="$2"
    local TEMP_DIR="$3"

    echo ""
    echo "------------------------------------------"
    echo "Processing: ${SEX}"
    echo "Results dir: ${RESULTS_DIR}"
    echo "------------------------------------------"

    # Check chromosome results
    echo "Checking chromosome results for ${SEX}..."
    local MISSING_CHR=""
    for CHR in $(seq 1 22); do
        local RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
        if [ ! -f "${RESULT_FILE}" ]; then
            echo "✗ Missing: ${SEX} chr${CHR}"
            MISSING_CHR="${MISSING_CHR} ${CHR}"
        else
            echo "✓ Found: ${SEX} chr${CHR} ($(wc -l < "${RESULT_FILE}") lines)"
        fi
    done

    if [ -n "${MISSING_CHR}" ]; then
        echo ""
        echo "WARNING: Missing results for ${SEX} chromosomes:${MISSING_CHR}"
        echo "Some jobs may have failed. Check logs."
        read -p "Continue with available ${SEX} results? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Merge
    echo ""
    echo "Merging ${SEX} results..."
    local MERGED_FILE="${RESULTS_DIR}/mvgwas_wmh_${SEX}.tsv"

    # header
    rm -f "${MERGED_FILE}"
    for CHR in $(seq 1 22); do
        local RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
        if [ -f "${RESULT_FILE}" ]; then
            head -1 "${RESULT_FILE}" > "${MERGED_FILE}"
            break
        fi
    done

    # data
    for CHR in $(seq 1 22); do
        local RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
        if [ -f "${RESULT_FILE}" ]; then
            tail -n +2 "${RESULT_FILE}" >> "${MERGED_FILE}"
        fi
    done

    echo "✓ Merged file created: ${MERGED_FILE}"
    echo "  Total variants: $(tail -n +2 "${MERGED_FILE}" | wc -l)"

    # Summary
    echo ""
    echo "Creating summary statistics for ${SEX}..."
    local SUMMARY_FILE="${RESULTS_DIR}/mvgwas_summary_${SEX}.txt"

    cat > "${SUMMARY_FILE}" << EOF
=============================================================================
MVGWAS Whole Genome Analysis - Summary (${SEX})
=============================================================================
Date: $(date)
Phenotype: WMH (multivariate)
=============================================================================

Total variants tested: $(tail -n +2 "${MERGED_FILE}" | wc -l)

Variants per chromosome:
EOF

    for CHR in $(seq 1 22); do
        local RESULT_FILE="${RESULTS_DIR}/chr${CHR}/mvgwas_chr${CHR}.tsv"
        if [ -f "${RESULT_FILE}" ]; then
            local COUNT
            COUNT=$(tail -n +2 "${RESULT_FILE}" | wc -l)
            printf "  chr%-2s: %s variants
" "${CHR}" "${COUNT}" >> "${SUMMARY_FILE}"
        else
            printf "  chr%-2s: MISSING
" "${CHR}" >> "${SUMMARY_FILE}"
        fi
    done

    echo "" >> "${SUMMARY_FILE}"
    echo "Output files:" >> "${SUMMARY_FILE}"
    echo "  - ${MERGED_FILE}" >> "${SUMMARY_FILE}"

    echo ""
    echo "----- ${SEX} summary -----"
    cat "${SUMMARY_FILE}"

    # Cleanup (optional)
    echo ""
    read -p "Delete temporary chromosome VCF files for ${SEX}? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning up ${SEX} temporary files..."
        rm -rf "${TEMP_DIR}"
        echo "✓ ${SEX} temporary files deleted"
    else
        echo "${SEX} temporary files kept in: ${TEMP_DIR}"
    fi

    echo ""
    echo "Done merging ${SEX}"
}

# Run for both sexes
merge_one_sex "female" "${FEMALE_RESULTS_DIR}" "${FEMALE_TEMP_DIR}"
merge_one_sex "male"   "${MALE_RESULTS_DIR}"   "${MALE_TEMP_DIR}"

echo ""
echo "=========================================="
echo "Merge completed for female + male!"
echo "=========================================="
echo "Female: ${FEMALE_RESULTS_DIR}/mvgwas_wmh_female.tsv"
echo "Male:   ${MALE_RESULTS_DIR}/mvgwas_wmh_male.tsv"
