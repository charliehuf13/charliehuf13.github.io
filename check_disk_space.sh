#!/bin/bash

echo "=== Disk Space Analysis ==="
echo ""

BASE_DIR="/nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads"

echo "1. Current /tmp directory:"
df -h /tmp 2>/dev/null || echo "   /tmp not accessible"

echo ""
echo "2. Working directory ($BASE_DIR):"
df -h "$BASE_DIR" 2>/dev/null || echo "   Working directory not accessible"

echo ""
echo "3. Home directory:"
df -h ~ 2>/dev/null || echo "   Home directory not accessible"

echo ""
echo "4. Root filesystem:"
df -h / 

echo ""
echo "5. All mounted filesystems:"
df -h | grep -E "(Filesystem|/dev/|tmpfs)" | head -10

echo ""
echo "=== Sample File Sizes ==="
if [[ -d "$BASE_DIR" ]]; then
    for sample_dir in "$BASE_DIR"/cinn*/; do
        if [[ -d "$sample_dir" ]]; then
            sample_name=$(basename "$sample_dir")
            read_file="$sample_dir/reads.fastq.gz"
            if [[ -f "$read_file" ]]; then
                size=$(du -h "$read_file" | cut -f1)
                echo "$sample_name: $size"
            fi
        fi
    done
else
    echo "Base directory not found: $BASE_DIR"
fi

echo ""
echo "=== Recommendations ==="
echo "FastK typically needs 2-3x the input file size in temporary space."
echo "For large files (>5GB), consider:"
echo "1. Using a directory with >50GB free space for TMPDIR"
echo "2. Using -M2 or -M4 flag to limit memory usage"
echo "3. Processing samples one at a time"
echo "4. Using -T1 for single-threaded processing"

echo ""
echo "=== Suggested Commands ==="
echo "To use working directory as temp:"
echo "export TMPDIR=\"$BASE_DIR/fastk_tmp\""
echo ""
echo "To use home directory as temp:"
echo "export TMPDIR=\"~/fastk_tmp\""
echo ""
echo "To check what's using space in /tmp:"
echo "sudo du -sh /tmp/* 2>/dev/null | sort -hr | head -10"