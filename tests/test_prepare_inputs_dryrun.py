import os
import subprocess
import tempfile
import unittest
import pandas as pd

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class TestPrepareInputsDryRun(unittest.TestCase):
    def test_prepare_inputs_dryrun_runs(self):
        with tempfile.TemporaryDirectory() as td:
            cov = pd.DataFrame({
                "ID":["1","2"],
                "age":["50","60"],
                "sex":["1","2"],
                "PC1":["0","0"],"PC2":["0","0"],"PC3":["0","0"],"PC4":["0","0"],"PC5":["0","0"]
            })
            phe = pd.DataFrame({"ID":["1","2"],"WMH":["0.1","0.2"]})
            cov_path = os.path.join(td, "cov.tsv")
            phe_path = os.path.join(td, "phe.tsv")
            cov.to_csv(cov_path, sep="\\t", index=False)
            phe.to_csv(phe_path, sep="\\t", index=False)

            vcf_path = os.path.join(td, "geno.vcf.gz")
            open(vcf_path, "w").close()
            sample_ids = os.path.join(td, "sample_ids.txt")
            with open(sample_ids, "w") as f:
                f.write("1\n2\n")

            outdir = os.path.join(td, "out")
            cmd = [
                "python3",
                os.path.join(REPO_ROOT, "scripts/preprocessing/prepare_inputs.py"),
                "--covar", cov_path,
                "--pheno", phe_path,
                "--vcf", vcf_path,
                "--sample-ids-file", sample_ids,
                "--outdir", outdir,
                "--dry-run"
            ]
            subprocess.check_call(cmd)

if __name__ == "__main__":
    unittest.main()
