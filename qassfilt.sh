#!/usr/bin/env bash
source ~/miniconda3/etc/profile.d/conda.sh
set -euo pipefail
#All rights reserved. © 2025 QAssfilt, Samrach Han
# =========================
# CONFIGURATION WITH DEFAULTS
# =========================
INPUT_PATH=""
OUTPUT_PATH=""
INPUT_DIR_DEPTH=1
SPADES_THREADS=32
FASTP_THREADS=16
CHECKM2_THREADS=16
QUAST_REFERENCE=""
QUAST_THREADS=16
KRAKEN2_THREADS=16
GTDBTK_THREADS=16
SEQKIT_MIN_COV=10
SEQKIT_MIN_LENGTH=500
SKIP_STEPS=()
CONTIG_MODE=0
INIT_MODE=0
VERSION_QAssfilt=1.2
KRAKEN2_DB_PATH="0"
GTDBTK_DB_PATH="0"
CHECKM2DB_PATH=""
CONTIGS_REMOVE=

# Free-form options
FASTP_EXTRA_OPTS=""
SPADES_EXTRA_OPTS=""
ABRITAMR_EXTRA_OPTS=""
ABRICATE_EXTRA_OPTS=""
RUN_ABRITAMR=0
RUN_ABRICATE=0

# =========================
# START TIMER
# =========================
START_TIME=$(date +%s)

# =========================
# PARSE COMMAND LINE ARGUMENTS
# =========================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --INITIAL|-ini) INIT_MODE="1"; shift  ;;
        --INPUT_PATH|-i) INPUT_PATH="$2"; shift 2 ;;
        --CONTIGS|-cg) CONTIG_MODE="1"; shift  ;;
        --OUTPUT_PATH|-o) OUTPUT_PATH="$2"; shift 2 ;;
        --INPUT_DIR_DEPTH|-id) INPUT_DIR_DEPTH="$2"; shift 2 ;;
        --CHECKM2DB_PATH|-d) CHECKM2DB_PATH="$2"; shift 2 ;;
        --KRAKEN2_DB_PATH|-kd) KRAKEN2_DB_PATH="$2"; shift 2 ;;
        --GTDBTK_DB_PATH|-gd) GTDBTK_DB_PATH="$2"; shift 2 ;;
        --SPADES_THREADS|-st) SPADES_THREADS="$2"; shift 2 ;;
        --FASTP_THREADS|-ft) FASTP_THREADS="$2"; shift 2 ;;
        --CHECKM2_THREADS|-ct) CHECKM2_THREADS="$2"; shift 2 ;;
        --QUAST_THREADS|-qt) QUAST_THREADS="$2"; shift 2 ;;
        --KRAKEN2_THREADS|-kt) KRAKEN2_THREADS="$2"; shift 2 ;;
        --GTDBTK_THREADS|-gt) GTDBTK_THREADS="$2"; shift 2 ;;
        --QUAST_REFERENCE|-qr) QUAST_REFERENCE="$2"; shift 2 ;;
        --SEQKIT_MIN_COV|-mc) SEQKIT_MIN_COV="$2"; shift 2 ;;
        --SEQKIT_MIN_LENGTH|-ml) SEQKIT_MIN_LENGTH="$2"; shift 2 ;;
        --skip) SKIP_STEPS="$2"; shift 2 ;;
        --fastp) FASTP_EXTRA_OPTS="$2"; shift 2 ;;
        --spades) SPADES_EXTRA_OPTS="$2"; shift 2 ;;
        --abricate) ABRICATE_EXTRA_OPTS="$2"; RUN_ABRICATE=1; shift 2 ;;
        --abritamr) ABRITAMR_EXTRA_OPTS="$2"; RUN_ABRITAMR=1; shift 2 ;;
        --contigs_remove|-cr) CONTIGS_REMOVE="$2"; shift 2 ;;
        --version|-v)
    echo "QAssfilt Pipeline version ${VERSION_QAssfilt}"
    exit 0
    ;;
        -h|--help)
            echo ""
            echo "Usage: qassfilt -i ~/dir -o ~/dir [options]"
            echo ""
            echo "  --INITIAL, -ini            		Initiallize QAssfilt, including checking and installing environments and tools (obligated for the first time)"
            echo "  --INPUT_PATH, -i [DIR]          	Path to directory containing fastq file (Apply for all Illumina paired end reads)"
            echo "  --CONTIGS, -cg            		Enable contig mode (flag option)"
            echo "                             		This will scan for fasta (.fa .fasta .fas .fna) in INPUT_PATH"
            echo "  --OUTPUT_PATH, -o [DIR]         	Path to output directory"
            echo "  --INPUT_DIR_DEPTH, -id [INT]    	Define directories to be scanned for fastq file (default: $INPUT_DIR_DEPTH)"
            echo "                             		e.g.: -id 1 will scan for only file in INPUT_PATH directory"
            echo "                             		e.g.: -id 2 will scan all file in INPUT_PATH subdirectories"
            echo "  --CHECKM2DB_PATH, -d [DIR]      	Path to CheckM2 database directory (optional; if not given, pipeline will auto-manage)"
            echo "  --KRAKEN2_DB_PATH, -kd [DIR]      	Path to KRAKEN2 database directory (enables kraken2 step)"
            echo "  --GTDBTK_DB_PATH, -gd [DIR]      	Path to GTDBTK database directory (enables gtdbtk step)"
            echo "  --SPADES_THREADS, -st [INT]     	Threads for spades (default: $SPADES_THREADS)"
            echo "  --FASTP_THREADS, -ft [INT]      	Threads for fastp (default: $FASTP_THREADS)"
            echo "  --CHECKM2_THREADS, -ct [INT]    	Threads for CheckM2 (default: $CHECKM2_THREADS)"
            echo "  --QUAST_THREADS, -qt [INT]      	Threads for QUAST (default: $QUAST_THREADS)"
            echo "  --KRAKEN2_THREADS, -kt [INT]      	Threads for KRAKEN2 (default: $KRAKEN2_THREADS)"
            echo "  --GTDBTK_THREADS, -gt [INT]      	Threads for GTDBTK (default: $GTDBTK_THREADS)"
            echo "  --QUAST_REFERENCE, -qr [FILE]   	Path to reference sequence for QUAST (optional)"
            echo "  --SEQKIT_MIN_COV, -mc [INT]     	Minimum (≤) contig coverage to be filtered (default: $SEQKIT_MIN_COV)"
            echo "  --SEQKIT_MIN_LENGTH, -ml [INT]  	Minimum (≤) contig length to be filtered (default: $SEQKIT_MIN_LENGTH)"
            echo "  --skip [LIST]                 	Skip tool(s) you don't want to use in the pipeline (space-separated)"
            echo "                             		e.g.: --skip \"FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a"
            echo "                             		\"ABRITAMR-b ABRITAMR-a ABRICATE-b ABRICATE-a MULTIQC\""
            echo "  --contigs_remove, -cr [FILE]   	Path to file containing contigs to remove."
            echo "                             		Create a tab file with path to fasta format at column 1 and the contig name at column 2(separated by comma for multiple names)."
            echo "  --fastp [STRING]                	Options/parameters to pass directly to fastp"
            echo "                             		e.g.: \"-q 30 -u 30 -e 15 -l 50 -5 -3, ...\""
            echo "  --spades [STRING]               	Options/parameters to pass directly to SPAdes"
            echo "                             		e.g.: \"--isolate --careful --cov-cutoff auto, ...\""
            echo "  --abricate [STRING]             	Options/parameters to pass directly to abricate except --db (enables abricate step)"
            echo "                             		e.g.: \"--minid 80, --mincov 80,...\""
            echo "  --abritamr [STRING]             	Options/parameters to pass directly to abritamr (enables abritamr step)"
            echo "                             		e.g.: \"--species Escherichia, -j 16 ...\""

            echo "  --version, -v              		Check QAssfilt version"
            echo "  --help, -h                 		Show this help message and exit"
            echo ""
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# =========================
# Process --skip options
# =========================
process_skips() {
    local lower_skips=()
    for s in ${SKIP_STEPS[@]}; do
        lower_skips+=("$(echo "$s" | tr '[:upper:]' '[:lower:]')")
    done

    # Initialize required envs/tools
    REQUIRED_ENVS=(qassfilt_fastp qassfilt_spades qassfilt_quast qassfilt_checkm2 qassfilt_seqkit qassfilt_multiqc qassfilt_kraken2 qassfilt_gtdbtk qassfilt_abritamr qassfilt_abricate)
    REQUIRED_TOOLS=(fastp spades.py quast.py checkm2 seqkit multiqc kraken2 gtdbtk abritamr abricate)

    # Clear SKIP_STEPS; populate exactly from user input
    SKIP_STEPS=()

    local skip_checkm2_a=0
    local skip_checkm2_b=0
    local skip_quast_a=0
    local skip_quast_b=0
    local skip_kraken2_a=0
    local skip_kraken2_b=0
    local skip_gtdbtk_a=0
    local skip_gtdbtk_b=0
    local skip_abritamr_a=0
    local skip_abritamr_b=0
    local skip_abricate_a=0
    local skip_abricate_b=0

    # Loop through requested skips
    for s in "${lower_skips[@]}"; do
        case "$s" in
            fastp)
                SKIP_STEPS+=(FASTP)
                REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_fastp}")
                REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/fastp}")
                ;;
            spades)
                SKIP_STEPS+=(SPADES)
                REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_spades}")
                REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/spades.py}")
                ;;
            quast-a)
                SKIP_STEPS+=(QUAST-a)
                skip_quast_a=1
                ;;
            quast-b)
                SKIP_STEPS+=(QUAST-b)
                skip_quast_b=1
                ;;
            checkm2-a)
                SKIP_STEPS+=(CHECKM2-a)
                skip_checkm2_a=1
                ;;
            checkm2-b)
                SKIP_STEPS+=(CHECKM2-b)
                skip_checkm2_b=1
                ;;
            filter)
                SKIP_STEPS+=(FILTER)
                REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_seqkit}")
                REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/seqkit}")
                ;;
            multiqc)
                SKIP_STEPS+=(MULTIQC)
                REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_multiqc}")
                REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/multiqc}")
                ;;
            kraken2-a)
                SKIP_STEPS+=(KRAKEN2-a)
                skip_kraken2_a=1
                ;;
            kraken2-b)
                SKIP_STEPS+=(KRAKEN2-b)
                skip_kraken2_b=1
                ;;
            gtdbtk-a)
                SKIP_STEPS+=(GTDBTK-a)
                skip_gtdbtk_a=1
                ;;
            gtdbtk-b)
                SKIP_STEPS+=(GTDBTK-b)
                skip_gtdbtk_b=1
                ;;
            abritamr-a)
                SKIP_STEPS+=(ABRITAMR-a)
                skip_abritamr_a=1
                ;;
            abritamr-b)
                SKIP_STEPS+=(ABRITAMR-b)
                skip_abritamr_b=1
                ;;
            abricate-a)
                SKIP_STEPS+=(ABRICATE-a)
                skip_abricate_a=1
                ;;
            abricate-b)
                SKIP_STEPS+=(ABRICATE-b)
                skip_abricate_b=1
                ;;
            *)
                echo "[!] Warning: Unknown skip step '$s', ignoring."
                ;;
        esac
    done

    # Remove duplicates
    SKIP_STEPS=($(printf "%s\n" "${SKIP_STEPS[@]}" | sort -u))

    # Env/tool skipping for QUAST
    if [[ $skip_quast_a -eq 1 && $skip_quast_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_quast}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/quast.py}")
    fi

    # Env/tool skipping for CheckM2 only if BOTH skipped
    if [[ $skip_checkm2_a -eq 1 && $skip_checkm2_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_checkm2}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/checkm2}")
        CHECKM2DB_REQUIRED=false
    else
        CHECKM2DB_REQUIRED=true
    fi

    # Env/tool skipping for Kraken2 only if BOTH skipped
    if [[ $skip_kraken2_a -eq 1 && $skip_kraken2_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_kraken2}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/kraken2}")
    fi

    # Env/tool skipping for GTDBTK only if BOTH skipped
    if [[ $skip_gtdbtk_a -eq 1 && $skip_gtdbtk_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_gtdbtk}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/gtdbtk}")
    fi

    # Env/tool skipping for ABRITAMR only if BOTH skipped
    if [[ $skip_abritamr_a -eq 1 && $skip_abritamr_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_abritamr}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/abritamr}")
    fi

    # Env/tool skipping for ABRICATE only if BOTH skipped
    if [[ $skip_abricate_a -eq 1 && $skip_abricate_b -eq 1 ]]; then
        REQUIRED_ENVS=("${REQUIRED_ENVS[@]/qassfilt_abricate}")
        REQUIRED_TOOLS=("${REQUIRED_TOOLS[@]/abricate}")
    fi
}

