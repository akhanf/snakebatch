# batch-snakedwi
Batch submit workflow for [snakedwi](https://github.com/akhanf/snakedwi). Runs each subject/session as a separate job,
writing output to a temp directory (e.g. $SLURM_TMPDIR) and copying the final outputs. 
 

## Pre-requisites

 - BIDS dataset(s) that also includes a .pybids folder (which can be created with [pybidsdb](https://github.com/pvandyken/pybidsdb))
 - Virtual environment with snakemake and snakebids activated (can use `source $SNAKEMAKE_VENV_DIR/activate` if using khanlab neuroglia-helpers)
 - A cluster profile to submit the jobs, e.g. [cc-slurm](https://github.com/khanlab/cc-slurm)
 - Container dependencies downloaded already to a --singularity-prefix folder (note: default is `/project/6050199/akhanf/singularity/snakemake_containers/`)

## Instructions

1. Clone this repository (can clone to a `/project` folder since it still runs the app on local scratch)

2. Edit the `config/snakebids.yml` file to customize your run options. Pay attention to the following options:
  - `tag:` this is the tag, branch, or commit to use for the app
  - `opts:` this defines the CLI options for the app
  - `resources:` this defines how much resources each session is allocated when submitting jobs

3. Run the workflow using the CLI as a dry-run:

```
./run.py <PATH_TO_BIDS> <PATH_TO_OUTPUT> participant -np
```

4. If you want to restrict by participants or sessions, can use `--participant-label`, `--exclude-participant-label`, or `--filter-dwi session=SESSION_TO_FILTER`, e.g.:

5. Run all the jobs using a cluster profile, e.g. 

```
./run.py <PATH_TO_BIDS> <PATH_TO_OUTPUT> participant -np --profile cc-slurm --immediate-submit --notemp 
```

## Notes 
 - The workflow only includes sessions where both dwi and t1 exist (by taking an intersection of those lists)
 - Only runs that completed successfully will have any outputs retained. For those that failed you will need to inspect the slurm logs.
 - The `work` subfolder will not be retained at all, if you need this, you can add it to the `root_folders:` list in the config
 - It is generally OK to use immediate-submit for this workflow, since it does not have multiple layers of dependent rules. Furthermore, the `--notemp` option does not get propagated to the snakemake call used to run the app on each subject/session.
 - With the latest version of Snakemake, the `--slurm` option can be used to submit jobs instead of `--profile cc-slurm`. This will work for jobs without GPUs, however, some additional logic will need to be added to this workflow to support this option with GPUs (coming soon).

