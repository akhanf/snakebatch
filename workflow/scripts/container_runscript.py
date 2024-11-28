#from snakemake import shell
#shell("singularity run -e {snakemake.input.container} {snakemake.input.bids} {snakemake.resources.tmpdir}/out {snakemake.params.analysis_level} {snakemake.params.args} {snakemake.params.default_opts} --participant-label {snakemake.wildcards.subject} && pushd {snakemake.resources.tmpdir}/out && zip out.zip -r * && popd && mv {snakemake.resources.tmpdir}/out/out.zip  {snakemake.output.zipfile}")

import subprocess
import zipfile
import os
from pathlib import Path
import tempfile

# Create a temporary directory within the specified root directory
with tempfile.TemporaryDirectory(dir=snakemake.resources.tmpdir) as temp_dir:
    temp_dir_path = Path(temp_dir) / "out"
    temp_dir_path.mkdir(parents=True, exist_ok=True)  # Create the 'out' subdirectory

    # Prepare the Singularity command
    singularity_command = [
        "singularity", "run", "-e",
        str(snakemake.input.container),
        str(snakemake.input.bids),
        str(temp_dir_path),
        str(snakemake.params.analysis_level)
    ]

    # Add additional parameters if defined
    if snakemake.params.args:
        singularity_command.extend(snakemake.params.args.split())
    if snakemake.params.default_opts:
        singularity_command.extend(snakemake.params.default_opts.split())
    
    # Add wildcard parameters
    singularity_command.extend(["--participant-label", str(snakemake.wildcards.subject)])

    # Execute the Singularity command
    subprocess.run(singularity_command, check=True)

    # Define paths for input and output
    zipfile_path = Path(snakemake.output.zipfile)
    
    # Create a zip file using Python's zipfile module
    ignore_patterns = [".snakebids", ".snakemake"]

    with zipfile.ZipFile(zipfile_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(temp_dir_path):
            for file in files:
                file_path = Path(root) / file
                relative_path = file_path.relative_to(temp_dir_path)
                
                # Skip files that match any ignore pattern
                if any(str(relative_path).startswith(pattern) for pattern in ignore_patterns):
                    continue
                
                # Write file to the zip archive with a relative path
                zf.write(file_path, relative_path)

    # Note: The temporary directory and its contents will be automatically cleaned up
    # after the `with` block is exited.

