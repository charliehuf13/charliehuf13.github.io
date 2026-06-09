#!/bin/bash
set -euo pipefail

# Function to run smudgeplot for a single sample
run_smudgeplot_sample() {
    local SAMPLE_DIR="$1"
    local SAMPLE_NAME=$(basename "$SAMPLE_DIR")
    
    echo "🔬 Running smudgeplot for $SAMPLE_NAME"
    
    # Check if FastK output exists
    if [[ ! -d "$SAMPLE_DIR/FastK_Table" ]]; then
        echo "❌ No FastK_Table directory found for $SAMPLE_NAME"
        return 1
    fi
    
    local KTAB_FILE="$SAMPLE_DIR/FastK_Table/${SAMPLE_NAME}.ktab"
    local HIST_FILE="$SAMPLE_DIR/FastK_Table/${SAMPLE_NAME}.hist"
    
    if [[ ! -f "$KTAB_FILE" ]]; then
        echo "❌ No .ktab file found for $SAMPLE_NAME"
        return 1
    fi
    
    if [[ ! -f "$HIST_FILE" ]]; then
        echo "❌ No .hist file found for $SAMPLE_NAME"
        return 1
    fi
    
    # Change to sample directory
    cd "$SAMPLE_DIR"
    
    # Create output directories
    mkdir -p kmerpairs plots
    
    echo "Step 1: Generating heterozygous k-mer pairs..."
    # Step 1: Generate smudgepairs
    if smudgeplot.py hetkmers -o "kmerpairs/${SAMPLE_NAME}_kmerpairs_text" -k "$KTAB_FILE"; then
        echo "✅ hetkmers completed for $SAMPLE_NAME"
    else
        echo "❌ hetkmers failed for $SAMPLE_NAME"
        return 1
    fi
    
    echo "Step 2: Generating smudgeplot..."
    # Step 2: Generate plots
    local SMU_FILE="kmerpairs/${SAMPLE_NAME}_kmerpairs_text.smu"
    if [[ -f "$SMU_FILE" ]]; then
        if smudgeplot.py plot -i "$SMU_FILE" -o "plots/${SAMPLE_NAME}_plot_smudgeplot" --hist "$HIST_FILE"; then
            echo "✅ plot completed for $SAMPLE_NAME"
            
            # List generated files
            echo "Generated files:"
            ls -la plots/
            
            # Show a summary if the summary file exists
            local SUMMARY_FILE="plots/${SAMPLE_NAME}_plot_smudgeplot_summary.txt"
            if [[ -f "$SUMMARY_FILE" ]]; then
                echo "Summary for $SAMPLE_NAME:"
                cat "$SUMMARY_FILE"
            fi
        else
            echo "❌ plot failed for $SAMPLE_NAME"
            return 1
        fi
    else
        echo "❌ .smu file not found: $SMU_FILE"
        return 1
    fi
    
    echo "✅ Smudgeplot completed successfully for $SAMPLE_NAME"
    return 0
}

# Main script
BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"

echo "Starting smudgeplot analysis..."
echo "Base directory: $BASE_DIR"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "❌ Base directory not found: $BASE_DIR"
    exit 1
fi

# Process all samples or a specific sample if provided as argument
if [[ $# -eq 1 ]]; then
    # Single sample mode
    SAMPLE_NAME="$1"
    SAMPLE_DIR="$BASE_DIR/$SAMPLE_NAME"
    if [[ -d "$SAMPLE_DIR" ]]; then
        run_smudgeplot_sample "$SAMPLE_DIR"
    else
        echo "❌ Sample directory not found: $SAMPLE_DIR"
        exit 1
    fi
else
    # Process all samples
    success_count=0
    total_count=0
    
    for SAMPLE_DIR in "$BASE_DIR"/cinn*/; do
        if [[ -d "$SAMPLE_DIR" ]]; then
            SAMPLE_NAME=$(basename "$SAMPLE_DIR")
            ((total_count++))
            
            echo ""
            echo "=== Processing $SAMPLE_NAME ($total_count) ==="
            
            if run_smudgeplot_sample "$SAMPLE_DIR"; then
                ((success_count++))
            fi
        fi
    done
    
    echo ""
    echo "=== Summary ==="
    echo "Successfully processed: $success_count/$total_count samples"
    
    # Show which samples completed successfully
    echo ""
    echo "Completed samples:"
    for SAMPLE_DIR in "$BASE_DIR"/cinn*/; do
        if [[ -d "$SAMPLE_DIR" ]]; then
            SAMPLE_NAME=$(basename "$SAMPLE_DIR")
            if [[ -d "$SAMPLE_DIR/plots" ]] && [[ -f "$SAMPLE_DIR/plots/${SAMPLE_NAME}_plot_smudgeplot.pdf" ]]; then
                echo "✅ $SAMPLE_NAME"
            else
                echo "❌ $SAMPLE_NAME"
            fi
        fi
    done
fi