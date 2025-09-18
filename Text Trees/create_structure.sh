#!/bin/bash
# This script reads Tree.md and creates the folder/file structure described in it.
# Run: bash create_structure.sh

TREE_FILE="Tree.md"
BASE_PATH="$(dirname "$0")"

# Function to trim leading tree characters and whitespace
tree_to_path() {
    local line="$1"
    # Remove tree drawing characters and leading whitespace
    local clean=$(echo "$line" | sed 's/[│├└─]//g' | sed 's/^ *//')
    echo "$clean"
}

# Main logic
current_path=""
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    # Get indentation (number of leading spaces)
    indent=$(echo "$line" | grep -o '^[ │├└]*' | wc -c)
    name=$(tree_to_path "$line")
    # Skip if name is empty
    [[ -z "$name" ]] && continue
    # If it's a folder (ends with /)
    if [[ "$name" =~ /$ ]]; then
        # Build path based on indentation
        # Remove trailing slash
        name="${name%/}"
        # Track parent paths by indentation
        path_levels[$indent]="$name"
        # Build full path
        full_path=""
        for i in $(printf "%s\n" "${!path_levels[@]}" | sort -n); do
            if (( i <= indent )); then
                [[ -n "${path_levels[$i]}" ]] && full_path+="/${path_levels[$i]}"
            fi
        done
        mkdir -p "$BASE_PATH$full_path"
    # If it's a file (contains a dot and not ending with /)
    elif [[ "$name" =~ \.[a-zA-Z0-9]+$ ]]; then
        # Find parent path
        parent_path=""
        for i in $(printf "%s\n" "${!path_levels[@]}" | sort -n); do
            if (( i < indent )); then
                [[ -n "${path_levels[$i]}" ]] && parent_path+="/${path_levels[$i]}"
            fi
        done
        mkdir -p "$BASE_PATH$parent_path"
        touch "$BASE_PATH$parent_path/$name"
    fi
done < "$TREE_FILE"

echo "Structure created from $TREE_FILE."
    TOP_FOLDER="Server_Administration"
    echo "\nFolder structure for $TOP_FOLDER:"
    tree "$TOP_FOLDER" | tee "$TOP_FOLDER/folder_tree.txt"
