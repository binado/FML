#!/bin/bash

set -e

default_ini_filename="camb_params.ini"

usage() {
    echo "Usage: $0 <parameter_file>"
    echo "  <parameter_file>  Path to the parameter file for generating initial conditions"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

generate_ini_file() {
    if ! which lua &> /dev/null; then
        echo "Lua is not installed. Please install Lua to proceed."
        exit 1
    fi
    lua get_initial_conditions.lua "$1"
}

temp_file=$(mktemp)
if ! generate_ini_file "$1" > "$temp_file"; then
    echo "Error: Failed to generate ini file from parameter '$1'"
    rm -f "$temp_file"
    exit 1
fi

output_dir=$(head -n 1 "$temp_file")
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi
ini_filepath="$output_dir/$default_ini_filename"
tail -n +2 "$temp_file" > "$ini_filepath"
rm "$temp_file"

if ! which camb &> /dev/null; then
    echo "CAMB is not installed or not in PATH. Please install CAMB to proceed."
    exit 1
fi
(cd "$output_dir" && camb "$(basename "$ini_filepath")")
