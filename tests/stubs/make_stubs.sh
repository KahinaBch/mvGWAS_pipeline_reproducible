#!/usr/bin/env bash
set -euo pipefail
stubdir="$1"
mkdir -p "$stubdir"

mk_generic() {
  local name="$1"
  cat > "${stubdir}/${name}" <<'EOF'
#!/usr/bin/env bash
echo "[stub] $0 $*" >&2
exit 0
EOF
  chmod +x "${stubdir}/${name}"
}

# Special bcftools stub to support: bcftools query -l <vcf>
cat > "${stubdir}/bcftools" <<'EOF'
#!/usr/bin/env bash
# Minimal stub for tests.
if [[ "$1" == "query" && "$2" == "-l" ]]; then
  # Emit at least one sample ID so strong dry-run overlap is non-zero in tests.
  echo "1"
  exit 0
fi
echo "[stub] $0 $*" >&2
exit 0
EOF
chmod +x "${stubdir}/bcftools"

mk_generic sbatch
mk_generic nextflow
mk_generic java
mk_generic Rscript
mk_generic squeue
mk_generic plink2
mk_generic plink
