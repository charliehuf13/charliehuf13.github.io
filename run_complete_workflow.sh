#!/bin/bash
set -euo pipefail

# Configuration
BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"
SHARED_TMP="${BASE_DIR}/fastk_tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check conda environment
    if [[ "$CONDA_DEFAULT_ENV" != "smudgeplot_env" ]]; then
        error "Please activate the smudgeplot_env conda environment first:"
        echo "conda activate smudgeplot_env"
        exit 1
    fi
    
    # Check if FastK is available
    if ! command -v FastK &> /dev/null; then
        error "FastK not found. Please install it in the conda environment."
        exit 1
    fi
    
    # Check if smudgeplot is available
    if ! command -v smudgeplot.py &> /dev/null; then
        error "smudgeplot.py not found. Please install it in the conda environment."
        exit 1
    fi
    
    # Check base directory
    if [[ ! -d "$BASE_DIR" ]]; then
        error "Base directory not found: $BASE_DIR"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Function to check disk space
check_disk_space() {
    log "Checking disk space..."
    
    # Check available space in base directory
    local available_space=$(df "$BASE_DIR" | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    log "Available space in working directory: ${available_gb}GB"
    
    if [[ $available_gb -lt 50 ]]; then
        warning "Low disk space detected (${available_gb}GB). FastK may fail for large files."
        echo "Consider freeing up space or using a different temporary directory."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to run FastK for a single sample
run_fastk_sample() {
    local sample_name="$1"
    local sample_dir="$BASE_DIR/$sample_name"
    local read_file="$sample_dir/reads.fastq.gz"
    
    log "Processing FastK for $sample_name"
    
    # Check if already completed
    if [[ -d "$sample_dir/FastK_Table" ]] && [[ -f "$sample_dir/FastK_Table/${sample_name}.ktab" ]]; then
        success "$sample_name FastK already completed, skipping..."
        return 0
    fi
    
    if [[ ! -f "$read_file" ]]; then
        error "Read file not found: $read_file"
        return 1
    fi
    
    # Show file size
    local file_size=$(du -h "$read_file" | cut -f1)
    log "File size: $file_size"
    
    # Change to sample directory
    cd "$sample_dir"
    
    # Clean any existing partial files
    rm -f "${sample_name}".* 2>/dev/null || true
    rm -rf FastK_Table 2>/dev/null || true
    
    # Run FastK with conservative settings
    log "Running FastK..."
    if FastK -k31 -v -T1 -M2 -N"$sample_name" "$read_file"; then
        # Create FastK_Table directory and move files
        mkdir -p FastK_Table
        
        # Move all FastK output files
        local moved_files=0
        for file in "${sample_name}".*; do
            if [[ -f "$file" ]]; then
                mv "$file" FastK_Table/
                ((moved_files++))
            fi
        done
        
        if [[ $moved_files -gt 0 ]]; then
            success "FastK completed for $sample_name"
            return 0
        else
            error "No FastK output files generated for $sample_name"
            return 1
        fi
    else
        error "FastK failed for $sample_name"
        return 1
    fi
}

# Function to run smudgeplot for a single sample
run_smudgeplot_sample() {
    local sample_name="$1"
    local sample_dir="$BASE_DIR/$sample_name"
    
    log "Processing smudgeplot for $sample_name"
    
    # Check if FastK output exists
    if [[ ! -f "$sample_dir/FastK_Table/${sample_name}.ktab" ]]; then
        error "FastK output not found for $sample_name"
        return 1
    fi
    
    # Check if already completed
    if [[ -f "$sample_dir/plots/${sample_name}_plot_smudgeplot.pdf" ]]; then
        success "$sample_name smudgeplot already completed, skipping..."
        return 0
    fi
    
    # Change to sample directory
    cd "$sample_dir"
    
    # Create output directories
    mkdir -p kmerpairs plots
    
    # Step 1: Generate heterozygous k-mer pairs
    log "Generating heterozygous k-mer pairs..."
    if smudgeplot.py hetkmers -o "kmerpairs/${sample_name}_kmerpairs_text" -k "FastK_Table/${sample_name}.ktab"; then
        success "hetkmers completed for $sample_name"
    else
        error "hetkmers failed for $sample_name"
        return 1
    fi
    
    # Step 2: Generate plots
    log "Generating smudgeplot..."
    local smu_file="kmerpairs/${sample_name}_kmerpairs_text.smu"
    if [[ -f "$smu_file" ]]; then
        if smudgeplot.py plot -i "$smu_file" -o "plots/${sample_name}_plot_smudgeplot" --hist "FastK_Table/${sample_name}.hist"; then
            success "smudgeplot completed for $sample_name"
            
            # Show summary if available
            local summary_file="plots/${sample_name}_plot_smudgeplot_summary.txt"
            if [[ -f "$summary_file" ]]; then
                log "Summary for $sample_name:"
                cat "$summary_file"
            fi
            return 0
        else
            error "smudgeplot plot failed for $sample_name"
            return 1
        fi
    else
        error ".smu file not found: $smu_file"
        return 1
    fi
}

# Main workflow
main() {
    log "Starting complete smudgeplot workflow"
    
    # Check prerequisites
    check_prerequisites
    check_disk_space
    
    # Set up temporary directory
    mkdir -p "$SHARED_TMP"
    export TMPDIR="$SHARED_TMP"
    export TEMP="$SHARED_TMP"
    export TMP="$SHARED_TMP"
    
    log "Using temporary directory: $SHARED_TMP"
    
    # List of samples
    local samples=(cinn6092 cinn7433 cinn7474 cinn7495 cinn7505 cinn7551 cinn7663 cinn7801 cinn7820)
    
    local fastk_success=0
    local smudgeplot_success=0
    local total_samples=${#samples[@]}
    
    log "Processing $total_samples samples"
    
    # Process each sample
    for sample_name in "${samples[@]}"; do
        echo ""
        log "=== Processing $sample_name ==="
        
        # Run FastK
        if run_fastk_sample "$sample_name"; then
            ((fastk_success++))
            
            # Run smudgeplot
            if run_smudgeplot_sample "$sample_name"; then
                ((smudgeplot_success++))
            fi
        fi
        
        # Clean temporary files for this sample
        find "$SHARED_TMP" -name "*${sample_name}*" -delete 2>/dev/null || true
    done
    
    # Clean up shared temporary directory
    log "Cleaning up temporary directory..."
    rm -rf "$SHARED_TMP"
    
    # Final summary
    echo ""
    log "=== FINAL SUMMARY ==="
    success "FastK completed: $fastk_success/$total_samples samples"
    success "Smudgeplot completed: $smudgeplot_success/$total_samples samples"
    
    echo ""
    log "Sample status:"
    for sample_name in "${samples[@]}"; do
        local sample_dir="$BASE_DIR/$sample_name"
        local fastk_status="❌"
        local smudgeplot_status="❌"
        
        if [[ -f "$sample_dir/FastK_Table/${sample_name}.ktab" ]]; then
            fastk_status="✅"
        fi
        
        if [[ -f "$sample_dir/plots/${sample_name}_plot_smudgeplot.pdf" ]]; then
            smudgeplot_status="✅"
        fi
        
        echo "$sample_name: FastK $fastk_status, Smudgeplot $smudgeplot_status"
    done
    
    if [[ $smudgeplot_success -eq $total_samples ]]; then
        success "All samples completed successfully!"
    else
        warning "Some samples failed. Check the logs above for details."
    fi
}

# Run main function
main "$@"