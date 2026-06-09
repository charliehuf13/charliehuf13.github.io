#!/bin/bash
set -euo pipefail

# Directory containing all sample subdirectories
BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"

# Create a shared temporary directory in the working directory (where there's more space)
SHARED_TMP="${BASE_DIR}/fastk_tmp"
mkdir -p "$SHARED_TMP"

echo "Using shared temporary directory: $SHARED_TMP"
echo "Available disk space:"
df -h "$BASE_DIR"

# Export the custom temp directory
export TMPDIR="$SHARED_TMP"
export TEMP="$SHARED_TMP"
export TMP="$SHARED_TMP"

# loop over subdirs
for SAMPLE_DIR in "$BASE_DIR"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_DIR")
    READ_FILE="${SAMPLE_DIR}/reads.fastq.gz"

    # Skip if not a sample directory
    if [[ "$SAMPLE_NAME" == "fastk_tmp" ]]; then
        continue
    fi

    if [[ -f "$READ_FILE" ]]; then
        echo "✅ Processing $SAMPLE_NAME"
        echo "File size: $(du -h "$READ_FILE" | cut -f1)"

        # Change to sample directory
        cd "$SAMPLE_DIR"
        
        # Clean any existing FastK files first
        rm -f "${SAMPLE_NAME}".* 2>/dev/null || true
        
        # Run FastK with conservative settings
        # -k31: 31-mer size
        # -v: verbose
        # -T1: single thread (safer for memory)
        # -M4: limit memory to 4GB
        # -N: output prefix
        echo "Running FastK for $SAMPLE_NAME..."
        FastK -k31 -v -T1 -M4 -N"$SAMPLE_NAME" "$READ_FILE"
        
        # Create FastK_Table directory and move files
        mkdir -p FastK_Table
        
        # Move all FastK output files
        for file in "${SAMPLE_NAME}".*; do
            if [[ -f "$file" ]]; then
                mv "$file" FastK_Table/
                echo "Moved $file to FastK_Table/"
            fi
        done
        
        # Clean temporary files for this sample
        find "$SHARED_TMP" -name "*${SAMPLE_NAME}*" -delete 2>/dev/null || true
        
        echo "✅ Completed $SAMPLE_NAME"
        echo "Output files in FastK_Table/:"
        ls -la FastK_Table/
        echo ""
    else
        echo "⚠️  Skipping $SAMPLE_NAME — no reads.fastq.gz found"
    fi
done

# Clean up shared temporary directory
echo "Cleaning up shared temporary directory..."
rm -rf "$SHARED_TMP"

echo "All samples processed!"
echo "Final directory structure:"
for SAMPLE_DIR in "$BASE_DIR"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_DIR")
    if [[ "$SAMPLE_NAME" != "fastk_tmp" && -d "$SAMPLE_DIR/FastK_Table" ]]; then
        echo "$SAMPLE_NAME/FastK_Table/:"
        ls -la "$SAMPLE_DIR/FastK_Table/" | head -3
    fi
done