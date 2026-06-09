#!/bin/bash
set -euo pipefail

# Directory containing all sample subdirectories
BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"

# Create a shared temporary directory in the working directory
SHARED_TMP="${BASE_DIR}/fastk_tmp"
mkdir -p "$SHARED_TMP"

echo "Resuming FastK processing..."
echo "Using shared temporary directory: $SHARED_TMP"
echo "Available disk space:"
df -h "$BASE_DIR"

# Export the custom temp directory
export TMPDIR="$SHARED_TMP"
export TEMP="$SHARED_TMP"
export TMP="$SHARED_TMP"

# List of samples in the order they should be processed
SAMPLES=(cinn6092 cinn7433 cinn7474 cinn7495 cinn7505 cinn7551 cinn7663 cinn7801 cinn7820)

for SAMPLE_NAME in "${SAMPLES[@]}"; do
    SAMPLE_DIR="$BASE_DIR/$SAMPLE_NAME"
    READ_FILE="${SAMPLE_DIR}/reads.fastq.gz"

    if [[ ! -d "$SAMPLE_DIR" ]]; then
        echo "⚠️  Sample directory $SAMPLE_NAME not found, skipping..."
        continue
    fi

    # Check if already completed
    if [[ -d "$SAMPLE_DIR/FastK_Table" ]] && [[ -f "$SAMPLE_DIR/FastK_Table/${SAMPLE_NAME}.ktab" ]]; then
        echo "✅ $SAMPLE_NAME already completed, skipping..."
        continue
    fi

    if [[ -f "$READ_FILE" ]]; then
        echo "🔄 Processing $SAMPLE_NAME"
        echo "File size: $(du -h "$READ_FILE" | cut -f1)"
        echo "Available temp space: $(df -h "$SHARED_TMP" | tail -1 | awk '{print $4}')"

        # Change to sample directory
        cd "$SAMPLE_DIR"
        
        # Clean any existing partial FastK files
        rm -f "${SAMPLE_NAME}".* 2>/dev/null || true
        rm -rf FastK_Table 2>/dev/null || true
        
        # Run FastK with very conservative settings for large files
        echo "Running FastK for $SAMPLE_NAME..."
        if FastK -k31 -v -T1 -M2 -N"$SAMPLE_NAME" "$READ_FILE"; then
            # Create FastK_Table directory and move files
            mkdir -p FastK_Table
            
            # Move all FastK output files
            moved_files=0
            for file in "${SAMPLE_NAME}".*; do
                if [[ -f "$file" ]]; then
                    mv "$file" FastK_Table/
                    echo "Moved $file to FastK_Table/"
                    ((moved_files++))
                fi
            done
            
            if [[ $moved_files -gt 0 ]]; then
                echo "✅ Completed $SAMPLE_NAME successfully"
                echo "Output files in FastK_Table/:"
                ls -la FastK_Table/
            else
                echo "❌ No output files generated for $SAMPLE_NAME"
            fi
        else
            echo "❌ FastK failed for $SAMPLE_NAME"
            # Clean up any partial files
            rm -f "${SAMPLE_NAME}".* 2>/dev/null || true
        fi
        
        # Clean temporary files for this sample
        find "$SHARED_TMP" -name "*${SAMPLE_NAME}*" -delete 2>/dev/null || true
        
        echo ""
    else
        echo "⚠️  No reads.fastq.gz found for $SAMPLE_NAME"
    fi
done

# Clean up shared temporary directory
echo "Cleaning up shared temporary directory..."
rm -rf "$SHARED_TMP"

echo ""
echo "Processing summary:"
for SAMPLE_NAME in "${SAMPLES[@]}"; do
    SAMPLE_DIR="$BASE_DIR/$SAMPLE_NAME"
    if [[ -d "$SAMPLE_DIR/FastK_Table" ]] && [[ -f "$SAMPLE_DIR/FastK_Table/${SAMPLE_NAME}.ktab" ]]; then
        echo "✅ $SAMPLE_NAME: COMPLETED"
    else
        echo "❌ $SAMPLE_NAME: FAILED or INCOMPLETE"
    fi
done