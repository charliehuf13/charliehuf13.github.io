# Fixed FastK Scripts for Smudgeplot Analysis

## Problem Solved

The original FastK run was failing with the error:
```
FastK: Cannot write to /tmp/reads.12.T0.  Enough disk space?
```

This happens because FastK uses `/tmp` for temporary files, and `/tmp` often has limited space on cluster systems.

## Solution

The updated scripts solve this by:

1. **Using a custom temporary directory** in your working directory where there's more space
2. **Reducing memory usage** with conservative FastK settings
3. **Processing samples one at a time** to avoid overwhelming the system
4. **Automatic cleanup** of temporary files after each sample

## Updated Scripts

### 1. `check_disk_space.sh`
**Purpose**: Check available disk space and get recommendations
**Usage**: 
```bash
chmod +x check_disk_space.sh
./check_disk_space.sh
```

### 2. `resume_fastk.sh`
**Purpose**: Resume FastK processing from where it failed, skipping completed samples
**Usage**:
```bash
chmod +x resume_fastk.sh
./resume_fastk.sh
```

### 3. `run_all_fastk_with_custom_tmp.sh`
**Purpose**: Run FastK on all samples with custom temporary directory
**Usage**:
```bash
chmod +x run_all_fastk_with_custom_tmp.sh
./run_all_fastk_with_custom_tmp.sh
```

### 4. `run_smudgeplot_updated.sh`
**Purpose**: Run smudgeplot analysis on samples that completed FastK
**Usage**:
```bash
chmod +x run_smudgeplot_updated.sh
# Run on all samples:
./run_smudgeplot_updated.sh
# Or run on a specific sample:
./run_smudgeplot_updated.sh cinn6092
```

### 5. `run_complete_workflow.sh` (RECOMMENDED)
**Purpose**: Complete workflow with error checking and progress tracking
**Usage**:
```bash
chmod +x run_complete_workflow.sh
./run_complete_workflow.sh
```

## Quick Start (Recommended Approach)

1. **Activate your conda environment**:
```bash
conda activate smudgeplot_env
```

2. **Navigate to your working directory**:
```bash
cd /nfs7/BPP/Chang_Lab/phytophthora_project/02_cleaned_reads/clade_07/hifiasm/smudgeplot_rawreads
```

3. **Check disk space** (optional but recommended):
```bash
./check_disk_space.sh
```

4. **Run the complete workflow**:
```bash
./run_complete_workflow.sh
```

## What Changed

### FastK Settings
- **Memory limit**: `-M2` (2GB instead of default 8GB)
- **Single thread**: `-T1` (safer for large files)
- **Custom temp directory**: Uses `$BASE_DIR/fastk_tmp` instead of `/tmp`

### Directory Structure
The scripts maintain your desired structure:
```
smudgeplot_rawreads/
├── cinn6092/
│   ├── reads.fastq.gz (symlink)
│   ├── FastK_Table/
│   │   ├── cinn6092.ktab
│   │   └── cinn6092.hist
│   ├── kmerpairs/
│   │   └── cinn6092_kmerpairs_text.smu
│   └── plots/
│       ├── cinn6092_plot_smudgeplot.pdf
│       └── cinn6092_plot_smudgeplot_log10.pdf
├── cinn7433/
│   └── ...
└── fastk_tmp/ (temporary, cleaned up automatically)
```

## Troubleshooting

### If FastK still fails with disk space errors:
1. Check available space: `df -h .`
2. Try using your home directory as temp: `export TMPDIR=~/fastk_tmp`
3. Process samples individually using the single-sample mode

### If a sample fails:
1. Check the specific error message
2. Verify the input file exists and isn't corrupted
3. Try running just that sample: `./run_smudgeplot_updated.sh cinn6092`

### Current Status Check:
You can check which samples have completed by looking for these files:
- FastK completed: `cinn*/FastK_Table/cinn*.ktab`
- Smudgeplot completed: `cinn*/plots/cinn*_plot_smudgeplot.pdf`

## Resume from Current State

Since you already have some samples completed (cinn6092, cinn7433, cinn7474), you can resume with:

```bash
./resume_fastk.sh
```

This will skip the completed samples and continue with cinn7495 where it failed.

## Key Improvements

1. **Automatic temp directory management** - no more `/tmp` issues
2. **Progress tracking** - see which samples are completed
3. **Error recovery** - resume from failures
4. **Resource conservation** - reduced memory usage
5. **Clean output** - organized directory structure maintained