mark_skipped_steps() {
    # Only mark explicitly skipped steps
    for step in "${SKIP_STEPS[@]}"; do
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "$step" "SKIPPED"
        done
    done
}

# =========================
# Validate / normalize output path and define STATUS_FILE
# =========================
OUTPUT_PATH="${OUTPUT_PATH:-.}"
mkdir -p "$OUTPUT_PATH"
STATUS_FILE="${OUTPUT_PATH}/pipeline_status.tsv"

# Now it's safe to set the trap
trap cleanup SIGINT

# =========================
# SKIP STEP HELPER
# =========================
is_skipped() {
    local step="$1"
    # Normalize to uppercase
    step=$(echo "$step" | tr '[:lower:]' '[:upper:]')
    for s in "${SKIP_STEPS[@]}"; do
        s_upper=$(echo "$s" | tr '[:lower:]' '[:upper:]')
        if [[ "$step" == "$s_upper" ]]; then
            return 0  # yes, skip
        fi
    done
    return 1  # not skipped
}
# Parameters recorded
PARAM_LOG="${OUTPUT_PATH}/pipeline_parameters.txt"

mkdir -p "$OUTPUT_PATH/logs"
timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

# =========================
# CHECK REQUIRED CONDA ENVIRONMENTS AND TOOL VERSIONS
# =========================

declare -A ENV_STEPS
ENV_STEPS=(
    [qassfilt_fastp]="FASTP"
    [qassfilt_spades]="SPADES"
    [qassfilt_quast]="QUAST-b QUAST-a"
    [qassfilt_checkm2]="CHECKM2-b CHECKM2-a"
    [qassfilt_seqkit]="FILTER"
    [qassfilt_abritamr]="ABRITAMR-b ABRITAMR-a"
    [qassfilt_abricate]="ABRICATE-b ABRICATE-a"
	[qassfilt_kraken2]="KRAKEN2-b KRAKEN2-a"
    [qassfilt_gtdbtk]="GTDBTK-b GTDBTK-a"
    [qassfilt_multiqc]="MULTIQC"
)

declare -A TOOLS
TOOLS=(
    [qassfilt_fastp]="fastp"
    [qassfilt_spades]="spades.py"
    [qassfilt_quast]="quast.py"
    [qassfilt_checkm2]="checkm2"
    [qassfilt_seqkit]="seqkit"
    [qassfilt_abritamr]="abritamr"
    [qassfilt_abricate]="abricate"
	[qassfilt_kraken2]="kraken2"
    [qassfilt_gtdbtk]="gtdbtk"
    [qassfilt_multiqc]="multiqc"
)

DEFAULT_CHECKM2DB="$HOME/databases/CheckM2_database/"

