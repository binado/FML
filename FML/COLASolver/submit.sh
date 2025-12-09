#!/bin/bash

# Get directory of this script (and assume env_setup.sh is here too)
SUBMIT_DIR=$(cd "$(dirname "$0")" && pwd)

# ---------------------------------------------------------
# CHANGE 1: Load Environment Immediately
# We need this so the script can find 'lua' for the parsing step below
# ---------------------------------------------------------
if [ -f "$SUBMIT_DIR/env_setup.sh" ]; then
    source "$SUBMIT_DIR/env_setup.sh"
else
    echo "Error: '$SUBMIT_DIR/env_setup.sh' not found."
    echo "Please ensure your environment setup script is in the same folder."
    exit 1
fi

# Check for --dry-run flag
DRY_RUN=false
PARAM_FILE=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *.lua)
            PARAM_FILE="$arg"
            ;;
        *)
            echo "Error: Unknown argument '$arg'"
            echo "Usage: $0 [--dry-run] <parameter_file.lua>"
            exit 1
            ;;
    esac
done

# Check if parameter file argument is provided
if [ -z "$PARAM_FILE" ]; then
    echo "Usage: $0 [--dry-run] <parameter_file.lua>"
    exit 1
fi

# Test if parameter file exists
if [ ! -f "$PARAM_FILE" ]; then
    echo "Error: Parameter file '$PARAM_FILE' does not exist"
    exit 1
fi

# Get directory of parameter file
PARAM_DIR=$(dirname "$PARAM_FILE")
NBODY_EXEC="$PARAM_DIR/nbody"

# Test if nbody executable exists
if [ ! -f "$NBODY_EXEC" ]; then
    echo "Error: nbody executable not found at '$NBODY_EXEC'"
    exit 1
fi

# Get absolute path of parameter file for use inside SLURM
ABS_PARAM_FILE=$(realpath "$PARAM_FILE")

# Extract output folder from lua parameter file
extract_output_folder() {
    local param_file="$1"
    # This now uses the 'lua' from your env_setup.sh (system or ~/local)
    local output_folder=$(lua -e "
        local param_file = '$param_file'
        dofile(param_file)
        if output_folder and output_folder ~= '' then
            print(output_folder)
        else
            print('.')
        end
    " 2>/dev/null)
    echo "$output_folder"
}

echo "Extracting output directory from parameter file..."
OUTPUT_DIR=$(extract_output_folder "$ABS_PARAM_FILE")

# Handle empty/missing output_folder
if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" = "." ]; then
    OUTPUT_DIR=$(dirname "$ABS_PARAM_FILE")
fi

# Create output directory
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
else
    echo "Using existing output directory: $OUTPUT_DIR"
fi

# Run boltzman solver
BOLTZMAN_SCRIPT="$SUBMIT_DIR/run_boltzman_solver.sh"
if [ ! -x "$BOLTZMAN_SCRIPT" ]; then
    echo "Error: '$BOLTZMAN_SCRIPT' not found or not executable"
    exit 1
fi

echo "Running boltzman solver..."
# WARNING: If this script needs Python, ensure env_setup.sh loads python/numpy too!
if ! "$BOLTZMAN_SCRIPT" "$ABS_PARAM_FILE"; then
    echo "Error: Boltzman solver failed"
    exit 1
fi
echo "Boltzman solver completed successfully"

# Submit SLURM job
if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode: Skipping sbatch submission"
else
    echo "Submitting SLURM job..."

    # ---------------------------------------------------------
    # CHANGE 2: Updated SBATCH Heredoc
    # Removed Conda, added env_setup.sh, used srun
    # ---------------------------------------------------------
    sbatch << EOF
#!/bin/bash
#SBATCH --job-name=cola
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=02:00:00
#SBATCH --mem=4G
#SBATCH --output=cola_%j.out
#SBATCH --error=cola_%j.err

# 1. Clean and Load Environment
module purge
source $SUBMIT_DIR/env_setup.sh

echo "Running on host: \$(hostname)"
echo "Loaded modules: \$(module list 2>&1)"

# 2. Paths
export OUTPUT="$OUTPUT_DIR"

# 3. Execution
# Use 'srun' to launch the MPI executable properly
srun "$NBODY_EXEC" "$ABS_PARAM_FILE"
EOF

    if [ $? -eq 0 ]; then
        echo "Job submitted successfully"
    else
        echo "Job submission failed"
    fi
fi
