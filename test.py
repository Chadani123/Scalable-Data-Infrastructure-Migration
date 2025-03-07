import json
import os
from collections import Counter

# Paths to your two folders
folder1 = "/Users/chadaniacharya/Downloads/json_files_1_maitri"
folder2 = "/Users/chadaniacharya/Downloads/json_files_2_mine"

# Files to compare (excluding custom.json as per your request)
files_to_compare = ["cust1.json", "cust2.json", "ord.json", "prod.json"]

def load_json_file(filepath):
    with open(filepath, 'r') as file:
        # Load each line as a JSON object, returning a list of dictionaries
        data = [json.loads(line) for line in file]
    return data

def normalize_keys(entry):
    """Normalize keys by removing spaces and ensuring consistent formatting."""
    if isinstance(entry, dict):
        return {k.replace(" ", ""): normalize_keys(v) for k, v in entry.items()}
    elif isinstance(entry, list):
        return [normalize_keys(e) for e in entry]
    else:
        return entry

def make_hashable(entry):
    """Convert a JSON entry to a hashable type, handling nested lists and dictionaries."""
    if isinstance(entry, dict):
        # Convert dictionaries by sorting items and making values hashable
        return tuple((k, make_hashable(v)) for k, v in sorted(entry.items()))
    elif isinstance(entry, list):
        # Convert lists by making each element hashable
        return tuple(make_hashable(e) for e in entry)
    else:
        # Return the entry as is if it's already hashable (e.g., int, str)
        return entry

def compare_files(file1_path, file2_path):
    data1 = load_json_file(file1_path)
    data2 = load_json_file(file2_path)

    # Normalize keys in each entry
    data1 = [normalize_keys(entry) for entry in data1]
    data2 = [normalize_keys(entry) for entry in data2]

    # Convert each entry in data to a hashable structure
    data1_counter = Counter(make_hashable(entry) for entry in data1)
    data2_counter = Counter(make_hashable(entry) for entry in data2)

    # Calculate differences
    common_entries = sum((data1_counter & data2_counter).values())
    unique_in_file1 = sum((data1_counter - data2_counter).values())
    unique_in_file2 = sum((data2_counter - data1_counter).values())

    return common_entries, unique_in_file1, unique_in_file2

# Iterate over each file to compare
for filename in files_to_compare:
    file1_path = os.path.join(folder1, filename)
    file2_path = os.path.join(folder2, filename)

    if os.path.exists(file1_path) and os.path.exists(file2_path):
        common, unique1, unique2 = compare_files(file1_path, file2_path)
        
        print(f"Comparison for {filename}:")
        print(f"  Common entries: {common}")
        print(f"  Unique entries in {file1_path}: {unique1}")
        print(f"  Unique entries in {file2_path}: {unique2}")
        print("\n")
    else:
        print(f"{filename} not found in one of the folders.")