check_envs_and_tools() {
    echo ""
    echo "QAssfilting required conda environments and tool versions..."
    echo ""

    for ENV in "${!ENV_STEPS[@]}"; do
        # Skip this env if all its steps are in SKIP_STEPS
        SKIP_THIS_ENV=true
        for STEP in ${ENV_STEPS[$ENV]}; do
            if ! [[ " ${SKIP_STEPS[*]} " =~ "$STEP" ]]; then
                SKIP_THIS_ENV=false
                break
            fi
        done
        [[ "$SKIP_THIS_ENV" == true ]] && continue

        TOOL=${TOOLS[$ENV]}
        echo ""
        echo "Checking environment: $ENV (for steps: ${ENV_STEPS[$ENV]})"

        # Special check for ABRicate environment
        
        if [[ "$ENV" == "qassfilt_abricate" || "$ENV" == "qassfilt_abritamr" ]]; then
            # Special environments without Python
            if ! conda env list | awk '{print $1}' | grep -x "${ENV}" >/dev/null; then
                echo "[WARN] Environment '$ENV' not found. Creating $ENV (no Python)..."
                conda create -y -n "$ENV" \
                    || { echo "❌ Failed to create env $ENV"; exit 1; }
            else
                echo "✅ Environment '$ENV' exists."
            fi
        else
            # Regular environment creation (includes Python)
            if ! conda env list | awk '{print $1}' | grep -x "${ENV}" >/dev/null; then
                echo "[WARN] Environment '$ENV' not found. Creating..."
                conda create -y -n "$ENV" python=3.10 \
                    || { echo "❌ Failed to create env $ENV"; exit 1; }
            else
                echo "✅ Environment '$ENV' exists."
            fi
        fi

        # Activate env
        conda activate "$ENV" || { echo "❌ Failed to activate env $ENV"; exit 1; }
        BIN_PATH="$CONDA_PREFIX/bin"

        # Check if tool exists
        if command -v "$TOOL" &>/dev/null; then
            # Print version if available
            case "$TOOL" in
                fastp)
                    if fastp_ver=$(fastp --version 2>/dev/null); then
                        echo "✅ fastp version: $fastp_ver"
                    else
                        echo "✅ fastp is available (version unknown)"
                    fi
                    ;;
                spades.py)
                    if spades_ver=$(spades.py --version 2>/dev/null); then
                        echo "✅ SPAdes version: $spades_ver"
                    else
                        echo "✅ SPAdes is available (version unknown)"
                    fi
                    ;;
                quast.py)
                    if quast_ver=$(quast.py --version 2>/dev/null); then
                        echo "✅ QUAST version: $quast_ver"
                    else
                        echo "✅ QUAST is available (version unknown)"
                    fi
                    ;;
                checkm2)
                    if checkm2_ver=$(checkm2 --version 2>/dev/null); then
                        echo "✅ CheckM2 version: $checkm2_ver"
                    else
                        echo "✅ CheckM2 is available (version unknown)"
                    fi
                    ;;
                seqkit)
                    if seqkit_ver=$(seqkit version 2>/dev/null); then
                        echo "✅ SeqKit version: $seqkit_ver"
                    else
                        echo "✅ SeqKit is available (version unknown)"
                    fi
                    ;;
                abritamr)
                    if abritamr_ver=$(abritamr --version 2>/dev/null); then
                        echo "✅ ABRITAMR version: $abritamr_ver"
                    else
                        echo "✅ ABRITAMR is available (version unknown)"
                    fi
                    ;;
                abricate)
                    if abricate_ver=$(abricate --version 2>/dev/null); then
                        echo "✅ ABRicate version: $abricate_ver"
                    else
                        echo "✅ ABRicate is available (version unknown)"
                    fi
                    ;;
                kraken2)
                    if kraken2_ver=$(kraken2 --version 2>/dev/null); then
                        echo "✅ Kraken2 version: $kraken2_ver"
                    else
                        echo "✅ Kraken2 is available (version unknown)"
                    fi
                    ;;
                gtdbtk)
                    # Check GTDB-Tk
                    if gtdbtk_ver=$(gtdbtk --version 2>/dev/null); then
                        echo "✅ GTDB-Tk version: $gtdbtk_ver"
                    else
                        echo "❌ GTDB-Tk is not installed or not in PATH"
                    fi

                    # Check Prodigal
                    if prodigal_ver=$(prodigal -v 2>&1); then
                        echo "✅ Prodigal version: $prodigal_ver"
                    else
                        echo "❌ Prodigal is not installed or not in PATH"
                    fi
                    ;;
                multiqc)
                    if multiqc_ver=$(multiqc --version 2>/dev/null); then
                        echo "✅ MultiQC version: $multiqc_ver"
                    else
                        echo "✅ MultiQC is available (version unknown)"
                    fi
                    ;;
                *)
                    echo "✅ $TOOL is available (version unknown)"
                    ;;
            esac
        else
            echo "[WARN] $TOOL not found in $ENV. Installing automatically..."
            case "$TOOL" in
                fastp)
                    fastp_version="1.0.1"
                    [[ -d fastp_dir ]] && rm -rf fastp_dir
                    fastp_url="http://opengene.org/fastp/fastp.${fastp_version}"
                    wget -O fastp "${fastp_url}" || { echo "❌ Failed to download fastp"; exit 1; }
                    chmod a+x ./fastp
                    mkdir -p "$CONDA_PREFIX/share/fastp/bin"
                    mv fastp "$CONDA_PREFIX/share/fastp/bin/"
                    ln -sf "$CONDA_PREFIX/share/fastp/bin/fastp" "$BIN_PATH/fastp"
                    ;;

                spades.py)
                    spades_version="4.2.0"

                    # Detect OS
                    OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')
                    case "$OS_TYPE" in
                        linux) OS="Linux" ;;
                        darwin) OS="MacOSX" ;;
                        *) echo "❌ Unsupported OS: $OS_TYPE"; exit 1 ;;
                    esac

                    # Detect architecture
                    ARCH_TYPE=$(uname -m)
                    case "$ARCH_TYPE" in
                        x86_64) ARCH="x86_64" ;;
                        aarch64 | arm64) ARCH="arm64" ;;
                        *) echo "❌ Unsupported architecture: $ARCH_TYPE"; exit 1 ;;
                    esac

                    # Construct download folder name and URL
                    spades_dir="SPAdes-${spades_version}-${OS}"
                    spades_url="https://github.com/ablab/spades/releases/download/v${spades_version}/${spades_dir}.tar.gz"

                    # Download
                    wget -O "${spades_dir}.tar.gz" "$spades_url" || { echo "❌ Failed to download SPAdes"; exit 1; }

                    # Extract to temporary directory
                    tmp_dir=$(mktemp -d)
                    tar -xzf "${spades_dir}.tar.gz" -C "$tmp_dir" || { echo "❌ Failed to extract SPAdes"; rm -f "${spades_dir}.tar.gz"; exit 1; }

                    # Find extracted SPAdes folder
                    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "SPAdes*" | head -n 1)
                    if [[ -z "$extracted_dir" ]]; then
                        echo "❌ SPAdes folder not found after extraction"
                        rm -rf "$tmp_dir" "${spades_dir}.tar.gz"
                        exit 1
                    fi

                    # Ensure CONDA_PREFIX/share exists
                    mkdir -p "$CONDA_PREFIX/share/"

                    # Move SPAdes to share directory
                    mv "$extracted_dir" "$CONDA_PREFIX/share/spades"

                    # Symlink spades.py
                    ln -sf "$CONDA_PREFIX/share/spades/bin/spades.py" "$BIN_PATH/spades.py"

                    # Symlink all other executables in bin/
                    for exe in "$CONDA_PREFIX/share/spades/bin/"*; do
                        ln -sf "$exe" "$BIN_PATH/$(basename "$exe")"
                    done

                    # Cleanup
                    rm -rf "$tmp_dir" "${spades_dir}.tar.gz"

                    echo "✅ SPAdes v${spades_version} installed to $CONDA_PREFIX/share/spades and linked to $BIN_PATH"
                    ;;

                quast.py)
                    quast_version="quast_5.3.0"
                    [[ -d quast ]] && rm -rf quast
                    git clone https://github.com/ablab/quast.git
                    cd quast || { echo "❌ Failed to enter quast folder"; exit 1; }
                    git checkout "${quast_version}" || { echo "❌ Version ${quast_version} not found"; exit 1; }
                    python setup.py install || { echo "❌ QUAST installation failed"; exit 1; }
                    cd ..
                    rm -rf quast
                    ;;

                checkm2)
                    checkm2_version="1.1.0"
                    [[ -d checkm2 ]] && rm -rf checkm2
                    git clone --recursive https://github.com/chklovski/checkm2.git
                    cd checkm2 || { echo "❌ Failed to enter checkm2 folder"; exit 1; }
                    git checkout "${checkm2_version}" || { echo "❌ Version ${checkm2_version} not found"; exit 1; }
                    git submodule update --init --recursive
                    conda env update -n "$ENV" -f checkm2.yml --prune
                    python setup.py install || { echo "❌ CheckM2 installation failed"; exit 1; }
                    cd ..
                    rm -rf checkm2
                    ;;

                seqkit)
                    seqkit_version="2.10.1"

                    # Detect OS
                    OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')
                    case "$OS_TYPE" in
                        linux) OS="linux" ;;
                        darwin) OS="macos" ;;
                        *) echo "❌ Unsupported OS: $OS_TYPE"; exit 1 ;;
                    esac

                    # Detect architecture
                    ARCH_TYPE=$(uname -m)
                    case "$ARCH_TYPE" in
                        x86_64) ARCH="amd64" ;;
                        aarch64 | arm64) ARCH="arm64" ;;
                        *) echo "❌ Unsupported architecture: $ARCH_TYPE"; exit 1 ;;
                    esac

                    # Construct download URL
                    seqkit_url="https://github.com/shenwei356/seqkit/releases/download/v${seqkit_version}/seqkit_${OS}_${ARCH}.tar.gz"

                    # Download
                    wget -O seqkit.tar.gz "$seqkit_url" || { echo "❌ Failed to download SeqKit"; exit 1; }

                    # Extract to temporary directory
                    tmp_dir=$(mktemp -d)
                    tar -xzf seqkit.tar.gz -C "$tmp_dir" || { echo "❌ Failed to extract SeqKit"; exit 1; }

                    # Find seqkit executable
                    seqkit_exec=$(find "$tmp_dir" -type f -name "seqkit" | head -n 1)
                    if [[ -z "$seqkit_exec" ]]; then
                        echo "❌ seqkit executable not found in the tarball"
                        rm -rf "$tmp_dir" seqkit.tar.gz
                        exit 1
                    fi

                    # Move to BIN_PATH and make executable
                    mv "$seqkit_exec" "$BIN_PATH/" || { echo "❌ Failed to move seqkit to $BIN_PATH"; exit 1; }
                    chmod +x "$BIN_PATH/seqkit"

                    # Cleanup
                    rm -rf "$tmp_dir" seqkit.tar.gz

                    echo "✅ SeqKit v${seqkit_version} installed to $BIN_PATH"
                    ;;

                abritamr)
                    abritamr_version="1.0.19"  # Conda uses version without "v"

                    echo "[INFO] Installing ABRITAMR v${abritamr_version} in $ENV..."

                    # Activate the environment
                    conda activate "$ENV" || { echo "❌ Failed to activate $ENV"; exit 1; }

                    # Install Perl and required dependencies via Conda
                    conda install -y -n "$ENV" abritamr=${abritamr_version}

                    conda deactivate
                    ;;

                abricate)
                    abricate_version="1.0.1"
                    echo "[INFO] Installing ABRicate v${abricate_version} in $ENV..."

                    # Activate the environment
                    conda activate "$ENV" || { echo "❌ Failed to activate $ENV"; exit 1; }

                    # Install Perl and required dependencies via Conda
                    conda install -y -n "$ENV" -c bioconda abricate=${abricate_version}

                    conda deactivate
                    ;;

                multiqc)
                    multiqc_version="1.31"
                    pip install "multiqc==${multiqc_version}" || { echo "❌ Failed to install MultiQC"; exit 1; }
                    ;;

                kraken2)
                    kraken2_version="v2.1.6"
                    [[ -d kraken2_dir ]] && rm -rf kraken2_dir
                    git clone https://github.com/DerrickWood/kraken2.git kraken2_dir
                    cd kraken2_dir || { echo "❌ Failed to enter kraken2_dir"; exit 1; }
                    git checkout "${kraken2_version}" || { echo "❌ Version ${kraken2_version} not found"; exit 1; }
                    ./install_kraken2.sh "$CONDA_PREFIX/share/kraken2" || { echo "❌ Kraken2 build failed"; exit 1; }
                    for exe in "$CONDA_PREFIX/share/kraken2/"*; do
                        ln -sf "$exe" "$BIN_PATH/$(basename "$exe")"
                    done
                    cd ..
                    rm -rf kraken2_dir
                    ;;
                gtdbtk)
                    echo "[INFO] Installing GTDB-Tk and dependencies in $ENV..."
                # Define versions
                    gtdbtk_version="2.5.2"
                    prodigal_version="2.6.3"
                    hmmer_version="3.4"
                    pplacer_version="1.1.alpha20"
                    skani_version="0.3.0"
                    fasttree_version="2.2.0"
                    mash_version="2.3"

                    # Check if inside a Conda environment
                    if [ -z "$CONDA_PREFIX" ]; then
                        echo "❌ No active Conda environment detected. Please activate your GTDB-Tk environment first."
                        exit 1
                    fi

                    # Activate the Conda environment
                    conda activate qassfilt_gtdbtk

                    # Step 1: Install GTDB-Tk via pip
                    echo "⚙️ Installing GTDB-Tk v${gtdbtk_version}..."
                    python -m pip install "gtdbtk==${gtdbtk_version}" || { echo "❌ Failed to install GTDB-Tk"; exit 1; }

                    # Step 2: Install Prodigal from source
                    echo "⚙️ Installing Prodigal v${prodigal_version}..."
                    PRODIGAL_URL="https://github.com/hyattpd/Prodigal/archive/refs/tags/v${prodigal_version}.tar.gz"
                    TMP_DIR=$(mktemp -d)
                    cd "$TMP_DIR" || { echo "❌ Failed to create temp directory"; exit 1; }
                    wget -q "$PRODIGAL_URL" -O prodigal.tar.gz || { echo "❌ Failed to download Prodigal"; exit 1; }
                    tar -xzf prodigal.tar.gz
                    cd "Prodigal-${prodigal_version}" || { echo "❌ Prodigal source directory missing"; exit 1; }
                    make clean >/dev/null 2>&1
                    make >/dev/null 2>&1
                    make install INSTALLDIR="${CONDA_PREFIX}/bin" || { echo "❌ Failed to install Prodigal"; exit 1; }
                    cd - >/dev/null
                    rm -rf "$TMP_DIR"

                    # Step 3: Install HMMER via Conda
                    echo "⚙️ Installing HMMER v${hmmer_version}..."
                    conda install -y -c bioconda hmmer=="${hmmer_version}" || { echo "❌ Failed to install HMMER"; exit 1; }

                    # Step 4: Install pplacer via Conda
                    echo "⚙️ Installing pplacer v${pplacer_version}..."
                    conda install -y -c bioconda pplacer=="${pplacer_version}" || { echo "❌ Failed to install pplacer"; exit 1; }

                    # Step 5: Install skani via Conda
                    echo "⚙️ Installing skani v${skani_version}..."
                    conda install -y -c bioconda skani=="${skani_version}" || { echo "❌ Failed to install skani"; exit 1; }

                    # Step 6: Install FastTree via Conda
                    echo "⚙️ Installing FastTree v${fasttree_version}..."
                    conda install -y -c bioconda fasttree=="${fasttree_version}" || { echo "❌ Failed to install FastTree"; exit 1; }

                    # Step 7: Install Mash via Conda
                    echo "⚙️ Installing Mash v${mash_version}..."
                    conda install -y -c bioconda mash=="${mash_version}" || { echo "❌ Failed to install Mash"; exit 1; }

                    # Step 8: Verify installations
                    echo "⚙️ Verifying installations..."
                    if ! gtdbtk --version &>/dev/null; then
                        echo "❌ GTDB-Tk installation failed."
                        exit 1
                    fi
                    if ! command -v prodigal &>/dev/null; then
                        echo "❌ Prodigal installation failed or not found in PATH."
                        exit 1
                    fi
                    if ! command -v hmmsearch &>/dev/null; then
                        echo "❌ HMMER installation failed or not found in PATH."
                        exit 1
                    fi
                    if ! command -v pplacer &>/dev/null; then
                        echo "❌ pplacer installation failed or not found in PATH."
                        exit 1
                    fi
                    if ! command -v skani &>/dev/null; then
                        echo "❌ skani installation failed or not found in PATH."
                        exit 1
                    fi
                    if ! command -v FastTree &>/dev/null; then
                        echo "❌ FastTree installation failed or not found in PATH."
                        exit 1
                    fi
                    if ! command -v mash &>/dev/null; then
                        echo "❌ Mash installation failed or not found in PATH."
                        exit 1
                    fi

                    echo "✅ All tools installed successfully."
                    ;;
                *)
                    echo "❌ Unknown tool $TOOL"
                    exit 1
                    ;;
            esac
            echo "✅ $TOOL already installed in $ENV."
        fi

        # CheckM2 DB only if qassfilt_checkm2 is active
        if [[ "$ENV" == "qassfilt_checkm2" ]]; then
            if [[ -n "$CHECKM2DB_PATH" ]]; then
                CHECKM2_DB="$CHECKM2DB_PATH"
                echo "✅ Using user-specified CheckM2 database: $CHECKM2_DB"
            else
                CHECKM2_DB="$HOME/databases/CheckM2_database"
                mkdir -p "$CHECKM2_DB"
                if [[ ! -d "$CHECKM2_DB" || -z "$(ls -A "$CHECKM2_DB")" ]]; then
				conda activate qassfilt_checkm2
                    echo "[WARN] CheckM2 DB not found, downloading..."
                    checkm2 database --download
                else
                    echo "✅ Found CheckM2 DB in $CHECKM2_DB"
                fi
            fi
            export CHECKM2DB="$CHECKM2_DB"
            echo "🔗 Exported CHECKM2DB=$CHECKM2DB"
        fi

        conda deactivate
    done

    echo ""
    echo "✅ QAssfilt required environments, tools, and CheckM2 database are ready."
    echo ""
}

# =========================
# TRIGGER Init
# =========================
if [[ $INIT_MODE -eq 1 ]]; then
    check_envs_and_tools
    echo "QAssfilt initialization completed. Exiting."
    exit 0
fi

if [[ "${CONTIG_MODE:-0}" -eq 1 ]]; then
    CONTIG_MODE_DISPLAY="Enabled"
else
    CONTIG_MODE_DISPLAY="Disabled"
fi

# ABRITAMR mode display
if [[ "${RUN_ABRITAMR:-0}" -eq 1 ]]; then
    ABRITAMR_MODE=1
    ABRITAMR_MODE_DISPLAY="Enabled"
else
    ABRITAMR_MODE=0
    ABRITAMR_MODE_DISPLAY="Disabled"
