#!/bin/bash
set -euo pipefail

# Directory containing all sample subdirectories
BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"

# Check available disk space
echo "Checking disk space..."
df -h "$BASE_DIR"

# loop over subdirs
for SAMPLE_DIR in "$BASE_DIR"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_DIR")
    READ_FILE="${SAMPLE_DIR}/reads.fastq.gz"

    if [[ -f "$READ_FILE" ]]; then
        echo "✅ Processing $SAMPLE_NAME"

        # Set up custom temp directory in the sample directory (where there's more space)
        export TMPDIR="${SAMPLE_DIR}/tmp"
        mkdir -p "$TMPDIR"
        
        # Also set FASTK_TEMP_DIR if supported
        export FASTK_TEMP_DIR="$TMPDIR"
        
        echo "Using temporary directory: $TMPDIR"
        echo "Available space in temp dir:"
        df -h "$TMPDIR"

        # Change to sample directory
        cd "$SAMPLE_DIR"
        
        # Run FastK with explicit output prefix and reduced memory usage
        # Use -M option to limit memory usage and -T1 for single thread to be safer
        FastK -k31 -v -T1 -M8 -N"$SAMPLE_NAME" "$READ_FILE"
        
        # Move the output files to FastK_Table subdirectory
        mkdir -p FastK_Table
        mv "${SAMPLE_NAME}".* FastK_Table/ 2>/dev/null || true
        
        # Clean up temp files
        echo "Cleaning up temporary files..."
        rm -rf "$TMPDIR"
        
        echo "✅ Completed $SAMPLE_NAME"
        echo ""
    else
        echo "⚠️  Skipping $SAMPLE_NAME — no reads.fastq.gz found"
    fi
done

echo "All samples processed!"