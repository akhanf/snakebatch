# batch-snakedwi
Batch submit workflow for [snakedwi](https://github.com/akhanf/snakedwi). Runs each subject/session as a separate job,
writing output to a temp directory (e.g. $SLURM_TMPDIR) and copying the final outputs. 

Notes:
 - The workflow only includes sessions where both dwi and t1 exist (by taking an intersection of those lists)
 - It looks for a .pybids directory inside the input BIDS dataset, which can be created with [pybidsdb](https://github.com/pvandyken/pybidsdb)
 
TO DO: finish this