fi

# ABRICATE mode display
if [[ "${RUN_ABRICATE:-0}" -eq 1 ]]; then
    ABRICATE_MODE=1
    ABRICATE_MODE_DISPLAY="Enabled"
else
    ABRICATE_MODE=0
    ABRICATE_MODE_DISPLAY="Disabled"
fi

# KRAKEN2 mode display (already handled above, but double-check logic)
if [[ -n "${KRAKEN2_DB_PATH}" && "${KRAKEN2_DB_PATH}" != "0" && -d "${KRAKEN2_DB_PATH}" ]]; then
    KRAKEN2_MODE=1
    KRAKEN2_MODE_DISPLAY="Enabled"
else
    KRAKEN2_MODE=0
    KRAKEN2_MODE_DISPLAY="Disabled"
fi

# GTDBTK mode display (already handled above, but double-check logic)
if [[ -n "${GTDBTK_DB_PATH}" && "${GTDBTK_DB_PATH}" != "0" && -d "${GTDBTK_DB_PATH}" ]]; then
    GTDBTK_MODE=1
    GTDBTK_MODE_DISPLAY="Enabled"
    export GTDBTK_DATA_PATH="${GTDBTK_DB_PATH}"
else
    GTDBTK_MODE=0
    GTDBTK_MODE_DISPLAY="Disabled"
fi

# call: contigs_remove to_remove.tab
contigs_remove() {
    local TAB_FILE="$1"

    # safety: fail early if missing arg
    if [[ -z "${TAB_FILE:-}" || ! -s "$TAB_FILE" ]]; then
        echo "❌ Tab file is missing or empty: $TAB_FILE"
        return 1
    fi

    while IFS=$'\t' read -r FASTA CONTIGS || [[ -n "$FASTA" ]]; do
        # skip empty/comment lines
        [[ -z "$FASTA" || "$FASTA" =~ ^# ]] && continue

        if [[ ! -s "$FASTA" ]]; then
            echo "⚠️  Fasta not found or empty: $FASTA"
            continue
        fi

        # preserve original extension (handles .fasta .fa .fna etc.)
        local base ext OUT
        base="${FASTA%.*}"
        ext="${FASTA##*.}"
        OUT="${base}_removed.${ext}"

        # if CONTIGS column empty -> copy file as-is (or skip)
        if [[ -z "${CONTIGS// /}" ]]; then
            echo "ℹ️  No contigs listed for $FASTA — copying to $OUT"
            cp -p -- "$FASTA" "$OUT"
            continue
        fi

        echo "🧹 Removing contigs [$CONTIGS] from $FASTA → $OUT"

        # AWK: read the comma-separated contig list into an associative array,
        # then stream through the fasta, keeping records whose *first token*
        # of the header is NOT in the removal list.
        awk -v names="$CONTIGS" '
        BEGIN {
            # split contig names by comma (allow optional spaces after comma)
            n = split(names, arr, /[[:space:]]*,[[:space:]]*/);
            for (i=1; i<=n; i++) {
                if (arr[i] != "") remove[arr[i]] = 1;
            }
            RS=">"; ORS="";
        }
        NR==1 { next }                  # skip the empty record before the first ">"
        {
            # $0 is "header\nsequence..."
            split($0, lines, "\n");
            header = lines[1];
            # take the first token of header (contig id before first space/tab)
            split(header, tok, /[ \t]/);
            id = tok[1];
            if (!(id in remove)) {
                # print the record back with the leading ">"
                print ">" $0;
            }
        }' "$FASTA" > "$OUT" || { echo "❌ awk failed for $FASTA"; continue; }

    done < "$TAB_FILE"
}

# Contig removal
if [[ -n "${CONTIGS_REMOVE:-}" ]]; then
    echo "🧾 Running contig removal using ${CONTIGS_REMOVE}"
    contigs_remove "$CONTIGS_REMOVE"
    echo "✅ Contig removal finished"
    exit 0
fi

# =========================
# PRINT INTRO ONCE
# =========================
print_intro() {
    echo "You have specified the following options:"
    echo "    INPUT_PATH          = $INPUT_PATH"
    echo "    CONTIG_MODE         = ${CONTIG_MODE_DISPLAY}"
    echo -n "    KRAKEN2_MODE        = $KRAKEN2_MODE_DISPLAY"
    [[ -n "$KRAKEN2_DB_PATH" ]] && echo -n " (DB: $KRAKEN2_DB_PATH)"
    echo

    echo -n "    GTDBTK_MODE         = $GTDBTK_MODE_DISPLAY"
    [[ -n "$GTDBTK_DB_PATH" ]] && echo -n " (DB: $GTDBTK_DB_PATH)"
    echo

    echo -n "    ABRITAMR_MODE       = $ABRITAMR_MODE_DISPLAY"
    [[ -n "$ABRITAMR_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRITAMR_EXTRA_OPTS)"
    echo

    echo -n "    ABRICATE_MODE       = $ABRICATE_MODE_DISPLAY"
    [[ -n "$ABRICATE_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRICATE_EXTRA_OPTS)"
    echo

    echo "    INPUT_DIR_DEPTH     = $INPUT_DIR_DEPTH"
    echo "    CHECKM2DB_PATH      = $CHECKM2DB_PATH"
    echo "    OUTPUT_PATH         = $OUTPUT_PATH"
    echo "    SPADES_THREADS      = $SPADES_THREADS"
    echo "    FASTP_THREADS       = $FASTP_THREADS"
    echo "    CHECKM2_THREADS     = $CHECKM2_THREADS"
    echo "    QUAST_THREADS       = $QUAST_THREADS"
    echo "    KRAKEN2_THREADS     = $KRAKEN2_THREADS"
    echo "    GTDBTK_THREADS      = $GTDBTK_THREADS"
    echo "    QUAST_REFERENCE     = $QUAST_REFERENCE"
    echo "    SEQKIT_MIN_COV      = $SEQKIT_MIN_COV"
    echo "    SEQKIT_MIN_LENGTH   = $SEQKIT_MIN_LENGTH"
    echo "    SKIP_STEPS          = ${SKIP_STEPS[*]}"
    echo "    FASTP_EXTRA_OPTS    = $FASTP_EXTRA_OPTS"
    echo "    SPADES_EXTRA_OPTS   = $SPADES_EXTRA_OPTS"
    echo ""
}

# Print intro once at the start and save to pipeline_parameters.txt
if [[ -t 1 ]]; then
    print_intro | tee "$PARAM_LOG"
else
    print_intro > "$PARAM_LOG"
fi

# =============
# update_status
# =============
HEADER_PRINTED=0

update_status() {
    local SAMPLE=$1
    local STEP=$2
    local STATUS=$3
    local ERROR_FILE="${4:-}"   # Optional: path to log file for errors
    local COL

    # Map step to column
    case $STEP in
        FASTP) COL=2 ;;
        SPADES) COL=3 ;;
        QUAST-b) COL=4 ;;
        CHECKM2-b) COL=5 ;;
        FILTER) COL=6 ;;
        QUAST-a) COL=7 ;;
        CHECKM2-a) COL=8 ;;
        KRAKEN2-b) COL=9 ;;
        KRAKEN2-a) COL=10 ;;
        GTDBTK-b) COL=11 ;;
        GTDBTK-a) COL=12 ;;
        ABRITAMR-b) COL=13 ;;
        ABRITAMR-a) COL=14 ;;
        ABRICATE-b) COL=15 ;;
        ABRICATE-a) COL=16 ;;
        MULTIQC) COL=17 ;;
        *) echo "Unknown step $STEP"; return ;;
    esac

    # Initialize STATUS_FILE if not exists
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo -e "Sample\tFASTP\tSPADES\tQUAST-b\tCHECKM2-b\tFILTER\tQUAST-a\tCHECKM2-a\tKRAKEN2-b\tKRAKEN2-a\tGTDBTK-b\tGTDBTK-a\tABRITAMR-b\tABRITAMR-a\tABRICATE-b\tABRICATE-a\tMULTIQC" > "$STATUS_FILE"
    fi

    # Update status file safely with flock
    (
        flock -x 200

        if grep -q "^$SAMPLE" "$STATUS_FILE"; then
            awk -v sample="$SAMPLE" -v col="$COL" -v status="$STATUS" \
                'BEGIN{FS=OFS="\t"} $1==sample{$col=status}1' \
                "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
        else
            # Initialize new row with blanks
            ROW=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
            ROW[$((COL-1))]="$STATUS"
            echo -e "$SAMPLE\t$(IFS=$'\t'; echo "${ROW[*]}")" >> "$STATUS_FILE"
        fi

        # Sort file by sample ID, keep header first
        (head -1 "$STATUS_FILE"; tail -n +2 "$STATUS_FILE" | sort) > "${STATUS_FILE}.sorted" && mv "${STATUS_FILE}.sorted" "$STATUS_FILE"

    ) 200>"$STATUS_FILE.lock"

    # -------------------------
    # Append last 5 lines of error log if FAIL
    # -------------------------
   if [[ "$STATUS" == "FAIL" && -n "$ERROR_FILE" ]]; then
        mkdir -p "${OUTPUT_PATH}"
        {
            echo "------------------------"
            echo -e "Sample: $SAMPLE\tStep: $STEP\n"
            if [[ -f "$ERROR_FILE" ]]; then
                tail -n 5 "$ERROR_FILE"
            else
                # treat ERROR_FILE as inline content (already the last-lines captured)
                echo -e "$ERROR_FILE"
            fi
            echo -e "\n"
        } >> "${OUTPUT_PATH}/pipeline_errors.log"
    fi

