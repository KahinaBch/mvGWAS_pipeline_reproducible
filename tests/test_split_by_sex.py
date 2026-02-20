import os
import subprocess
import tempfile
import unittest
import pandas as pd

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def write_tsv(path, df):
    df.to_csv(path, sep="\t", index=False)

class TestSplitBySex(unittest.TestCase):
    def test_split_by_sex_basic(self):
        with tempfile.TemporaryDirectory() as td:
            cov = pd.DataFrame({
                "ID": ["1","2","3","4"],
                "age": ["50","60","55","70"],
                "sex": ["1","2","1","2"],
                "PC1": ["0","0","0","0"],
            })
            phe = pd.DataFrame({
                "ID": ["1","2","3","4"],
                "WMH": ["0.1","0.2","0.3","0.4"],
            })
            cov_path = os.path.join(td, "cov.tsv")
            phe_path = os.path.join(td, "phe.tsv")
            outdir = os.path.join(td, "out")

            write_tsv(cov_path, cov)
            write_tsv(phe_path, phe)

            cmd = [
                "python3",
                os.path.join(REPO_ROOT, "scripts/preprocessing/split_by_sex.py"),
                "--covar", cov_path,
                "--pheno", phe_path,
                "--outdir", outdir,
                "--id-col", "ID",
                "--sex-col", "sex",
                "--male-code", "1",
                "--female-code", "2",
            ]
            subprocess.check_call(cmd)

            m_cov = os.path.join(outdir, "data_male", "WMH_covariates.tsv")
            f_cov = os.path.join(outdir, "data_female", "WMH_covariates.tsv")
            m_phe = os.path.join(outdir, "data_male", "WMH_phenotypes.tsv")
            f_phe = os.path.join(outdir, "data_female", "WMH_phenotypes.tsv")

            for p in [m_cov, f_cov, m_phe, f_phe]:
                self.assertTrue(os.path.exists(p), f"Missing expected file: {p}")

            m_cov_df = pd.read_csv(m_cov, sep="\t", dtype=str)
            f_cov_df = pd.read_csv(f_cov, sep="\t", dtype=str)
            self.assertEqual(len(m_cov_df), 2)
            self.assertEqual(len(f_cov_df), 2)

            m_phe_df = pd.read_csv(m_phe, sep="\t", dtype=str)
            f_phe_df = pd.read_csv(f_phe, sep="\t", dtype=str)
            self.assertEqual(len(m_phe_df), 2)
            self.assertEqual(len(f_phe_df), 2)

if __name__ == "__main__":
    unittest.main()
