
import json
import os


# Paths to both folders
folder_path_mine = "/Users/chadaniacharya/Downloads/json_files_2_mine/ord.json"
folder_path_maitri = "/Users/chadaniacharya/Downloads/json_files_1_maitri/ord.json"

# Function to load JSON lines and extract sorted order IDs
def extract_sorted_order_ids(file_path):
    order_ids = []
    try:
        with open(file_path, 'r') as file:
            for line in file:
                data = json.loads(line)
                order_id = data.get("OrderID")
                if order_id is not None:
                    order_ids.append(order_id)
        return sorted(order_ids)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return []

# Extract and sort order IDs from both folders
sorted_order_ids_mine = extract_sorted_order_ids(folder_path_mine)
sorted_order_ids_maitri = extract_sorted_order_ids(folder_path_maitri)

# Find unique indices for each list
unique_indices_mine = [i for i, order_id in enumerate(sorted_order_ids_mine) if order_id not in sorted_order_ids_maitri]
unique_indices_maitri = [i for i, order_id in enumerate(sorted_order_ids_maitri) if order_id not in sorted_order_ids_mine]
print(unique_indices_mine)
print(unique_indices_maitri)  # Display indices

# Check if all elements are the same in both sorted lists
are_all_indexes_same = sorted_order_ids_mine == sorted_order_ids_maitri

print(are_all_indexes_same)  # True if both lists are identical, False otherwise




# # Path to your folder
# folder_path = "/Users/chadaniacharya/Downloads/json_files_2_mine"
# file_name = "ord.json"
# file_path = os.path.join(folder_path, file_name)

# # Function to load JSON lines and extract order IDs
# def extract_order_ids(file_path):
#     order_ids = []
#     with open(file_path, 'r') as file:
#         for line in file:
#             data = json.loads(line)
#             order_id = data.get("OrderID")
#             if order_id is not None:
#                 order_ids.append(order_id)
#     return sorted(order_ids)

# # Extract and sort order IDs
# sorted_order_ids = extract_order_ids(file_path)
# print(sorted_order_ids[:100])  # Display first 10 sorted order IDs for verification