# -------------------------
# Live display with colors
# -------------------------
if [[ -t 1 && "$STATUS" == "RUNNING" ]]; then
    # Clear the screen
    clear
    CYAN="\e[36m"
    RESET="\e[0m"

    # -------------------------
    # Pinned header
    # -------------------------
	echo -e ""
	echo -e "QAssfilt Pipeline Progressing..."  # Print the static part
	echo -e "------------------------------------------------"
	echo -e "Options specified"
	echo -e ""
    echo -e "  INPUT_PATH        : $INPUT_PATH"
    echo -e "  INPUT_DIR_DEPTH   : ${CYAN}$INPUT_DIR_DEPTH${RESET}"
    echo -e "  OUTPUT_PATH       : $OUTPUT_PATH"
    echo -e "  CHECKM2DB_PATH    : $CHECKM2DB_PATH"
    echo -e "  CONTIG_MODE       : $CONTIG_MODE_DISPLAY"
    echo -n "  KRAKEN2_MODE      : $KRAKEN2_MODE_DISPLAY"
    if [[ "$KRAKEN2_MODE" -ne 1 ]]; then
        update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
        update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
    else
        [[ -n "$KRAKEN2_DB_PATH" ]] && echo -n " (DB: $KRAKEN2_DB_PATH)"
    fi
    echo

    # GTDBTK
    echo -n "  GTDBTK_MODE       : $GTDBTK_MODE_DISPLAY"
    if [[ "$GTDBTK_MODE" -ne 1 ]]; then
        update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
        update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
    else
        [[ -n "$GTDBTK_DB_PATH" ]] && echo -n " (DB: $GTDBTK_DB_PATH)"
    fi
    echo

    # ABRITAMR
    echo -n "  ABRITAMR_MODE     : $ABRITAMR_MODE_DISPLAY"
    if [[ "$ABRITAMR_MODE" -ne 1 ]]; then
        update_status "$SAMPLE" "ABRITAMR-b" "SKIPPED"
        update_status "$SAMPLE" "ABRITAMR-a" "SKIPPED"
    else
        [[ -n "$ABRITAMR_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRITAMR_EXTRA_OPTS)"
    fi
    echo

    # ABRICATE
    echo -n "  ABRICATE_MODE     : $ABRICATE_MODE_DISPLAY"
    if [[ "$ABRICATE_MODE" -ne 1 ]]; then
        update_status "$SAMPLE" "ABRICATE-b" "SKIPPED"
        update_status "$SAMPLE" "ABRICATE-a" "SKIPPED"
    else
        [[ -n "$ABRICATE_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRICATE_EXTRA_OPTS)"
    fi
    echo
    echo -e "  SPADES_THREADS    : ${CYAN}$SPADES_THREADS${RESET}"
    echo -e "  FASTP_THREADS     : ${CYAN}$FASTP_THREADS${RESET}"
    echo -e "  CHECKM2_THREADS   : ${CYAN}$CHECKM2_THREADS${RESET}"
    echo -e "  QUAST_THREADS     : ${CYAN}$QUAST_THREADS${RESET}"
	echo -e "  KRAKEN2_THREADS   : ${CYAN}$KRAKEN2_THREADS${RESET}"
	echo -e "  GTDBTK_THREADS    : ${CYAN}$GTDBTK_THREADS${RESET}"
    echo -e "  QUAST_REFERENCE   : $QUAST_REFERENCE"
    echo -e "  SEQKIT_MIN_COV    : ${CYAN}$SEQKIT_MIN_COV${RESET}"
    echo -e "  SEQKIT_MIN_LENGTH : ${CYAN}$SEQKIT_MIN_LENGTH${RESET}"
    echo -e "  SKIP_STEPS        : ${SKIP_STEPS[*]}"
    echo -e "  FASTP_EXTRA_OPTS  : ${CYAN}$FASTP_EXTRA_OPTS${RESET}"
    echo -e "  SPADES_EXTRA_OPTS : ${CYAN}$SPADES_EXTRA_OPTS${RESET}"
    echo -e "------------------------------------------------"
	echo -e "QAssfilt sample list : ${OUTPUT_PATH}/pipeline_status.tsv"
	echo -e ""
	echo -e "QAssfilt detail logs : ${OUTPUT_PATH}/logs"
    echo -e ""
	    if [[ -f "$STATUS_FILE" ]]; then
    TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))
    RUNNED=$(awk '
        NR>1 {
            for(i=2;i<=NF;i++) {
                if($i != "-" && $i != "SKIPPED") {
                    print $1
                    break
                }
            }
        }' "$STATUS_FILE" | sort -u | wc -l)

    echo -e "Samples processed: ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
    echo -e "------------------------------------------------"
fi
    # Print column header (pinned)
    HEADER_FORMAT="%-16s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n"
    head -1 "$STATUS_FILE" | awk -v fmt="$HEADER_FORMAT" 'BEGIN{FS=OFS="\t"} {printf fmt,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17}'
    echo -e ""

    # -------------------------
    # Only print the current sample row
    # -------------------------
    grep "^$SAMPLE" "$STATUS_FILE" | while IFS=$'\t' read -r sample fastp spades quastb checkm2b filter quasta checkm2a kraken2b kraken2a gtdbtkb gtdbtka abritamrb abritamra abricateb abricatea multiqc; do
        for var in fastp spades quastb checkm2b filter quasta checkm2a kraken2b kraken2a gtdbtkb gtdbtka abritamrb abritamra abricateb abricatea multiqc; do
            case "${!var}" in
                RUNNING) eval "$var=\"RUNNING\"" ;;
                OK)      eval "$var=\"OK\"" ;;
                FAIL)    eval "$var=\"FAIL\"" ;;
                SKIPPED) eval "$var=\"SKIPPED\"" ;;
                *)       eval "$var=\"-\"" ;;
            esac
        done

        printf "$HEADER_FORMAT" \
            "$sample" "$fastp" "$spades" "$quastb" "$checkm2b" "$filter" "$quasta" "$checkm2a" "$kraken2b" "$kraken2a" "$gtdbtkb" "$gtdbtka" "$abritamrb" "$abritamra" "$abricateb" "$abricatea" "$multiqc"
    done
fi
}

#=========================
# RESUME HELPERS
# =========================
get_status() {
    local SAMPLE=$1
    local STEP=$2
    awk -F"\t" -v s="$SAMPLE" -v step="$STEP" '
        NR==1 {for (i=1;i<=NF;i++){if($i==step) c=i}}
        $1==s {print $c}' "$STATUS_FILE"
}

