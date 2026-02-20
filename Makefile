.PHONY: test test-python test-dryrun test-plink-dryrun

test: test-python test-dryrun test-plink-dryrun

test-python:
	python3 -m unittest discover -s tests -p "test_*.py" -v

test-dryrun:
	bash tests/test_dry_run.sh

test-plink-dryrun:
	bash tests/test_plink_input_dry_run.sh
