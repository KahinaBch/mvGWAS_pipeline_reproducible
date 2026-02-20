#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly=TRUE)

if (length(args) < 2) {
  cat("Usage: qqplot.R <gwas_results.tsv> <out.png>\n")
  quit(status=1)
}

infile <- args[1]
outfile <- args[2]

d <- read.table(infile, header=TRUE, sep="\t", stringsAsFactors=FALSE, comment.char="")
# Try common p-value column names
pcol <- intersect(c("P","p","pval","p_value","PVAL","p.value"), colnames(d))
if (length(pcol) == 0) stop("No p-value column found. Expected one of: P, p, pval, p_value, PVAL, p.value")
p <- d[[pcol[1]]]
p <- p[is.finite(p) & p > 0 & p <= 1]

exp <- -log10(ppoints(length(p)))
obs <- -log10(sort(p))

png(outfile, width=1200, height=1200, res=150)
plot(exp, obs, xlab="Expected -log10(p)", ylab="Observed -log10(p)", pch=20)
abline(0,1)
dev.off()