# -------------------------
# NEW: get_last_incomplete_step
# -------------------------
get_last_incomplete_step() {
    local SAMPLE=$1
    local STEPS=(FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a ABRITAMR-b ABRITAMR-a ABRICATE-b ABRICATE-a MULTIQC)
    local LAST=""

    for (( idx=${#STEPS[@]}-1; idx>=0; idx-- )); do
        local s=${STEPS[idx]}
        local STATUS
        STATUS=$(get_status "$SAMPLE" "$s" || echo "-")

        # Ignore steps that are OK or SKIPPED
        if [[ "$STATUS" != "OK" && "$STATUS" != "SKIPPED" ]]; then
            LAST="$s"
            break
        fi
    done

    echo "$LAST"
}

should_run_step() {
    local SAMPLE=$1
    local STEP=$2

    # If user explicitly requested skip -> mark ALL samples skipped for this step
    if is_skipped "$STEP"; then
        update_status "$SAMPLE" "$STEP" "SKIPPED"
        return 1
    fi

    # Otherwise, follow normal pipeline order
    local LAST
    LAST=$(get_last_incomplete_step "$SAMPLE")

    if [[ "$STEP" == "$LAST" ]]; then
        return 0   # run this step
    else
        return 1   # do not run (leave status untouched)
    fi
}

# =========================
# DETECT PAIRED FILES FLEXIBLY
# =========================
# Detect samples
SAMPLES=()  # Initialize empty sample list

if [[ $CONTIG_MODE -eq 1 ]]; then
    echo "[INFO] Running in contig mode (--contigs): scanning for fasta files in $INPUT_PATH"
    declare -A CONTIG_PATHS
    while IFS= read -r -d '' FILE; do
        SAMPLE=$(basename "$FILE")
        SAMPLE=${SAMPLE%%.*}  # Remove extension
        SAMPLES+=("$SAMPLE")
        CONTIG_PATHS["$SAMPLE"]="$FILE"
    done < <(find "$INPUT_PATH" -maxdepth $INPUT_DIR_DEPTH -type f \( -iname "*.fa" -o -iname "*.fasta" -o -iname "*.fna" -o -iname "*.fas" \) -print0)

else
    # =========================
    # DETECT PAIRED FASTQ FILES FLEXIBLY
    # =========================
declare -A PAIRS
while IFS= read -r -d '' file; do
    BASENAME=$(basename "$file")
    if [[ "$BASENAME" =~ ^(.+)(_R?1(_[0-9]{3})?|_1)\.f(ast)?q(\.gz)?$ ]]; then
        SAMPLE="${BASH_REMATCH[1]}"
        PAIRS["$SAMPLE,1"]="$file"
    elif [[ "$BASENAME" =~ ^(.+)(_R?2(_[0-9]{3})?|_2)\.f(ast)?q(\.gz)?$ ]]; then
        SAMPLE="${BASH_REMATCH[1]}"
        PAIRS["$SAMPLE,2"]="$file"
    fi
done < <(find "${INPUT_PATH:-.}" -maxdepth $INPUT_DIR_DEPTH -type f \( -name "*.fq*" -o -name "*.fastq*" \) -print0)

    # GET UNIQUE SAMPLE NAMES IN ORDER (A→Z)
    SAMPLES=($(printf "%s\n" "${!PAIRS[@]}" | sed 's/,.*//' | sort -V | uniq))
fi

# ========================
# INITIALIZE STATUS FILE
# =========================
if [[ ! -f "$STATUS_FILE" ]]; then
    echo -e "Sample\tFASTP\tSPADES\tQUAST-b\tCHECKM2-b\tFILTER\tQUAST-a\tCHECKM2-a\tKRAKEN2-b\tKRAKEN2-a\tGTDBTK-b\tGTDBTK-a\tABRITAMR-b\tABRITAMR-a\tABRICATE-b\tABRICATE-a\tMULTIQC" > "$STATUS_FILE"
    for SAMPLE in "${SAMPLES[@]}"; do
        echo -e "$SAMPLE\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-" >> "$STATUS_FILE"
    done
fi

# APPLY SKIPS
# =========================
process_skips   # <- normalize skip list
for SAMPLE in "${SAMPLES[@]}"; do
    for STEP in FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a ABRITAMR-b ABRITAMR-a ABRICATE-b ABRICATE-a MULTIQC; do
        if is_skipped "$STEP"; then
            update_status "$SAMPLE" "$STEP" "SKIPPED"
        fi
    done
done

# Mark explicitly skipped steps for all samples
mark_skipped_steps

# =========================
# MARK SKIPPED STEPS IMMEDIATELY
# =========================
for SAMPLE in "${SAMPLES[@]}"; do
    for STEP in FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a ABRITAMR-b ABRITAMR-a ABRICATE-b ABRICATE-a MULTIQC; do
        # Only skip if SKIP_STEPS is set and contains this STEP
        if [[ -n "${SKIP_STEPS-}" ]] && [[ " ${SKIP_STEPS,,} " == *"${STEP,,}"* ]]; then
            update_status "$SAMPLE" "$STEP" "SKIPPED"
        fi
    done
done

# =========================
# PRE-RUN ERROR CHECK FOR UNMATCHED FILES
# =========================

MISSING=0
declare -A CHECKED_SAMPLES

for KEY in "${!PAIRS[@]}"; do
    SAMPLE="${KEY%%,*}"

    # Skip if we already checked this sample
    [[ -n "${CHECKED_SAMPLES[$SAMPLE]+x}" ]] && continue
    CHECKED_SAMPLES["$SAMPLE"]=1

    if [[ -z "${PAIRS["$SAMPLE,1"]+x}" ]]; then
        echo "[WARN] Missing R1 for sample '$SAMPLE'"
        MISSING=1
    fi
    if [[ -z "${PAIRS["$SAMPLE,2"]+x}" ]]; then
        echo "[WARN] Missing R2 for sample '$SAMPLE'"
        MISSING=1
    fi
done

[[ $MISSING -eq 1 ]] && { echo "Please check your input files. QAssfilt pipeline will exit."; exit 1; }

# =========================
# PIPELINE FUNCTION FOR ONE SAMPLE (with resume)
# =========================
process_sample() {
    local SAMPLE=$1
    local R1=$2
    local R2=$3

    # =========================
    # Directories
    # =========================
    local LOG_DIR="${OUTPUT_PATH}/logs"
    local FASTP_DIR="${OUTPUT_PATH}/fastp_file"
    local SPADES_DIR="${OUTPUT_PATH}/spades_file/${SAMPLE}"
	local CONTIGS_BEFORE_DIR="${OUTPUT_PATH}/contigs_before"
    local FILTERED_DIR="${OUTPUT_PATH}/contigs_filtered"
    mkdir -p "$LOG_DIR" "$FASTP_DIR" "$SPADES_DIR" "$CONTIGS_BEFORE_DIR" "$FILTERED_DIR"

    # =========================
    # Default file paths
    # =========================
    local CONTIGS_BEFORE=""
    local OUTFILTER="${FILTERED_DIR}/${SAMPLE}_filtered.fasta"
    local OUT1="${FASTP_DIR}/${SAMPLE}_R1.fastq.gz"
    local OUT2="${FASTP_DIR}/${SAMPLE}_R2.fastq.gz"
    local SPADES_CONTIGS="${SPADES_DIR}/contigs.fasta"

    # =========================
    # Contig mode handling
    # =========================
    if [[ "${CONTIG_MODE:-0}" -eq 1 ]]; then
        echo "[INFO] Contig mode: skipping FASTP and SPADES"
        CONTIGS_BEFORE="${CONTIG_PATHS[$SAMPLE]:-}"
        update_status "$SAMPLE" "FASTP" "SKIPPED"
        update_status "$SAMPLE" "SPADES" "SKIPPED"
		OUTFILTER="${FILTERED_DIR}/${SAMPLE}_filtered.fasta"
    else
        # =========================
        # 1. FASTP
        # =========================
        if is_skipped "FASTP"; then
            update_status "$SAMPLE" "FASTP" "SKIPPED"
        elif should_run_step "$SAMPLE" "FASTP" || [[ ! -s "$OUT1" || ! -s "$OUT2" ]] || [[ ! -s "${FASTP_DIR}/${SAMPLE}_fastp.html" ]] || [[ ! -s "${FASTP_DIR}/${SAMPLE}_fastp.json" ]]; then
            update_status "$SAMPLE" "FASTP" "RUNNING"
            conda activate qassfilt_fastp
            fastp -i "$R1" -I "$R2" \
                  -o "$OUT1" -O "$OUT2" \
                  -h "${FASTP_DIR}/${SAMPLE}_fastp.html" \
                  -j "${FASTP_DIR}/${SAMPLE}_fastp.json" \
                  -w $FASTP_THREADS $FASTP_EXTRA_OPTS \
                  >"$LOG_DIR/${SAMPLE}_fastp.log" 2>&1
            FASTP_EXIT=$?
            conda deactivate

            if [[ $FASTP_EXIT -eq 0 ]]; then
                update_status "$SAMPLE" "FASTP" "OK"
            else
                update_status "$SAMPLE" "FASTP" "FAIL" "$LOG_DIR/${SAMPLE}_fastp.log"
            fi
        fi

        # =========================
        # 2. SPADES
        # =========================
        if is_skipped "SPADES"; then
        update_status "$SAMPLE" "SPADES" "SKIPPED"
        elif should_run_step "$SAMPLE" "SPADES" || [[ ! -s "${CONTIGS_BEFORE_DIR}/${SAMPLE}_before.fasta" ]]; then
            update_status "$SAMPLE" "SPADES" "RUNNING"
            conda activate qassfilt_spades

            # Use FASTP output if available
            local SPADES_R1="$OUT1"
            local SPADES_R2="$OUT2"
            if is_skipped "FASTP"; then
                SPADES_R1="${PAIRS["$SAMPLE,1"]}"
                SPADES_R2="${PAIRS["$SAMPLE,2"]}"
            fi

            spades.py -1 "$SPADES_R1" -2 "$SPADES_R2" \
                      -o "$SPADES_DIR" \
                      -t $SPADES_THREADS $SPADES_EXTRA_OPTS \
                      >"$LOG_DIR/${SAMPLE}_spades.log" 2>&1
            SPADES_EXIT=$?
            conda deactivate

            if [[ $SPADES_EXIT -eq 0 ]]; then
			CONTIGS_BEFORE="${CONTIGS_BEFORE_DIR}/${SAMPLE}_before.fasta"
			[[ -s "$SPADES_CONTIGS" ]] && cp "$SPADES_CONTIGS" "$CONTIGS_BEFORE"
			update_status "$SAMPLE" "SPADES" "OK"
            else
                update_status "$SAMPLE" "SPADES" "FAIL" "$LOG_DIR/${SAMPLE}_spades.log"
            fi
        else
            CONTIGS_BEFORE="$SPADES_CONTIGS"
        fi
    fi

		# =========================
		# 3. QUAST BEFORE FILTERING
		# =========================
		if is_skipped "QUAST-b"; then
			update_status "$SAMPLE" "QUAST-b" "SKIPPED"
		elif [[ -s "$CONTIGS_BEFORE" ]]; then
			# Run QUAST-b if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "QUAST-b" || [[ ! -s "${OUTPUT_PATH}/quast_before/${SAMPLE}/report.tsv" ]]; then
				update_status "$SAMPLE" "QUAST-b" "RUNNING"
				conda activate qassfilt_quast
				local OUTDIR_QUAST="${OUTPUT_PATH}/quast_before/${SAMPLE}"
				mkdir -p "$OUTDIR_QUAST"

				if [[ -n "${QUAST_REFERENCE:-}" && -f "$QUAST_REFERENCE" ]]; then
					quast.py -o "$OUTDIR_QUAST" -t $QUAST_THREADS --reference "$QUAST_REFERENCE" "$CONTIGS_BEFORE" \
						>"$LOG_DIR/${SAMPLE}_quast_before.log" 2>&1
				else
					quast.py -o "$OUTDIR_QUAST" -t $QUAST_THREADS "$CONTIGS_BEFORE" \
						>"$LOG_DIR/${SAMPLE}_quast_before.log" 2>&1
				fi

				QUASTB_EXIT=$?
				conda deactivate

				[[ $QUASTB_EXIT -eq 0 ]] && update_status "$SAMPLE" "QUAST-b" "OK" || update_status "$SAMPLE" "QUAST-b" "FAIL" "$LOG_DIR/${SAMPLE}_quast_before.log"
			fi
		else
			echo "[WARN] $SAMPLE: CONTIGS_BEFORE not found, skipping QUAST-b"
			update_status "$SAMPLE" "QUAST-b" "SKIPPED"
		fi

		# =========================
		# 4. CHECKM2 BEFORE FILTERING
		# =========================
		if is_skipped "CHECKM2-b"; then
			update_status "$SAMPLE" "CHECKM2-b" "SKIPPED"
		elif [[ -s "$CONTIGS_BEFORE" ]]; then
			# Run CHECKM2-b if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "CHECKM2-b" || [[ ! -s "${OUTPUT_PATH}/checkm2_before/${SAMPLE}/quality_report.tsv" ]]; then
				update_status "$SAMPLE" "CHECKM2-b" "RUNNING"
				conda activate qassfilt_checkm2

				# -----------------------
				# Export CHECKM2DB with default fallback
				# -----------------------
				DEFAULT_CHECKM2DB="$HOME/databases/CheckM2_database"
				export CHECKM2DB="${CHECKM2DB_PATH:-${CHECKM2_DB:-$DEFAULT_CHECKM2DB}}"
				echo "[INFO] CHECKM2DB set to $CHECKM2DB"

				LOG_FILE="$LOG_DIR/${SAMPLE}_checkm2_before.log"
				DB_ARG="--database_path ${CHECKM2DB}/*.dmnd"

				checkm2 predict --threads "$CHECKM2_THREADS" \
					$DB_ARG \
					--input "$CONTIGS_BEFORE" \
					--force \
					--output-directory "${OUTPUT_PATH}/checkm2_before/${SAMPLE}" \
					>"$LOG_FILE" 2>&1

				CHECKM2B_EXIT=$?
				conda deactivate

				[[ $CHECKM2B_EXIT -eq 0 ]] && update_status "$SAMPLE" "CHECKM2-b" "OK" || update_status "$SAMPLE" "CHECKM2-b" "FAIL" "$LOG_FILE"
			fi
		else
			echo "[WARN] $SAMPLE: CONTIGS_BEFORE not found, skipping CHECKM2-b"
			update_status "$SAMPLE" "CHECKM2-b" "SKIPPED"
		fi

		# =========================
		# 5. FILTERING
		# =========================
		if is_skipped "FILTER"; then
			update_status "$SAMPLE" "FILTER" "SKIPPED"
		elif [[ -s "$CONTIGS_BEFORE" ]]; then
			# Run FILTER if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "FILTER" || [[ ! -s "$OUTFILTER" ]]; then
				update_status "$SAMPLE" "FILTER" "RUNNING"
				conda activate qassfilt_seqkit

				LOG_FILE="$LOG_DIR/${SAMPLE}_filter.log"
				TMP_OUT="${OUTFILTER}.tmp"

				# Filter by coverage
				seqkit fx2tab "$CONTIGS_BEFORE" | \
				awk -F "\t" -v cov="$SEQKIT_MIN_COV" '{
					header=$1
					seq=$2
					covval=""
					if (match(header, /_cov_([0-9]+\.?[0-9]*)/, arr)) covval=arr[1]
					else if (match(header, /_depth_([0-9]+\.?[0-9]*)/, arr)) covval=arr[1]
					if (covval != "" && covval+0 >= cov) print ">"header"\n"seq
				}' | seqkit seq -m "$SEQKIT_MIN_LENGTH" > "$TMP_OUT" 2>"$LOG_FILE"

				FILTER_EXIT=$?

				# If filtered output is empty, fallback to original
				if [[ $FILTER_EXIT -eq 0 ]]; then
					if [[ -s "$TMP_OUT" ]]; then
						mv "$TMP_OUT" "$OUTFILTER"
					else
						echo "[WARN] $SAMPLE: No contig passed coverage filter, keeping original input"
						cp "$CONTIGS_BEFORE" "$OUTFILTER"
						rm -f "$TMP_OUT"
					fi
					update_status "$SAMPLE" "FILTER" "OK"
				else
					rm -f "$TMP_OUT"  # clean up failed output
					update_status "$SAMPLE" "FILTER" "FAIL" "$LOG_FILE"
				fi

				conda deactivate
			fi
		else
			echo "[WARN] $SAMPLE: CONTIGS_BEFORE not found, skipping FILTER"
			update_status "$SAMPLE" "FILTER" "SKIPPED"
		fi

		# =========================
		# 6. QUAST AFTER FILTERING
		# =========================
		if is_skipped "QUAST-a"; then
			update_status "$SAMPLE" "QUAST-a" "SKIPPED"
		elif [[ -s "$OUTFILTER" ]]; then
			# Rerun QUAST if report missing or empty
			if should_run_step "$SAMPLE" "QUAST-a" || [[ ! -s "${OUTPUT_PATH}/quast_after/${SAMPLE}/report.tsv" ]]; then
				update_status "$SAMPLE" "QUAST-a" "RUNNING"
				conda activate qassfilt_quast
				local OUTDIR_QUAST="${OUTPUT_PATH}/quast_after/${SAMPLE}"
				mkdir -p "$OUTDIR_QUAST"

				if [[ -n "${QUAST_REFERENCE:-}" && -f "$QUAST_REFERENCE" ]]; then
					quast.py -o "$OUTDIR_QUAST" -t $QUAST_THREADS --reference "$QUAST_REFERENCE" "$OUTFILTER" \
						>"$LOG_DIR/${SAMPLE}_quast_after.log" 2>&1
				else
					quast.py -o "$OUTDIR_QUAST" -t $QUAST_THREADS "$OUTFILTER" \
						>"$LOG_DIR/${SAMPLE}_quast_after.log" 2>&1
				fi
				QUASTA_EXIT=$?
				conda deactivate

				[[ $QUASTA_EXIT -eq 0 ]] && update_status "$SAMPLE" "QUAST-a" "OK" || update_status "$SAMPLE" "QUAST-a" "FAIL" "$LOG_DIR/${SAMPLE}_quast_after.log"
			fi
		else
			echo "[WARN] $SAMPLE: FILTER output not found, skipping QUAST-a"
			update_status "$SAMPLE" "QUAST-a" "SKIPPED"
		fi


		# =========================
		# 7. CHECKM2 AFTER FILTERING
		# =========================
		if is_skipped "CHECKM2-a"; then
			update_status "$SAMPLE" "CHECKM2-a" "SKIPPED"
		elif [[ -s "$OUTFILTER" ]]; then
			# Run CHECKM2-a if OUTFILTER exists and step should run
			if should_run_step "$SAMPLE" "CHECKM2-a" || [[ ! -s "${OUTPUT_PATH}/checkm2_after/${SAMPLE}/quality_report.tsv" ]]; then
				update_status "$SAMPLE" "CHECKM2-a" "RUNNING"
				conda activate qassfilt_checkm2

				# -----------------------
				# Export CHECKM2DB with default fallback
				# -----------------------
				DEFAULT_CHECKM2DB="$HOME/databases/CheckM2_database"
				export CHECKM2DB="${CHECKM2DB_PATH:-${CHECKM2_DB:-$DEFAULT_CHECKM2DB}}"
				echo "[INFO] CHECKM2DB set to $CHECKM2DB"

				LOG_FILE="$LOG_DIR/${SAMPLE}_checkm2_after.log"
				DB_ARG="--database_path ${CHECKM2DB}/*.dmnd"

				checkm2 predict --threads "$CHECKM2_THREADS" \
					$DB_ARG \
					--input "$OUTFILTER" \
					--force \
					--output-directory "${OUTPUT_PATH}/checkm2_after/${SAMPLE}" \
					>"$LOG_FILE" 2>&1

				CHECKM2B_EXIT=$?
				conda deactivate

				[[ $CHECKM2B_EXIT -eq 0 ]] && update_status "$SAMPLE" "CHECKM2-a" "OK" || update_status "$SAMPLE" "CHECKM2-a" "FAIL" "$LOG_FILE"
			fi
		else
			echo "[WARN] $SAMPLE: OUTFILTER not found, skipping CHECKM2-a"
			update_status "$SAMPLE" "CHECKM2-a" "SKIPPED"
		fi
		
        # =========================
        # 8. KRAKEN2
        # =========================
        if [[ "${KRAKEN2_MODE:-0}" -eq 1 ]]; then
            if [[ -z "${KRAKEN2_DB_PATH:-}" || ! -d "${KRAKEN2_DB_PATH}" ]]; then
                # No database provided → mark both steps as SKIPPED
                update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
                update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
            else
                local KRAKENLOG="${LOG_DIR}/kraken2.log"
                mkdir -p "${OUTPUT_PATH}/kraken2/"

            # --- Run on CONTIGS_BEFORE ---
            local KRAKEN2_BEFORE_OUT="${OUTPUT_PATH}/kraken2/${SAMPLE}_before.output"
            local KRAKEN2_BEFORE_REPORT="${OUTPUT_PATH}/kraken2/${SAMPLE}_before.report"

            if is_skipped "KRAKEN2-b"; then
            update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
            elif [[ -s "$CONTIGS_BEFORE" ]]; then
            if should_run_step "$SAMPLE" "KRAKEN2-b" || [[ ! -s "$KRAKEN2_BEFORE_REPORT" ]] || [[ ! -s "$KRAKEN2_BEFORE_OUT" ]]; then
                update_status "$SAMPLE" "KRAKEN2-b" "RUNNING"
                conda activate qassfilt_kraken2 >/dev/null 2>&1 || true
                kraken2 \
                --db "$KRAKEN2_DB_PATH" \
                --threads "$KRAKEN2_THREADS" \
                --output "$KRAKEN2_BEFORE_OUT" \
                --report "$KRAKEN2_BEFORE_REPORT" \
                --use-names \
                "$CONTIGS_BEFORE" \
                >>"$KRAKENLOG" 2>&1
                [[ $? -eq 0 ]] && update_status "$SAMPLE" "KRAKEN2-b" "OK" || update_status "$SAMPLE" "KRAKEN2-b" "FAIL" "$KRAKENLOG"
                conda deactivate >/dev/null 2>&1 || true
            fi
            else
            update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
            fi

            # --- Run on OUTFILTER ---
            local KRAKEN2_AFTER_OUT="${OUTPUT_PATH}/kraken2/${SAMPLE}_after.output"
            local KRAKEN2_AFTER_REPORT="${OUTPUT_PATH}/kraken2/${SAMPLE}_after.report"

            if is_skipped "KRAKEN2-a"; then
            update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
            elif [[ -s "$OUTFILTER" ]]; then
            if should_run_step "$SAMPLE" "KRAKEN2-a" || [[ ! -s "$KRAKEN2_AFTER_REPORT" ]] || [[ ! -s "$KRAKEN2_AFTER_OUT" ]]; then
                update_status "$SAMPLE" "KRAKEN2-a" "RUNNING"
                conda activate qassfilt_kraken2 >/dev/null 2>&1 || true
                kraken2 \
                --db "$KRAKEN2_DB_PATH" \
                --threads "$KRAKEN2_THREADS" \
                --output "$KRAKEN2_AFTER_OUT" \
                --report "$KRAKEN2_AFTER_REPORT" \
                --use-names \
                "$OUTFILTER" \
                >>"$KRAKENLOG" 2>&1
                [[ $? -eq 0 ]] && update_status "$SAMPLE" "KRAKEN2-a" "OK" || update_status "$SAMPLE" "KRAKEN2-a" "FAIL" "$KRAKENLOG"
                conda deactivate >/dev/null 2>&1 || true
            fi
            else
            update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
            fi
            fi
        else
            update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
            update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
        fi
}
		# =========================
		# RUN PIPELINE FOR ALL SAMPLES SEQUENTIALLY
		# =========================
		for SAMPLE in "${SAMPLES[@]}"; do
			if [[ $CONTIG_MODE -eq 1 ]]; then
				R1=""
				R2=""
			else
				R1="${PAIRS["$SAMPLE,1"]:-}"
				R2="${PAIRS["$SAMPLE,2"]:-}"
			fi
			process_sample "$SAMPLE" "$R1" "$R2"
		done

		wait

        # =========================
        # 9. GTDBTK
        # =========================
        if [[ "${GTDBTK_MODE:-0}" -eq 1 ]]; then
            if [[ -z "${GTDBTK_DB_PATH:-}" || ! -d "${GTDBTK_DB_PATH}" ]]; then
                # No database → mark both steps as SKIPPED
                update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
                update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
            else
                GTDBTKLOG="${OUTPUT_PATH}/logs/gtdbtk.log"
                mkdir -p "${OUTPUT_PATH}/gtdbtk/"
                export GTDBTK_DATA_PATH="$GTDBTK_DB_PATH"

            # --- Run on CONTIGS_BEFORE ---
            CONTIGS_BEFORE="${OUTPUT_PATH}/contigs_before/"
            GTDBTK_BEFORE_DIR="${OUTPUT_PATH}/gtdbtk/before"
            if is_skipped "GTDBTK-b"; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
                done
            elif [[ -s "$CONTIGS_BEFORE" ]]; then
            if should_run_step "$SAMPLE" "GTDBTK-b" || [[ ! -s "${GTDBTK_BEFORE_DIR}/classify/gtdbtk.bac120.summary.tsv" ]]; then
                update_status "$SAMPLE" "GTDBTK-b" "RUNNING"
                conda activate qassfilt_gtdbtk >/dev/null 2>&1 || true
                gtdbtk classify_wf \
                --genome_dir "$CONTIGS_BEFORE" \
                --out_dir "$GTDBTK_BEFORE_DIR" \
                --cpus "$GTDBTK_THREADS" \
                --extension fasta \
                >>"$GTDBTKLOG" 2>&1
                    # Update GTDBTK-b status for all samples based on last command exit
                    if [[ $? -eq 0 ]]; then
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-b" "OK"
                        done
                    else
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-b" "FAIL" "$GTDBTKLOG"
                        done
                    fi

                    # Deactivate conda
                    conda deactivate >/dev/null 2>&1 || true
                    fi

                else
                    for SAMPLE in "${SAMPLES[@]}"; do
                        update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
                    done
                    fi

            # --- Run on OUTFILTER ---
            OUTFILTER="${OUTPUT_PATH}/contigs_filtered/"
            GTDBTK_AFTER_DIR="${OUTPUT_PATH}/gtdbtk/after"
            if is_skipped "GTDBTK-a"; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
                done
            elif [[ -s "$OUTFILTER" ]]; then
            if should_run_step "$SAMPLE" "GTDBTK-a" || [[ ! -s "${GTDBTK_AFTER_DIR}/classify/gtdbtk.bac120.summary.tsv" ]]; then
                update_status "$SAMPLE" "GTDBTK-a" "RUNNING"
                conda activate qassfilt_gtdbtk >/dev/null 2>&1 || true
                gtdbtk classify_wf \
                --genome_dir "$OUTFILTER" \
                --out_dir "$GTDBTK_AFTER_DIR" \
                --cpus "$GTDBTK_THREADS" \
                --extension fasta \
                >>"$GTDBTKLOG" 2>&1
                    # Update GTDBTK-a status for all samples based on last command exit
                    if [[ $? -eq 0 ]]; then
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-a" "OK"
                        done
                    else
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-a" "FAIL" "$GTDBTKLOG"
                        done
                    fi

                    # Deactivate conda
                    conda deactivate >/dev/null 2>&1 || true
                    fi

                else
                    for SAMPLE in "${SAMPLES[@]}"; do
                        update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
                    done
                    fi
                fi
            fi

# =========================
# 10. ABRITAMR
# =========================
if [[ "${ABRITAMR_MODE:-0}" -eq 1 ]]; then
    ABRITAMRLOG="${OUTPUT_PATH}/logs/abritamr.log"
    mkdir -p "${OUTPUT_PATH}/abritamr/"

    # --- Run on CONTIGS_BEFORE ---
    CONTIGS_BEFORE="${OUTPUT_PATH}/contigs_before/"
    ABRITAMR_BEFORE_OUT="${OUTPUT_PATH}/abritamr/before"
    mkdir -p "$ABRITAMR_BEFORE_OUT"

    if is_skipped "ABRITAMR-b"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-b" "SKIPPED"
        done
    elif [[ -d "$CONTIGS_BEFORE" && $(find "$CONTIGS_BEFORE" -name '*.fasta' | wc -l) -gt 0 ]]; then
        if should_run_step "$SAMPLE" "ABRITAMR-b" || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_matches.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_partials.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_virulence.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/abritamr.txt" ]]; then
            update_status "$SAMPLE" "ABRITAMR-b" "RUNNING"
            conda activate qassfilt_abritamr >/dev/null 2>&1 || true

            # Create .tab mapping file
            find "$CONTIGS_BEFORE" -type f -name "*.fasta" | awk -F/ '{
                file=$NF; sub(/\.[^.]+$/, "", file);
                print file "\t" $0
            }' > "${ABRITAMR_BEFORE_OUT}/abritamr_list_before.tab"

            (
                cd "$ABRITAMR_BEFORE_OUT" || exit 1
                abritamr run $ABRITAMR_EXTRA_OPTS \
                    --contigs "abritamr_list_before.tab" >>"$ABRITAMRLOG" 2>&1
            )

            # Update status for all samples
            if [[ $? -eq 0 ]]; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRITAMR-b" "OK"
                done
            else
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRITAMR-b" "FAIL" "$ABRITAMRLOG"
                done
            fi

            conda deactivate >/dev/null 2>&1 || true
        fi
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-b" "SKIPPED"
        done
    fi

    # --- Run on OUTFILTER ---
    OUTFILTER="${OUTPUT_PATH}/contigs_filtered/"
    ABRITAMR_AFTER_OUT="${OUTPUT_PATH}/abritamr/after"
    mkdir -p "$ABRITAMR_AFTER_OUT"

    if is_skipped "ABRITAMR-a"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-a" "SKIPPED"
        done
    elif [[ -d "$OUTFILTER" && $(find "$OUTFILTER" -name '*.fasta' | wc -l) -gt 0 ]]; then
        if should_run_step "$SAMPLE" "ABRITAMR-a" || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_matches.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_partials.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_virulence.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/abritamr.txt" ]]; then
            update_status "$SAMPLE" "ABRITAMR-a" "RUNNING"
            conda activate qassfilt_abritamr >/dev/null 2>&1 || true

            # Create .tab mapping file
            find "$OUTFILTER" -type f -name "*.fasta" | awk -F/ '{
                file=$NF; sub(/\.[^.]+$/, "", file);
                print file "\t" $0
            }' > "${ABRITAMR_AFTER_OUT}/abritamr_list_after.tab"

            (
                cd "$ABRITAMR_AFTER_OUT" || exit 1
                abritamr run $ABRITAMR_EXTRA_OPTS \
                    --contigs "abritamr_list_after.tab" >>"$ABRITAMRLOG" 2>&1
            )

            # Update status for all samples
            if [[ $? -eq 0 ]]; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRITAMR-a" "OK"
                done
            else
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRITAMR-a" "FAIL" "$ABRITAMRLOG"
                done
            fi

            conda deactivate >/dev/null 2>&1 || true
        fi
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-a" "SKIPPED"
        done
    fi
