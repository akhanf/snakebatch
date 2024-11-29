import os
import hashlib
import zipfile
import pandas as pd
import json
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import shutil
import tempfile
from pathlib import Path

def get_files_in_zip(zip_path):
    """Returns a list of file names in a zip archive."""
    try:
        with zipfile.ZipFile(zip_path, 'r') as z:
            return z.namelist()
    except zipfile.BadZipFile:
        print(f"Error: {zip_path} is not a valid zip file.")
        return []

def extract_file(zip_path, file_name, output_dir):
    """Extract a specific file from a zip archive to the output directory."""
    with zipfile.ZipFile(zip_path, 'r') as z:
        try:
            # Ensure directory structure exists before extracting
            file_path = os.path.join(output_dir, file_name)
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            z.extract(file_name, output_dir)
            return file_path
        except FileExistsError:
            # Handle potential race condition where the directory was created simultaneously
            pass

def compute_checksum(file_path):
    """Compute the SHA256 checksum of a file."""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def merge_tsv_files(file_paths, output_path):
    """Merge multiple TSV files into one."""
    dfs = [pd.read_csv(fp, sep='\t') for fp in file_paths]
    merged_df = pd.concat(dfs, ignore_index=True)
    merged_df.to_csv(output_path, sep='\t', index=False)

def merge_json_files(file_paths, output_path):
    """Merge multiple JSON files into one by combining their key-value pairs."""
    combined_data = {}
    for file_path in file_paths:
        with open(file_path, 'r') as f:
            data = json.load(f)
        for key, value in data.items():
            if key in combined_data and isinstance(combined_data[key], list) and isinstance(value, list):
                combined_data[key].extend(value)
            elif key in combined_data and combined_data[key] != value:
                print(f"Warning: Conflicting values for key '{key}' in JSON files.")
            else:
                combined_data[key] = value
    with open(output_path, 'w') as f:
        json.dump(combined_data, f, indent=4)

def handle_file(file_name, zips, temp_dir, output_dir):
    """Process a single file from overlapping zip archives."""
    extracted_files = []
    for zip_path in zips:
        extracted_files.append(extract_file(zip_path, file_name, temp_dir))

    output_path = os.path.join(output_dir, file_name)
    output_dir_for_file = os.path.dirname(output_path)

    # Ensure the output directory exists
    os.makedirs(output_dir_for_file, exist_ok=True)

    if len(extracted_files) > 1:
        if all(compute_checksum(f) == compute_checksum(extracted_files[0]) for f in extracted_files):
            # Identical files, pick the first one
            os.rename(extracted_files[0], output_path)
        elif file_name.endswith('.tsv'):
            merge_tsv_files(extracted_files, output_path)
        elif file_name.endswith('.json'):
            merge_json_files(extracted_files, output_path)
        else:
            print(f"Warning: No merge rule for {file_name}. Keeping the first file.")
            os.rename(extracted_files[0], output_path)
    else:
        os.rename(extracted_files[0], output_path)

    # Clean up temp files
    for f in extracted_files:
        if os.path.exists(f):
            os.remove(f)
def zip_output_files(output_dir, zip_file_path):
    """Zips all files in the output directory into a specified archive."""
    with zipfile.ZipFile(zip_file_path, 'w') as archive:
        for root, _, files in os.walk(output_dir):
            for file in files:
                file_path = os.path.join(root, file)
                archive.write(file_path, arcname=os.path.relpath(file_path, output_dir))
    print(f"All files zipped into: {zip_file_path}")

def process_files_in_parallel(file_dict, temp_dir, output_dir, max_workers=4):
    """Process all files in parallel."""
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for file_name, zips in file_dict.items():
            futures.append(executor.submit(handle_file, file_name, zips, temp_dir, output_dir))
        
        for future in as_completed(futures):
            future.result()  # Raises exception if any task failed

def main():

    # Create a temporary directory within the specified root directory
    with tempfile.TemporaryDirectory(dir=snakemake.resources.tmpdir) as temp_dir:

        zip_files = snakemake.input
        output_dir = Path(temp_dir) / "merged_files"
        os.makedirs(output_dir, exist_ok=True)


        # Step 1: Identify overlapping files
        file_occurrences = defaultdict(list)
        for zip_path in zip_files:
            files = get_files_in_zip(zip_path)
            for file in files:
                file_occurrences[file].append(zip_path)

        overlapping_files = {file: zips for file, zips in file_occurrences.items() if len(zips) > 1}
        non_overlapping_files = {file: zips for file, zips in file_occurrences.items() if len(zips) == 1}

        print("Processing files in parallel...")
        process_files_in_parallel(overlapping_files, temp_dir, output_dir)
        process_files_in_parallel(non_overlapping_files, temp_dir, output_dir)

        print(f"Extraction complete. All files are in the '{output_dir}' directory.")

        # zip all the output files
        zip_output_files(output_dir, snakemake.output.zipfile)


if __name__ == "__main__":
    main()

