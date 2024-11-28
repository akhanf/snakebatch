#!/bin/bash
set -euo pipefail

# Inputs
CONTAINER=$1
BIDS_DIR=$2
OUTPUT_DIR=$3
EXTRA_ARGS=$4



# Run the container
singularity run -e $CONTAINER $BIDS_DIR $OUTPUT_DIR $EXTRA_ARGS

