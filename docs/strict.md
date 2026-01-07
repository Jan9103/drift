# Drift Strict

A nagger built into drift.

## Usage

Just add `load-env drift/strict.nu` to the first line of your main script.

Nu is not fully deterministic, but it should run as one of the first things
at every execution then.

## Rules

* Externals **have** to use `^` or `run-external`. No implicit external calls.
