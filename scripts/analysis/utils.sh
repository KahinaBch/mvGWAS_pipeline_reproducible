#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# Expand CHRS:
# - "1-22" -> 1 2 ... 22
# - "16,18,20" -> 16 18 20
# - "1-5,10,12-13" -> expands accordingly
expand_chrs() {
  local spec="${1:-1-22}"
  local out=()
  IFS=',' read -ra parts <<< "$spec"
  for p in "${parts[@]}"; do
    if [[ "$p" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local a="${BASH_REMATCH[1]}"; local b="${BASH_REMATCH[2]}"
      if (( a <= b )); then
        for ((i=a;i<=b;i++)); do out+=("$i"); done
      else
        for ((i=a;i>=b;i--)); do out+=("$i"); done
      fi
    elif [[ "$p" =~ ^[0-9]+$ ]]; then
      out+=("$p")
    else
      die "Invalid CHRS spec chunk: '$p' (supported: 1-22, 16,18,20, 1-5,10,12-13)"
    fi
  done
  printf "%s\n" "${out[@]}"
}

# Decide contig naming for bcftools region extraction
# If contigs contain "chr16", returns prefix="chr", else prefix="".
detect_chr_prefix() {
  local vcf="$1"
  need_cmd bcftools
  local has_chr
  has_chr=$(bcftools view -h "$vcf" | awk '/^##contig=/<0{print}' | head -n 50 | grep -m1 -E 'ID=chr[0-9]+' || true)
  if [[ -n "$has_chr" ]]; then
    echo "chr"
  else
    echo ""
  fi
}