fi

# =========================
# 11. ABRICATE
# =========================
if [[ "${ABRICATE_MODE:-0}" -eq 1 ]]; then
    ABRICATELOG="${OUTPUT_PATH}/logs/abricate.log"
    mkdir -p "${OUTPUT_PATH}/abricate/"

    # --- Run on CONTIGS_BEFORE ---
    CONTIGS_BEFORE=( "${OUTPUT_PATH}/contigs_before/"*.fasta )
    ABRICATE_BEFORE_PREFIX="${OUTPUT_PATH}/abricate/before"

    if is_skipped "ABRICATE-b"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-b" "SKIPPED"
        done
    elif (( ${#CONTIGS_BEFORE[@]} > 0 )); then
        if should_run_step "$SAMPLE" "ABRICATE-b" || [[ ! -s "${OUTPUT_PATH}/abricate/before_plasmidfinder.summary.tsv" ]]; then
            update_status "$SAMPLE" "ABRICATE-b" "RUNNING"
            conda activate qassfilt_abricate >/dev/null 2>&1 || true

            ABRICATE_DBS=$(abricate --list | awk 'NR>1 {print $1}')
            for DB in $ABRICATE_DBS; do
                DB_PREFIX="${ABRICATE_BEFORE_PREFIX}_${DB}"
                echo "[$(date '+%F %T')] Running ABRICATE (before) with database: $DB" >>"$ABRICATELOG"
                abricate $ABRICATE_EXTRA_OPTS --db "$DB" "${CONTIGS_BEFORE[@]}" > "${DB_PREFIX}.tsv" 2>>"$ABRICATELOG"

                if [[ -s "${DB_PREFIX}.tsv" ]]; then
                    abricate --summary "${DB_PREFIX}.tsv" > "${DB_PREFIX}.summary.tsv" 2>>"$ABRICATELOG"
                else
                    echo "⚠️ No hits found for $DB (before) — summary skipped" >>"$ABRICATELOG"
                fi
            done

            # Update status for all samples
            if [[ $? -eq 0 ]]; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRICATE-b" "OK"
                done
            else
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRICATE-b" "FAIL" "$ABRICATELOG"
                done
            fi

            conda deactivate >/dev/null 2>&1 || true
        fi
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-b" "SKIPPED"
        done
    fi

    # --- Run on OUTFILTER ---
    OUTFILTER=( "${OUTPUT_PATH}/contigs_filtered/"*.fasta )
    ABRICATE_AFTER_PREFIX="${OUTPUT_PATH}/abricate/after"

    if is_skipped "ABRICATE-a"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-a" "SKIPPED"
        done
    elif (( ${#OUTFILTER[@]} > 0 )); then
        if should_run_step "$SAMPLE" "ABRICATE-a" || [[ ! -s "${OUTPUT_PATH}/abricate/after_plasmidfinder.summary.tsv" ]]; then
            update_status "$SAMPLE" "ABRICATE-a" "RUNNING"
            conda activate qassfilt_abricate >/dev/null 2>&1 || true

            ABRICATE_DBS=$(abricate --list | awk 'NR>1 {print $1}')
            for DB in $ABRICATE_DBS; do
                DB_PREFIX="${ABRICATE_AFTER_PREFIX}_${DB}"
                echo "[$(date '+%F %T')] Running ABRICATE (after) with database: $DB" >>"$ABRICATELOG"
                abricate $ABRICATE_EXTRA_OPTS --db "$DB" "${OUTFILTER[@]}" > "${DB_PREFIX}.tsv" 2>>"$ABRICATELOG"

                if [[ -s "${DB_PREFIX}.tsv" ]]; then
                    abricate --summary "${DB_PREFIX}.tsv" > "${DB_PREFIX}.summary.tsv" 2>>"$ABRICATELOG"
                else
                    echo "⚠️ No hits found for $DB (after) — summary skipped" >>"$ABRICATELOG"
                fi
            done

            # Update status for all samples
            if [[ $? -eq 0 ]]; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRICATE-a" "OK"
                done
            else
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "ABRICATE-a" "FAIL" "$ABRICATELOG"
                done
            fi

            conda deactivate >/dev/null 2>&1 || true
        fi
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-a" "SKIPPED"
        done
    fi
fi

		# =========================
		#12. MULTIQC - combined & separate reports
		# =========================
		if is_skipped "MULTIQC"; then
			for SAMPLE in "${SAMPLES[@]}"; do
				update_status "$SAMPLE" "MULTIQC" "SKIPPED"
			done
		elif should_run_step "$SAMPLE" "MULTIQC" || [[ ! -d "${OUTPUT_PATH}/multiqc_reports" ]]; then
			update_status "$SAMPLE" "MULTIQC" "RUNNING"
			conda activate qassfilt_multiqc

			LOG_FILE="${OUTPUT_PATH}/logs/multiqc.log"
			mkdir -p "${OUTPUT_PATH}/logs"
			mkdir -p "${OUTPUT_PATH}/multiqc_reports"

			RUN_ANY=0

			# --- Fastp MultiQC ---
			if [[ -d "${OUTPUT_PATH}/fastp_file" ]]; then
				mkdir -p "${OUTPUT_PATH}/multiqc_reports/fastp"

				# Path to MultiQC config
				FASTP_CONFIG="${OUTPUT_PATH}/multiqc_fastp_config.yaml"

        cat > "$FASTP_CONFIG" <<'EOF'
# Clean up sample names (_1, _2, .fastq.gz, etc.)
extra_fn_clean_exts:
  - "_1"
  - "_2"
  - "_R1"
  - "_R2"
  - ".fastq.gz"
  - ".fq.gz"

custom_data:
  fastp_extra:
    file_format: json
    file_regex: ".*_fastp.json"
    plot_type: table
    pconfig:
      id: "fastp_extra"
      title: "Additional Fastp Parameters"
      descrition: "Extra quality metrics extracted from fastp output"
      headers:
        q20_rate: "Q20 Rate"
        q30_rate: "Q30 Rate"
        read1_mean_length: "Read1 Mean Length"
        read2_mean_length: "Read2 Mean Length"
        gc_content: "GC Content"
    data:
      - name: "before_filtering"
        path: "before_filtering/q20_rate"
      - name: "before_filtering"
        path: "before_filtering/q30_rate"
      - name: "before_filtering"
        path: "before_filtering/read1_mean_length"
      - name: "before_filtering"
        path: "before_filtering/read2_mean_length"
      - name: "before_filtering"
        path: "before_filtering/gc_content"
      - name: "after_filtering"
        path: "after_filtering/q20_rate"
      - name: "after_filtering"
        path: "after_filtering/q30_rate"
      - name: "after_filtering"
        path: "after_filtering/read1_mean_length"
      - name: "after_filtering"
        path: "after_filtering/read2_mean_length"
      - name: "after_filtering"
        path: "after_filtering/gc_content"
EOF

        multiqc "${OUTPUT_PATH}/fastp_file" \
            -o "${OUTPUT_PATH}/multiqc_reports/fastp" \
            --title "QAssfilt Fastp Quality Report" \
            -c "$FASTP_CONFIG" \
            --force \
            --module fastp \
            >"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    # --- Combined QC MultiQC (QUAST + CheckM2) ---
    QC_DIRS=()
    [[ -d "${OUTPUT_PATH}/quast_before" ]]   && QC_DIRS+=("${OUTPUT_PATH}/quast_before")
    [[ -d "${OUTPUT_PATH}/quast_after" ]]    && QC_DIRS+=("${OUTPUT_PATH}/quast_after")
    [[ -d "${OUTPUT_PATH}/checkm2_before" ]] && QC_DIRS+=("${OUTPUT_PATH}/checkm2_before")
    [[ -d "${OUTPUT_PATH}/checkm2_after" ]]  && QC_DIRS+=("${OUTPUT_PATH}/checkm2_after")

    if [[ ${#QC_DIRS[@]} -gt 0 ]]; then
        mkdir -p "${OUTPUT_PATH}/multiqc_reports/Assembly_qc"
        multiqc "${QC_DIRS[@]}" \
            -o "${OUTPUT_PATH}/multiqc_reports/Assembly_qc" \
            --title "QAssfilt Assembly Quality Report (QUAST + CheckM2)" \
            --force \
            >>"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    # --- Kraken2 MultiQC ---
    if [[ -d "${OUTPUT_PATH}/kraken2" ]]; then
        mkdir -p "${OUTPUT_PATH}/multiqc_reports/kraken2"
        multiqc "${OUTPUT_PATH}/kraken2" \
            -o "${OUTPUT_PATH}/multiqc_reports/kraken2" \
            --title "QAssfilt Kraken2 Report" \
            --force \
            >>"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    # --- GTDB-Tk MultiQC ---
    if [[ -d "${OUTPUT_PATH}/gtdbtk" ]]; then
        mkdir -p "${OUTPUT_PATH}/multiqc_reports/gtdbtk"
        multiqc "${OUTPUT_PATH}/gtdbtk" \
            -o "${OUTPUT_PATH}/multiqc_reports/gtdbtk" \
            --title "QAssfilt GTDB-Tk Report" \
            --force \
            >>"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    MQ_EXIT=$?
    conda deactivate

    if [[ $RUN_ANY -eq 1 && $MQ_EXIT -eq 0 ]]; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "MULTIQC" "OK"
        done
    elif [[ $RUN_ANY -eq 0 ]]; then
        # Nothing to report
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "MULTIQC" "SKIPPED"
        done
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "MULTIQC" "FAIL" "$LOG_FILE"
        done
    fi
fi

# =========================
# END TIMER + FINAL STATUS
# =========================
clear   # clear screen before showing final status

echo "QAssfilt Pipeline final status:"
column -t -s$'\t' "$STATUS_FILE"
echo ""
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
echo "Total runtime: ${RUNTIME} seconds (~$(printf '%02d:%02d:%02d\n' \
     $((RUNTIME/3600)) $(((RUNTIME/60)%60)) $((RUNTIME%60))))"
echo ""
echo "----------------------------------------------------------"
echo "               QAssfilt Pipeline completed!"
echo ""
printf "%-18s : %s\n" "Path to QAssfilt output"              "${OUTPUT_PATH}"
echo ""
echo "All rights reserved. © 2025 QAssfilt, Samrach Han"
echo "----------------------------------------------------------"
