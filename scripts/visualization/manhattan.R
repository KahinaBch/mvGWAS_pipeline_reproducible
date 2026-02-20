#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly=TRUE)

if (length(args) < 2) {
  cat("Usage: manhattan.R <gwas_results.tsv> <out.png>\n")
  quit(status=1)
}

infile <- args[1]
outfile <- args[2]

d <- read.table(infile, header=TRUE, sep="\t", stringsAsFactors=FALSE, comment.char="")

# Attempt to find CHR/BP/P columns with common names
chr_col <- intersect(c("CHR","chr","chrom","CHROM"), colnames(d))
bp_col  <- intersect(c("BP","bp","pos","POS","position"), colnames(d))
p_col   <- intersect(c("P","p","pval","p_value","PVAL","p.value"), colnames(d))

if (length(chr_col)==0 || length(bp_col)==0 || length(p_col)==0) {
  stop("Missing required columns. Need CHR, BP, and P (or common variants).")
}

CHR <- as.integer(d[[chr_col[1]]])
BP  <- as.numeric(d[[bp_col[1]]])
P   <- as.numeric(d[[p_col[1]]])

ok <- is.finite(CHR) & is.finite(BP) & is.finite(P) & P>0 & P<=1
CHR <- CHR[ok]; BP <- BP[ok]; P <- P[ok]

# Order by chr then bp
ord <- order(CHR, BP)
CHR <- CHR[ord]; BP <- BP[ord]; P <- P[ord]

# Compute cumulative position
chr_levels <- sort(unique(CHR))
chr_offsets <- setNames(rep(0, length(chr_levels)), chr_levels)
cum <- numeric(length(BP))
offset <- 0
for (c in chr_levels) {
  idx <- which(CHR == c)
  cum[idx] <- BP[idx] + offset
  offset <- max(cum[idx])
  chr_offsets[as.character(c)] <- mean(range(cum[idx]))
}

png(outfile, width=2000, height=900, res=150)
plot(cum, -log10(P), pch=20, cex=0.4,
     xaxt="n", xlab="Chromosome", ylab="-log10(p)")
axis(1, at=chr_offsets, labels=names(chr_offsets))
abline(h=-log10(5e-8), lty=2)
dev.off()
