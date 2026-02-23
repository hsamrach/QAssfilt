#!/usr/bin/env bash

#All rights reserved. © 2025 QAssfilt, Samrach Han

set -eo pipefail

cleanup() {

    trap - SIGINT SIGTERM

    kill -TERM -- -$$ 2>/dev/null
    sleep 2
    kill -KILL -- -$$ 2>/dev/null

    exit 130
}

trap cleanup SIGINT SIGTERM

# =========================
# CONFIGURATION WITH DEFAULTS
# =========================
SOURCE_CONDA=""
INPUT_PATH=""
OUTPUT_PATH=""
INPUT_DIR_DEPTH=1
THREADS=8
QUAST_REFERENCE=""
GTDBTK_THREADS=8
SEQKIT_MIN_COV=10
SEQKIT_MIN_LENGTH=500
SKIP_STEPS=()
CONTIG_MODE=0
COMPETITIVE_MODE=0
INIT_MODE=0
VERSION_QAssfilt=1.3.7
KRAKEN2_DB_PATH=""
GTDBTK_DB_PATH=""
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
        --initial|-ini) INIT_MODE="1"; shift  ;;
        --source_conda|-sc) SOURCE_CONDA="$2"; shift 2 ;;
        --input_path|-i) INPUT_PATH="$2"; shift 2 ;;
        --contigs|-cg) CONTIG_MODE="1"; shift  ;;
        --competitive|-cp) COMPETITIVE_MODE="1"; shift ;;
        --output_path|-o) OUTPUT_PATH="$2"; shift 2 ;;
        --input_dir_depth|-id) INPUT_DIR_DEPTH="$2"; shift 2 ;;
        --checkm2_db_path|-cd) CHECKM2DB_PATH="$2"; shift 2 ;;
        --kraken2_db_path|-kd) KRAKEN2_DB_PATH="$2"; shift 2 ;;
        --gtdbtk_db_path|-gd) GTDBTK_DB_PATH="$2"; shift 2 ;;
        --threads|-t) THREADS="$2"; shift 2 ;;
        --gtdbtk_threads|-gt) GTDBTK_THREADS="$2"; shift 2 ;;
        --quast_reference|-qr) QUAST_REFERENCE="$2"; shift 2 ;;
        --filter_min_cov|-mc) SEQKIT_MIN_COV="$2"; shift 2 ;;
        --filter_min_length|-ml) SEQKIT_MIN_LENGTH="$2"; shift 2 ;;
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
            echo "  --initial, -ini            		Initialize QAssfilt, including checking and installing environments and tools (obligated for the first time)"
            echo "  --source_conda, -sc [dir]      	Path to source conda environment (optional; if not given, pipeline will use default)"
            echo "                                        e.g.: --source_conda, -sc /home/user/miniconda3/"
            echo "  --input_path, -i [dir]          	Path to directory containing fastq file (Apply for all Illumina paired end reads)"
            echo "  --contigs, -cg            		Enable contig mode (flag option)"
            echo "                             		This will scan for fasta (.fa .fasta .fas .fna .ffn) in input_path"
            echo "  --competitive, -cp           		Enable competitive mode (flag option)"
            echo "  --output_path, -o [dir]         	Path to output directory"
            echo "  --input_dir_depth, -id [N]    	Define directories to be scanned for fastq file (default: $INPUT_DIR_DEPTH)"
            echo "                             		e.g.: -id 1 will scan for only files in input_path directory"
            echo "                             		e.g.: -id 2 will scan all files in input_path subdirectories"
            echo "  --checkm2_db_path, -cd [dir]      	Path to CheckM2 database directory (optional; if not given, pipeline will auto-manage)"
            echo "  --kraken2_db_path, -kd [dir]      	Providing path to KRAKEN2 database directory to enable kraken2 step (default: disable)"
            echo "  --gtdbtk_db_path, -gd [dir]      	Providing path to GTDBTK database directory to enable gtdbtk step (default: disable)"
            echo "  --threads, -t [N]  	                Number of threads for fastp, spades, quast, checkm2, and kraken2 (default: $THREADS)"
            echo "  --gtdbtk_threads, -gt [N]      	Threads for GTDBTK (default: $GTDBTK_THREADS)"
            echo "  --quast_reference, -qr [file]   	Path to reference sequence for QUAST (optional)"
            echo "  --filter_min_cov, -mc [N]     	Minimum (≤) contig coverage to be filtered (default: $SEQKIT_MIN_COV)"
            echo "  --filter_min_length, -ml [N]  	Minimum (≤) contig length to be filtered (default: $SEQKIT_MIN_LENGTH)"
            echo "  --skip [list]                 	Skip tool(s) you don't want to use in the pipeline (space-separated)"
            echo "                             		e.g.: --skip \"FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a"
            echo "                             		ABRITAMR-b ABRITAMR-a ABRICATE-b ABRICATE-a MULTIQC\""
            echo "  --contigs_remove, -cr [file]   	A tab-delimited file with path to fasta file (column1) and contig NODE (column2, separated by comma if multiple)."
            echo "  --fastp [string]                	Options/parameters to pass directly to fastp"
            echo "                             		e.g.: \"-q 30 -u 30 -e 15 -l 50 -5 -3, ...\""
            echo "  --spades [string]               	Options/parameters to pass directly to SPAdes"
            echo "                             		e.g.: \"-k 77 --isolate --careful --cov-cutoff auto, ...\""
            echo "  --abricate [string]             	Options/parameters to pass directly to abricate, except \"--db\" to enable abricate step (default: disable)"
            echo "                             		e.g.: Use at least an option to enable abricate \"--minid 80, --mincov 80, --threads 8,...\""
            echo "  --abritamr [string]             	Options/parameters to pass directly to abritamr to enable abritamr step (default: disable)"
            echo "                             		e.g.: Use at least an option to enable abritamr \"--species Escherichia, -j 8,...\""
            echo "  --version, -v              		Show QAssfilt version and exit"
            echo "  --help, -h                 		Show this help message and exit"
            echo ""
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Search for conda.sh in common locations
for d in \
    $SOURCE_CONDA \
    /opt/miniconda* \
    /opt/anaconda* \
    /opt/miniforge* \
    /opt/mambaforge \
    /opt/conda \
    $HOME/miniconda* \
    $HOME/anaconda* \
    $HOME/conda \
    $HOME/miniforge* \
    $HOME/mambaforge \
    /usr/local/miniconda* \
    /usr/local/anaconda* \
    /usr/local/miniforge* \
    /usr/local/mambaforge \
    /usr/local/conda
do
    if [ -f "$d/etc/profile.d/conda.sh" ]; then
        source "$d/etc/profile.d/conda.sh"
        found=1
        break
    fi
done

# If nothing was found
if [ -z "$found" ]; then
    echo "⚠️  Could not find conda.sh — please check your Conda installation."
    exit 1
fi

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
    # ======================================
    # 1. Mark explicitly skipped steps
    # ======================================
    for step in "${SKIP_STEPS[@]}"; do
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "$step" "SKIPPED"
        done
    done

    # ======================================
    # 2. Handle module enable/disable
    # ======================================
    for TOOL in ABRITAMR ABRICATE KRAKEN2 GTDBTK; do
        local MODE_VAR="${TOOL}_MODE"

        for SAMPLE in "${SAMPLES[@]}"; do
            for substep in b a; do
                local STEP_NAME="${TOOL}-${substep}"
                local CURRENT_STATUS=$(awk -v s="$SAMPLE" -v step="$STEP_NAME" '$1==s && $2==step {print $3}' "$STATUS_FILE")

                if [[ "${!MODE_VAR:-0}" -eq 0 ]]; then
                    # Tool disabled → mark SKIPPED
                    update_status "$SAMPLE" "$STEP_NAME" "SKIPPED"
                elif [[ "$CURRENT_STATUS" == "SKIPPED" ]]; then
                    # Tool re-enabled → reset to pending
                    update_status "$SAMPLE" "$STEP_NAME" "-"
                fi
            done
        done
    done
}

# =========================
# Validate / normalize output path and define STATUS_FILE
# =========================
OUTPUT_PATH="${OUTPUT_PATH:-.}"
mkdir -p "$OUTPUT_PATH"
STATUS_FILE="${OUTPUT_PATH}/pipeline_status.tsv"

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

            # Special environments without Python
            if [[ "$ENV" == "qassfilt_abricate" || "$ENV" == "qassfilt_abritamr" || "$ENV" == "qassfilt_gtdbtk" || "$ENV" == "qassfilt_kraken2" ]]; then
                if ! conda env list | awk '{print $1}' | grep -x "${ENV}" >/dev/null; then
                    echo "[INFO] Environment '$ENV' not found. Creating $ENV..."
                    mamba create -y -n "$ENV" \
                        || { echo "❌ Failed to create env $ENV"; exit 1; }
                else
                    echo "✅ Environment '$ENV' exists."
                fi
            else
            # Regular environment creation (includes Python)
            if ! conda env list | awk '{print $1}' | grep -x "${ENV}" >/dev/null; then
                echo "[INFO] Environment '$ENV' not found. Creating..."
                mamba create -y -n "$ENV" python=3.12 \
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
                    echo "[INFO] Installing fastp v${fastp_version} in $ENV..."
                    mamba install -n qassfilt_fastp -c defaults -c conda-forge -c bioconda -y fastp=${fastp_version} || { echo "❌ Failed to install fastp"; exit 1; }
                    ;;

                spades.py)
                    spades_version="1.1.0"

                    echo "[INFO] Installing SPAdes v${spades_version} in $ENV..."
                    mamba install -n qassfilt_spades -c defaults -c conda-forge -c bioconda -y spades=4.2.0 || { echo "❌ Failed to install SPAdes"; exit 1; }
                    ;;

                quast.py)
                    quast_version="5.3.0"
                    echo "[INFO] Installing QUAST v${quast_version} in $ENV..."
                    mamba install -n qassfilt_quast -c defaults -c conda-forge -c bioconda -y quast=${quast_version} || { echo "❌ Failed to install QUAST"; exit 1; }
                    ;;

                checkm2)
                    checkm2_version="1.1.0"

                    echo "[INFO] Installing CheckM2 v${checkm2_version} in $ENV..."

                    mamba install -y -n "$ENV" -c defaults -c conda-forge -c bioconda checkm2=${checkm2_version} || { echo "❌ Failed to install CheckM2"; exit 1; }

                    ;;

                seqkit)
                    seqkit_version="2.10.1"
                    echo "[INFO] Installing SeqKit v${seqkit_version} in $ENV..."

                    mamba install -n qassfilt_seqkit -c defaults -c conda-forge -c bioconda -y seqkit=${seqkit_version} || { echo "❌ Failed to install SeqKit"; exit 1; }
                    ;;

                abritamr)
                    abritamr_version="1.0.20"

                    echo "[INFO] Installing ABRITAMR v${abritamr_version} in $ENV..."

                    mamba install -y -n "$ENV" -c defaults -c conda-forge -c bioconda abritamr=${abritamr_version} || { echo "❌ Failed to install ABRITAMR"; exit 1; }

                    ;;

                abricate)
                    abricate_version="1.0.1"
                    echo "[INFO] Installing ABRicate v${abricate_version} in $ENV..."

                    mamba install -y -n "$ENV" -c defaults -c bioconda -c conda-forge abricate=${abricate_version} || { echo "❌ Failed to install ABRicate"; exit 1; }

                    ;;

                multiqc)
                    multiqc_version="1.31"
                    echo "[INFO] Installing MultiQC v${multiqc_version} in $ENV..."
                    mamba install -n qassfilt_multiqc -c defaults -c conda-forge -c bioconda -y multiqc=${multiqc_version} || { echo "❌ Failed to install MultiQC"; exit 1; }
                    ;;

                kraken2)
                    kraken2_version="2.1.6"
                    echo "[INFO] Installing Kraken2 v${kraken2_version} in $ENV..."

                    mamba install -y -n "$ENV" -c defaults -c conda-forge -c bioconda kraken2=${kraken2_version} || { echo "❌ Failed to install Kraken2"; exit 1; }

                    ;;

                gtdbtk)
                    gtdbtk_version="2.5.2"
                    echo "[INFO] Installing GTDB-Tk v${gtdbtk_version} in $ENV..."

                    mamba install -y -n "$ENV" -c defaults -c conda-forge -c bioconda gtdbtk=${gtdbtk_version} python=3.11 || { echo "❌ Failed to install GTDB-Tk"; exit 1; }

                    ;;
            esac
            echo "✅ $TOOL installed in $ENV."
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
                    conda activate qassfilt_checkm2 >/dev/null 2>&1 || conda activate qassfilt_checkm2 >/dev/null 2>&1 || { echo "❌ Failed to activate qassfilt_checkm2"; exit 1; }
                    echo "[WARN] CheckM2 DB not found, downloading..."
                    checkm2 database --download
                else
                    echo "✅ Found CheckM2 DB in $CHECKM2_DB"
                fi
            fi
        fi

        conda deactivate >/dev/null 2>&1 || true
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
    wait
    echo "QAssfilt initialization completed. Exiting."
    exit 0
fi

if [[ "${CONTIG_MODE:-0}" -eq 1 ]]; then
    CONTIG_MODE_DISPLAY="Enabled"
else
    CONTIG_MODE_DISPLAY="Disabled"
fi

if [[ "${COMPETITIVE_MODE:-0}" -eq 1 ]]; then
    COMPETITIVE_MODE_DISPLAY="Enabled"
else
    COMPETITIVE_MODE_DISPLAY="Disabled"
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
    echo "    SOURCE_CONDA          = $SOURCE_CONDA"
    echo "    INPUT_PATH            = $(realpath -m "$INPUT_PATH")"
    echo "    CONTIG_MODE           = ${CONTIG_MODE_DISPLAY}"
    echo "    COMPETITIVE_MODE      = ${COMPETITIVE_MODE_DISPLAY}"
    echo -n "    KRAKEN2_MODE          = $KRAKEN2_MODE_DISPLAY"
    [[ -n "$KRAKEN2_DB_PATH" ]] && echo -n " (DB: $KRAKEN2_DB_PATH)"
    echo

    echo -n "    GTDBTK_MODE           = $GTDBTK_MODE_DISPLAY"
    [[ -n "$GTDBTK_DB_PATH" ]] && echo -n " (DB: $GTDBTK_DB_PATH)"
    echo

    echo -n "    ABRITAMR_MODE         = $ABRITAMR_MODE_DISPLAY"
    [[ -n "$ABRITAMR_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRITAMR_EXTRA_OPTS)"
    echo

    echo -n "    ABRICATE_MODE         = $ABRICATE_MODE_DISPLAY"
    [[ -n "$ABRICATE_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRICATE_EXTRA_OPTS)"
    echo

    echo "    INPUT_DIR_DEPTH       = $INPUT_DIR_DEPTH"
    echo "    CHECKM2DB_PATH        = $CHECKM2DB_PATH"
    echo "    OUTPUT_PATH           = $(realpath -m "$OUTPUT_PATH")"
    echo "    THREADS               = $THREADS"
    echo "    GTDBTK_THREADS        = $GTDBTK_THREADS"
    echo "    QUAST_REFERENCE       = $QUAST_REFERENCE"
    echo "    SEQKIT_MIN_COV        = $SEQKIT_MIN_COV"
    echo "    SEQKIT_MIN_LENGTH     = $SEQKIT_MIN_LENGTH"
    echo "    SKIP_STEPS            = ${SKIP_STEPS[*]}"
    echo "    FASTP_EXTRA_OPTS      = $FASTP_EXTRA_OPTS"
    echo "    SPADES_EXTRA_OPTS     = $SPADES_EXTRA_OPTS"
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
            ROW=("-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-" "-")
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
if [[ -t 1 && ( "$STATUS" == "RUNNING" || "$STATUS" == "FAIL" ) ]]; then
    {
        flock -n 201 || return 0
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
    echo -e "  SOURCE_CONDA        : $SOURCE_CONDA"
    echo -e "  INPUT_PATH          : $(realpath -m "$INPUT_PATH")"
    echo -e "  INPUT_DIR_DEPTH     : ${CYAN}$INPUT_DIR_DEPTH${RESET}"
    echo -e "  OUTPUT_PATH         : $(realpath -m "$OUTPUT_PATH")"
    echo -e "  CHECKM2DB_PATH      : $CHECKM2DB_PATH"
    echo -e "  CONTIG_MODE         : $CONTIG_MODE_DISPLAY"
    echo -e "  COMPETITIVE_MODE    : $COMPETITIVE_MODE_DISPLAY"
    echo -n "  KRAKEN2_MODE        : $KRAKEN2_MODE_DISPLAY"
    [[ -n "$KRAKEN2_DB_PATH" ]] && echo -n " (DB: $KRAKEN2_DB_PATH)"
    echo

    echo -n "  GTDBTK_MODE         : $GTDBTK_MODE_DISPLAY"
    [[ -n "$GTDBTK_DB_PATH" ]] && echo -n " (DB: $GTDBTK_DB_PATH)"
    echo

    echo -n "  ABRITAMR_MODE       : $ABRITAMR_MODE_DISPLAY"
    [[ -n "$ABRITAMR_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRITAMR_EXTRA_OPTS)"
    echo

    echo -n "  ABRICATE_MODE       : $ABRICATE_MODE_DISPLAY"
    [[ -n "$ABRICATE_EXTRA_OPTS" ]] && echo -n " (Opts: $ABRICATE_EXTRA_OPTS)"
    echo
    echo -e "  THREADS             : ${CYAN}$THREADS${RESET}"
	echo -e "  GTDBTK_THREADS      : ${CYAN}$GTDBTK_THREADS${RESET}"
    echo -e "  QUAST_REFERENCE     : $QUAST_REFERENCE"
    echo -e "  SEQKIT_MIN_COV      : ${CYAN}$SEQKIT_MIN_COV${RESET}"
    echo -e "  SEQKIT_MIN_LENGTH   : ${CYAN}$SEQKIT_MIN_LENGTH${RESET}"
    echo -e "  SKIP_STEPS          : ${SKIP_STEPS[*]}"
    echo -e "  FASTP_EXTRA_OPTS    : ${CYAN}$FASTP_EXTRA_OPTS${RESET}"
    echo -e "  SPADES_EXTRA_OPTS   : ${CYAN}$SPADES_EXTRA_OPTS${RESET}"
	echo -e "  Sample list         : $(realpath -m "$OUTPUT_PATH")/pipeline_status.tsv"
	echo -e "  Detail logs         : $(realpath -m "$OUTPUT_PATH")/logs"
	echo -e "  Remark              : Press Ctrl+C to abort the run safely!"
    echo -e "================================================"
    echo -e "           >>> PROCESSING STATUS <<<"
    echo -e "================================================"
    if [[ -f "$STATUS_FILE" ]]; then
        TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))

    RUNNED=$(awk '
        NR>1 {
            if($2 != "-" && $2 != "SKIPPED" || $3 != "-" && $3 != "SKIPPED")
                count++
        }
        END { print count+0 }
    ' "$STATUS_FILE")

        echo -e "  Stage 1 progress (FASTP - SPADES): ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
    fi

    if [[ -f "$STATUS_FILE" ]]; then
    TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))

    RUNNED=$(awk '
        NR>1 {
            if($4 != "-" && $4 != "SKIPPED" || $5 != "-" && $5 != "SKIPPED" || $6 != "-" && $6 != "SKIPPED")
                count++
        }
        END { print count+0 }
    ' "$STATUS_FILE")

    echo -e "  Stage 2 progress (QUAST-b - CHECKM2-b - FILTER): ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
    fi

    if [[ -f "$STATUS_FILE" ]]; then
        TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))

    RUNNED=$(awk '
        NR>1 {
            if($7 != "-" && $7 != "SKIPPED" || $8 != "-" && $8 != "SKIPPED")
                count++
        }
        END { print count+0 }
    ' "$STATUS_FILE")

        echo -e "  Stage 3 progress (QUAST-a - CHECKM2-a): ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
    fi

    if [[ -f "$STATUS_FILE" ]]; then
        TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))

    RUNNED=$(awk '
        NR>1 {
            if($9 != "-" && $9 != "SKIPPED" || $10 != "-" && $10 != "SKIPPED")
                count++
        }
        END { print count+0 }
    ' "$STATUS_FILE")

        echo -e "  Stage 4 progress (KRAKEN2-b - KRAKEN2-a): ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
    fi
    
    if [[ -f "$STATUS_FILE" ]]; then
        TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))

        RUNNED=$(awk '
        ' "$STATUS_FILE")

        echo -e "  Stage 5 batch analysis (GTDBTK-b - GTDBTK-a - ABRITAMR-b - ABRITAMR-a - ABRICATE-b - ABRICATE-a - MULTIQC) "
    fi
    # -------------------------
    # Print current sample vertically
    # -------------------------
    grep "^$SAMPLE" "$STATUS_FILE" | while IFS=$'\t' read -r sample fastp spades quastb checkm2b filter quasta checkm2a kraken2b kraken2a gtdbtkb gtdbtka abritamrb abritamra abricateb abricatea multiqc; do
          echo -e "  Sample analyzing    : ${CYAN}${sample}${RESET}"
          echo -e ""
          printf "%-21s : %s\n" "  FASTP" "$fastp"
          printf "%-21s : %s\n" "  SPADES" "$spades"
          printf "%-21s : %s\n" "  QUAST-b" "$quastb"
          printf "%-21s : %s\n" "  CHECKM2-b" "$checkm2b"
          printf "%-21s : %s\n" "  FILTER" "$filter"
          printf "%-21s : %s\n" "  QUAST-a" "$quasta"
          printf "%-21s : %s\n" "  CHECKM2-a" "$checkm2a"
          printf "%-21s : %s\n" "  KRAKEN2-b" "$kraken2b"
          printf "%-21s : %s\n" "  KRAKEN2-a" "$kraken2a"
          printf "%-21s : %s\n" "  GTDBTK-b" "$gtdbtkb"
          printf "%-21s : %s\n" "  GTDBTK-a" "$gtdbtka"
          printf "%-21s : %s\n" "  ABRITAMR-b" "$abritamrb"
          printf "%-21s : %s\n" "  ABRITAMR-a" "$abritamra"
          printf "%-21s : %s\n" "  ABRICATE-b" "$abricateb"
          printf "%-21s : %s\n" "  ABRICATE-a" "$abricatea"
          printf "%-21s : %s\n" "  MULTIQC" "$multiqc"
          echo -e "------------------------------------------------"
    done
        } 201>/tmp/qassfilt_screen.lock
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

    # Check if the step is skipped
    if is_skipped "$STEP"; then
        # Step explicitly skipped by user → mark SKIPPED
        update_status "$SAMPLE" "$STEP" "SKIPPED"
        return 1  # do not run
    else
        # Step is not in SKIP_STEPS → if currently marked SKIPPED, reset to pending
        current_status=$(get_status "$SAMPLE" "$STEP")
        if [[ "$current_status" == "SKIPPED" ]]; then
            update_status "$SAMPLE" "$STEP" "-"
        fi
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
    CONTIG_BEFORE_DIR="${OUTPUT_PATH}/contigs_before"
    mkdir -p "$CONTIG_BEFORE_DIR"

    while IFS= read -r -d '' FILE; do
        BASENAME=${FILE##*/}          # Faster than basename
        SAMPLE="${BASENAME%.*}"

        CONTIG_PATHS["$SAMPLE"]="$FILE"
        SAMPLES+=("$SAMPLE")

        cp -f "$FILE" "$CONTIG_BEFORE_DIR/$BASENAME"

    done < <(
        find "$INPUT_PATH" -maxdepth "$INPUT_DIR_DEPTH" -type f \
            \( -iname "*.fa" -o -iname "*.fasta" -o -iname "*.fna" -o -iname "*.fas" -o -iname "*.ffn" \) \
            -print0
    )

else
declare -A PAIRS
declare -A SAMPLE_SEEN

while IFS= read -r -d '' file; do
    BASENAME=${file##*/}

    if [[ "$BASENAME" =~ ^(.+)[._-]R?1(_[0-9]{3})?\.f(ast)?q(\.gz)?$ ]]; then
        SAMPLE="${BASH_REMATCH[1]}"
        PAIRS["$SAMPLE,1"]="$file"
        SAMPLE_SEEN["$SAMPLE"]=1

    elif [[ "$BASENAME" =~ ^(.+)[._-]R?2(_[0-9]{3})?\.f(ast)?q(\.gz)?$ ]]; then
        SAMPLE="${BASH_REMATCH[1]}"
        PAIRS["$SAMPLE,2"]="$file"
        SAMPLE_SEEN["$SAMPLE"]=1
    fi
done < <(
    find "${INPUT_PATH:-.}" -maxdepth "$INPUT_DIR_DEPTH" -type f \
        \( -name "*.fq" -o -name "*.fastq" -o -name "*.fq.gz" -o -name "*.fastq.gz" \) \
        -print0
)

# Get sorted unique sample names (still external sort, but minimal input)
mapfile -t SAMPLES < <(
    printf "%s\n" "${!SAMPLE_SEEN[@]}" | sort -V
)
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
    for STEP in FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a \
                KRAKEN2-b KRAKEN2-a GTDBTK-b GTDBTK-a ABRITAMR-b ABRITAMR-a \
                ABRICATE-b ABRICATE-a MULTIQC; do

        if is_skipped "$STEP"; then
            # Step explicitly skipped → mark SKIPPED
            update_status "$SAMPLE" "$STEP" "SKIPPED"
        else
            # Step not in SKIP_STEPS → if currently SKIPPED, reset to pending (-)
            current_status=$(get_status "$SAMPLE" "$STEP")
            if [[ "$current_status" == "SKIPPED" ]]; then
                update_status "$SAMPLE" "$STEP" "-"
            fi
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

# Extract unique sample names from PAIRS keys
declare -A UNIQUE_SAMPLES
for KEY in "${!PAIRS[@]}"; do
    SAMPLE="${KEY%%,*}"
    UNIQUE_SAMPLES["$SAMPLE"]=1
done

# Now loop over unique samples
for SAMPLE in "${!UNIQUE_SAMPLES[@]}"; do
    if [[ -z "${PAIRS["$SAMPLE,1"]+x}" ]]; then
        echo "[WARN] Missing R1 for sample '$SAMPLE'"
        MISSING=1
    fi
    if [[ -z "${PAIRS["$SAMPLE,2"]+x}" ]]; then
        echo "[WARN] Missing R2 for sample '$SAMPLE'"
        MISSING=1
    fi
done

(( MISSING )) && { echo "Please check your input files. QAssfilt pipeline will exit."; exit 1; }

# Processing area
run_fastp() {
    local SAMPLE=$1
    local R1=$2
    local R2=$3

    local FASTP_DIR="${OUTPUT_PATH}/fastp_file"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    local OUT1="${FASTP_DIR}/${SAMPLE}_trimmed_R1.fastq.gz"
    local OUT2="${FASTP_DIR}/${SAMPLE}_trimmed_R2.fastq.gz"
    mkdir -p "$LOG_DIR"

    if [[ "${CONTIG_MODE:-0}" -eq 1 ]]; then
        update_status "$SAMPLE" "FASTP" "SKIPPED"
        return 0
    fi

    if is_skipped "FASTP"; then
        update_status "$SAMPLE" "FASTP" "SKIPPED"
        return 0
    fi

    if should_run_step "$SAMPLE" "FASTP" || [[ ! -s "$OUT1" ]] || [[ ! -s "$OUT2" ]] || [[ ! -s "${FASTP_DIR}/${SAMPLE}.html" ]] || [[ ! -s "${FASTP_DIR}/${SAMPLE}.json" ]]; then
        mkdir -p "$FASTP_DIR"
        update_status "$SAMPLE" "FASTP" "RUNNING"

        conda run -n qassfilt_fastp fastp \
            -i "$R1" -I "$R2" \
            -o "$OUT1" -O "$OUT2" \
            -h "${FASTP_DIR}/${SAMPLE}.html" \
            -j "${FASTP_DIR}/${SAMPLE}.json" \
            -w "$THREADS" $FASTP_EXTRA_OPTS \
            >"${LOG_DIR}/${SAMPLE}_fastp.log" 2>&1

        [[ $? -eq 0 ]] \
            && update_status "$SAMPLE" "FASTP" "OK" \
            || update_status "$SAMPLE" "FASTP" "FAIL" "${LOG_DIR}/${SAMPLE}_fastp.log"
    fi
}

run_spades() {
    local SAMPLE=$1
    local FASTP_DIR="${OUTPUT_PATH}/fastp_file"
    local OUT1="${FASTP_DIR}/${SAMPLE}_trimmed_R1.fastq.gz"
    local OUT2="${FASTP_DIR}/${SAMPLE}_trimmed_R2.fastq.gz"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    local SPADES_DIR="${OUTPUT_PATH}/raw/spades_file/${SAMPLE}"
    local CONTIGS_BEFORE_DIR="${OUTPUT_PATH}/contigs_before"
    local CONTIGS_BEFORE="${CONTIGS_BEFORE_DIR}/${SAMPLE}.fasta"
    local SPADES_CONTIGS="${SPADES_DIR}/contigs.fasta"
    mkdir -p "$LOG_DIR"

    if [[ "${CONTIG_MODE:-0}" -eq 1 ]]; then
        update_status "$SAMPLE" "SPADES" "SKIPPED"
        return 0
    fi
        if is_skipped "SPADES"; then
        update_status "$SAMPLE" "SPADES" "SKIPPED"
        elif should_run_step "$SAMPLE" "SPADES" || [[ ! -s "${CONTIGS_BEFORE_DIR}/${SAMPLE}.fasta" ]]; then
            update_status "$SAMPLE" "SPADES" "RUNNING"
            mkdir -p "$SPADES_DIR"

            # Use FASTP output if available
            local SPADES_R1="$OUT1"
            local SPADES_R2="$OUT2"
            if is_skipped "FASTP"; then
                SPADES_R1="${PAIRS["$SAMPLE,1"]}"
                SPADES_R2="${PAIRS["$SAMPLE,2"]}"
            fi

            conda run -n qassfilt_spades spades.py -1 "$SPADES_R1" -2 "$SPADES_R2" \
                      -o "$SPADES_DIR" \
                      -t $THREADS $SPADES_EXTRA_OPTS \
                      >"$LOG_DIR/${SAMPLE}_spades.log" 2>&1
            SPADES_EXIT=$?

                if [[ $SPADES_EXIT -eq 0 ]]; then
                mkdir -p "$CONTIGS_BEFORE_DIR"
                [[ -s "$SPADES_CONTIGS" ]] && mv "$SPADES_CONTIGS" "${CONTIGS_BEFORE_DIR}/${SAMPLE}.fasta"
                update_status "$SAMPLE" "SPADES" "OK"
                else
                    update_status "$SAMPLE" "SPADES" "FAIL" "$LOG_DIR/${SAMPLE}_spades.log"
                fi
        fi
}

run_quast_before() {
    local SAMPLE=$1
    local LOG_DIR="${OUTPUT_PATH}/logs"
    local BASE_PATH="${OUTPUT_PATH}/contigs_before/${SAMPLE}"
    local CONTIGS_BEFORE=$(ls "${BASE_PATH}".{fasta,fa,fna,fas,ffn} 2>/dev/null | head -n1)
    mkdir -p "$LOG_DIR"

    if is_skipped "QUAST-b"; then
        update_status "$SAMPLE" "QUAST-b" "SKIPPED"
    elif [[ -s "$CONTIGS_BEFORE" ]]; then
        # Run QUAST-b if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "QUAST-b" || [[ ! -s "${OUTPUT_PATH}/raw/quast_before/${SAMPLE}/report.tsv" ]]; then
				update_status "$SAMPLE" "QUAST-b" "RUNNING"

				local OUTDIR_QUAST="${OUTPUT_PATH}/raw/quast_before/${SAMPLE}"
				mkdir -p "$OUTDIR_QUAST"

                if [[ -n "${QUAST_REFERENCE:-}" && -f "$QUAST_REFERENCE" ]]; then
                    conda run -n qassfilt_quast quast.py -o "$OUTDIR_QUAST" \
                        -t $THREADS \
                        --reference "$QUAST_REFERENCE" \
                        "$CONTIGS_BEFORE" \
                        --min-contig 1 \
                        >"$LOG_DIR/${SAMPLE}_quast_before.log" 2>&1
                else
                    conda run -n qassfilt_quast quast.py -o "$OUTDIR_QUAST" \
                        -t $THREADS \
                        "$CONTIGS_BEFORE" \
                        --min-contig 1 \
                        >"$LOG_DIR/${SAMPLE}_quast_before.log" 2>&1
                fi

				QUASTB_EXIT=$?

				[[ $QUASTB_EXIT -eq 0 ]] && update_status "$SAMPLE" "QUAST-b" "OK" || update_status "$SAMPLE" "QUAST-b" "FAIL" "$LOG_DIR/${SAMPLE}_quast_before.log"
			fi
		else
			update_status "$SAMPLE" "QUAST-b" "SKIPPED"
		fi
}

run_checkm2_before() {
    local SAMPLE=$1
    local BASE_PATH="${OUTPUT_PATH}/contigs_before/${SAMPLE}"
    local CONTIGS_BEFORE=$(ls "${BASE_PATH}".{fasta,fa,fna,fas,ffn} 2>/dev/null | head -n1)
    local LOG_DIR="${OUTPUT_PATH}/logs"
    mkdir -p "$LOG_DIR"

		if is_skipped "CHECKM2-b"; then
			update_status "$SAMPLE" "CHECKM2-b" "SKIPPED"
		elif [[ -s "$CONTIGS_BEFORE" ]]; then
			# Run CHECKM2-b if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "CHECKM2-b" || [[ ! -s "${OUTPUT_PATH}/raw/checkm2_before/${SAMPLE}/quality_report.tsv" ]]; then
				update_status "$SAMPLE" "CHECKM2-b" "RUNNING"

				# -----------------------
				# Export CHECKM2DB with default fallback
				# -----------------------
				DEFAULT_CHECKM2DB="$HOME/databases/CheckM2_database"
				export CHECKM2DB="${CHECKM2DB_PATH:-${CHECKM2_DB:-$DEFAULT_CHECKM2DB}}"

				LOG_FILE="$LOG_DIR/${SAMPLE}_checkm2_before.log"
				DB_ARG="--database_path ${CHECKM2DB}/*.dmnd"

				conda run -n qassfilt_checkm2 checkm2 predict --threads "$THREADS" \
					$DB_ARG \
					--input "$CONTIGS_BEFORE" \
					--force \
					--output-directory "${OUTPUT_PATH}/raw/checkm2_before/${SAMPLE}" \
					>"$LOG_FILE" 2>&1

				CHECKM2B_EXIT=$?

				[[ $CHECKM2B_EXIT -eq 0 ]] && update_status "$SAMPLE" "CHECKM2-b" "OK" || update_status "$SAMPLE" "CHECKM2-b" "FAIL" "$LOG_FILE"
			fi
		else
			update_status "$SAMPLE" "CHECKM2-b" "SKIPPED"
		fi
}

run_filter() {
    local SAMPLE=$1
    local LOG_DIR="${OUTPUT_PATH}/logs"
    local BASE_PATH="${OUTPUT_PATH}/contigs_before/${SAMPLE}"
    local CONTIGS_BEFORE=$(ls "${BASE_PATH}".{fasta,fa,fna,fas,ffn} 2>/dev/null | head -n1)
    local FILTERED_DIR="${OUTPUT_PATH}/contigs_filtered"
    local OUTFILTER="${FILTERED_DIR}/${SAMPLE}_filtered.fasta"
    mkdir -p "$LOG_DIR"

		if is_skipped "FILTER"; then
			update_status "$SAMPLE" "FILTER" "SKIPPED"
		elif [[ -s "$CONTIGS_BEFORE" ]]; then
			# Run FILTER if CONTIGS_BEFORE exists and step should run
			if should_run_step "$SAMPLE" "FILTER" || [[ ! -s "$OUTFILTER" ]]; then
				update_status "$SAMPLE" "FILTER" "RUNNING"
                mkdir -p "$FILTERED_DIR"

				conda activate qassfilt_seqkit >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_seqkit >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_seqkit after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_seqkit activated on second attempt."
                    fi
                fi

				LOG_FILE="$LOG_DIR/${SAMPLE}_filter.log"
				TMP_OUT="${OUTFILTER}.tmp"

				# Filter by coverage
				{
                seqkit fx2tab "$CONTIGS_BEFORE" | \
                awk -F "\t" -v cov="$SEQKIT_MIN_COV" '{
                    header=$1
                    seq=$2
                    covval=""
                    if (match(header, /_cov_([0-9]+\.?[0-9]*)/, arr)) covval=arr[1]
                    else if (match(header, /_depth_([0-9]+\.?[0-9]*)/, arr)) covval=arr[1]
                    if (covval != "" && covval+0 >= cov) print ">"header"\n"seq
                }' | \
                seqkit seq -m "$SEQKIT_MIN_LENGTH" > "$TMP_OUT"
                } 2> "$LOG_FILE"

				FILTER_EXIT=$?

				# If filtered output is empty, fallback to original
				if [[ $FILTER_EXIT -eq 0 ]]; then
					if [[ -s "$TMP_OUT" ]]; then
						mv "$TMP_OUT" "$OUTFILTER"
					else
						cp "$CONTIGS_BEFORE" "$OUTFILTER"
						rm -f "$TMP_OUT"
					fi
					update_status "$SAMPLE" "FILTER" "OK"
				else
					rm -f "$TMP_OUT"  # clean up failed output
					update_status "$SAMPLE" "FILTER" "FAIL" "$LOG_FILE"
				fi

				conda deactivate >/dev/null 2>&1 || true
			fi
		else
			update_status "$SAMPLE" "FILTER" "SKIPPED"
		fi
}

run_quast_after() {
    local SAMPLE=$1
    local OUTFILTER="${OUTPUT_PATH}/contigs_filtered/${SAMPLE}_filtered.fasta"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    mkdir -p "$LOG_DIR"

    if is_skipped "QUAST-a"; then
        update_status "$SAMPLE" "QUAST-a" "SKIPPED"
		elif [[ -s "$OUTFILTER" ]]; then
			# Rerun QUAST if report missing or empty
			if should_run_step "$SAMPLE" "QUAST-a" || [[ ! -s "${OUTPUT_PATH}/raw/quast_after/${SAMPLE}/report.tsv" ]]; then
				update_status "$SAMPLE" "QUAST-a" "RUNNING"

				local OUTDIR_QUAST="${OUTPUT_PATH}/raw/quast_after/${SAMPLE}"
				mkdir -p "$OUTDIR_QUAST"

				if [[ -n "${QUAST_REFERENCE:-}" && -f "$QUAST_REFERENCE" ]]; then
					conda run -n qassfilt_quast quast.py -o "$OUTDIR_QUAST" -t $THREADS --reference "$QUAST_REFERENCE" "$OUTFILTER" --min-contig 1 \
						>"$LOG_DIR/${SAMPLE}_quast_after.log" 2>&1
				else
					conda run -n qassfilt_quast quast.py -o "$OUTDIR_QUAST" -t $THREADS "$OUTFILTER" --min-contig 1 \
						>"$LOG_DIR/${SAMPLE}_quast_after.log" 2>&1
				fi
				QUASTA_EXIT=$?

				[[ $QUASTA_EXIT -eq 0 ]] && update_status "$SAMPLE" "QUAST-a" "OK" || update_status "$SAMPLE" "QUAST-a" "FAIL" "$LOG_DIR/${SAMPLE}_quast_after.log"
			fi
		else
			update_status "$SAMPLE" "QUAST-a" "SKIPPED"
		fi
}

run_checkm2_after() {
    local SAMPLE=$1
    local OUTFILTER="${OUTPUT_PATH}/contigs_filtered/${SAMPLE}_filtered.fasta"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    mkdir -p "$LOG_DIR"

    if is_skipped "CHECKM2-a"; then
        update_status "$SAMPLE" "CHECKM2-a" "SKIPPED"
		elif [[ -s "$OUTFILTER" ]]; then
			# Run CHECKM2-a if OUTFILTER exists and step should run
			if should_run_step "$SAMPLE" "CHECKM2-a" || [[ ! -s "${OUTPUT_PATH}/raw/checkm2_after/${SAMPLE}/quality_report.tsv" ]]; then
				update_status "$SAMPLE" "CHECKM2-a" "RUNNING"

				# -----------------------
				# Export CHECKM2DB with default fallback
				# -----------------------
				DEFAULT_CHECKM2DB="$HOME/databases/CheckM2_database"
				export CHECKM2DB="${CHECKM2DB_PATH:-${CHECKM2_DB:-$DEFAULT_CHECKM2DB}}"

				LOG_FILE="$LOG_DIR/${SAMPLE}_checkm2_after.log"
				DB_ARG="--database_path ${CHECKM2DB}/*.dmnd"

				conda run -n qassfilt_checkm2 checkm2 predict --threads "$THREADS" \
					$DB_ARG \
					--input "$OUTFILTER" \
					--force \
					--output-directory "${OUTPUT_PATH}/raw/checkm2_after/${SAMPLE}" \
					>"$LOG_FILE" 2>&1

				CHECKM2B_EXIT=$?

				[[ $CHECKM2B_EXIT -eq 0 ]] && update_status "$SAMPLE" "CHECKM2-a" "OK" || update_status "$SAMPLE" "CHECKM2-a" "FAIL" "$LOG_FILE"
			fi
		else
			update_status "$SAMPLE" "CHECKM2-a" "SKIPPED"
		fi
}

run_kraken2_before() {
    local SAMPLE=$1
    local CONTIGS_BEFORE="${OUTPUT_PATH}/contigs_before/${SAMPLE}.fasta"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    mkdir -p "$LOG_DIR"

    if [[ "${KRAKEN2_MODE:-0}" -eq 1 ]]; then
        if [[ -z "${KRAKEN2_DB_PATH:-}" || ! -d "${KRAKEN2_DB_PATH}" ]]; then
                # No database provided → mark both steps as SKIPPED
                update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
        else
                mkdir -p "${OUTPUT_PATH}/raw/kraken2/"

            # --- Run on CONTIGS_BEFORE ---
            local KRAKEN2_BEFORE_OUT="${OUTPUT_PATH}/raw/kraken2/${SAMPLE}.output"
            local KRAKEN2_BEFORE_REPORT="${OUTPUT_PATH}/raw/kraken2/${SAMPLE}.report"
            local KRAKENLOG_B="${LOG_DIR}/${SAMPLE}_kraken2_before.log"

            if is_skipped "KRAKEN2-b"; then
            update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
                elif [[ -s "$CONTIGS_BEFORE" ]]; then
                if should_run_step "$SAMPLE" "KRAKEN2-b" || [[ ! -s "$KRAKEN2_BEFORE_REPORT" ]] || [[ ! -s "$KRAKEN2_BEFORE_OUT" ]]; then
                update_status "$SAMPLE" "KRAKEN2-b" "RUNNING"

                conda run -n qassfilt_kraken2 kraken2 \
                --db "$KRAKEN2_DB_PATH" \
                --threads "$THREADS" \
                --output "$KRAKEN2_BEFORE_OUT" \
                --report "$KRAKEN2_BEFORE_REPORT" \
                --use-names \
                "$CONTIGS_BEFORE" \
                >"$KRAKENLOG_B" 2>&1
                [[ $? -eq 0 ]] && update_status "$SAMPLE" "KRAKEN2-b" "OK" || update_status "$SAMPLE" "KRAKEN2-b" "FAIL" "$KRAKENLOG_B"
                fi
            else
                update_status "$SAMPLE" "KRAKEN2-b" "SKIPPED"
            fi
        fi
    fi
}

run_kraken2_after() {
    local SAMPLE=$1
    local OUTFILTER="${OUTPUT_PATH}/contigs_filtered/${SAMPLE}_filtered.fasta"
    local LOG_DIR="${OUTPUT_PATH}/logs"
    mkdir -p "$LOG_DIR"

    # Only run if KRAKEN2_MODE = 1
    if [[ "${KRAKEN2_MODE:-0}" -ne 1 ]]; then
        return 0
    fi

    # Check DB path
    if [[ -z "${KRAKEN2_DB_PATH:-}" || ! -d "${KRAKEN2_DB_PATH}" ]]; then
        update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
        return 0
    fi

    mkdir -p "${OUTPUT_PATH}/raw/kraken2/"

    local KRAKEN2_AFTER_OUT="${OUTPUT_PATH}/raw/kraken2/${SAMPLE}_filtered.output"
    local KRAKEN2_AFTER_REPORT="${OUTPUT_PATH}/raw/kraken2/${SAMPLE}_filtered.report"
    local KRAKENLOG_A="${LOG_DIR}/${SAMPLE}_kraken2_filtered.log"

    # If globally skipped
    if is_skipped "KRAKEN2-a"; then
        update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
        return 0
    fi

    # If filtered file missing → skip
    if [[ ! -s "$OUTFILTER" ]]; then
        update_status "$SAMPLE" "KRAKEN2-a" "SKIPPED"
        return 0
    fi

    # Decide whether to run
    if should_run_step "$SAMPLE" "KRAKEN2-a" \
        || [[ ! -s "$KRAKEN2_AFTER_REPORT" ]] \
        || [[ ! -s "$KRAKEN2_AFTER_OUT" ]]; then

        update_status "$SAMPLE" "KRAKEN2-a" "RUNNING"

        conda run -n qassfilt_kraken2 kraken2 \
            --db "$KRAKEN2_DB_PATH" \
            --threads "$THREADS" \
            --output "$KRAKEN2_AFTER_OUT" \
            --report "$KRAKEN2_AFTER_REPORT" \
            --use-names \
            "$OUTFILTER" \
            >"$KRAKENLOG_A" 2>&1

        if [[ $? -eq 0 ]]; then
            update_status "$SAMPLE" "KRAKEN2-a" "OK"
        else
            update_status "$SAMPLE" "KRAKEN2-a" "FAIL" "$KRAKENLOG_A"
        fi
    fi
}

run_gtdbtk_before() {
    if [[ "${GTDBTK_MODE:-0}" -eq 1 ]]; then
        if [[ -z "${GTDBTK_DB_PATH:-}" || ! -d "${GTDBTK_DB_PATH}" ]]; then
            # No database → mark both steps as SKIPPED
            update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
            update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
        else
            GTDBTKLOG="${OUTPUT_PATH}/logs/gtdbtk.log"
            mkdir -p "${OUTPUT_PATH}/raw/gtdbtk/"
            export GTDBTK_DATA_PATH="$GTDBTK_DB_PATH"

            CONTIGS_BEFORE_GTDBTK="${OUTPUT_PATH}/contigs_before"
            GTDBTK_BEFORE_DIR="${OUTPUT_PATH}/raw/gtdbtk/before"
            mkdir -p "$GTDBTK_BEFORE_DIR"

            if is_skipped "GTDBTK-b"; then
                for SAMPLE in "${SAMPLES[@]}"; do
                    update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
                done
            elif [[ -d "$CONTIGS_BEFORE_GTDBTK" ]]; then
                if should_run_step "$SAMPLE" "GTDBTK-b" || [[ ! -s "${GTDBTK_BEFORE_DIR}/classify/before.bac120.classify.tree.1.tree" ]] || [[ ! -s "${GTDBTK_BEFORE_DIR}/classify/before.backbone.bac120.classify.tree" ]] || [[ ! -s "${GTDBTK_BEFORE_DIR}/classify/before.bac120.summary.tsv" ]] || [[ ! -s "${GTDBTK_BEFORE_DIR}/classify/before.bac120.tree.mapping.tsv" ]]; then
                    update_status "$SAMPLE" "GTDBTK-b" "RUNNING"

                    # Build batch file
                    find "$CONTIGS_BEFORE_GTDBTK" -type f \
                        \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.fasta" -o -iname "*.fas" \) |
                    awk '{
                        path=$0
                        file=$0
                        sub(/^.*\//, "", file)
                        sub(/\.[^.]+$/, "", file)
                        print path "\t" file
                    }' > "${GTDBTK_BEFORE_DIR}/gtdbtk_batch_before.tab"

                    conda run -n qassfilt_gtdbtk gtdbtk classify_wf \
                        --batchfile "${GTDBTK_BEFORE_DIR}/gtdbtk_batch_before.tab" \
                        --out_dir "$GTDBTK_BEFORE_DIR" \
                        --cpus "$GTDBTK_THREADS" \
                        --pplacer_cpus "$GTDBTK_THREADS" \
                        --skip_ani_screen \
                        --force \
                        --prefix before \
                        >>"$GTDBTKLOG" 2>&1

                    if [[ $? -eq 0 ]]; then
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-b" "OK"
                        done
                    else
                        for SAMPLE in "${SAMPLES[@]}"; do
                            update_status "$SAMPLE" "GTDBTK-b" "FAIL" "$GTDBTKLOG"
                        done
                    fi
                fi
            fi
        fi
    fi
}

run_gtdbtk_after() {
    
if [[ "${GTDBTK_MODE:-0}" -eq 1 ]]; then
    if [[ -z "${GTDBTK_DB_PATH:-}" || ! -d "${GTDBTK_DB_PATH}" ]]; then
        # No database → mark both steps as SKIPPED
        update_status "$SAMPLE" "GTDBTK-b" "SKIPPED"
        update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
    else
        GTDBTKLOG="${OUTPUT_PATH}/logs/gtdbtk.log"
        mkdir -p "${OUTPUT_PATH}/raw/gtdbtk/"
        export GTDBTK_DATA_PATH="$GTDBTK_DB_PATH"

    local OUTFILTER_GTDBTK="${OUTPUT_PATH}/contigs_filtered"
    local GTDBTK_AFTER_DIR="${OUTPUT_PATH}/raw/gtdbtk/after"
    local GTDBTKLOG="${OUTPUT_PATH}/logs/gtdbtk.log"

    mkdir -p "$GTDBTK_AFTER_DIR"
    mkdir -p "${OUTPUT_PATH}/logs"

    if is_skipped "GTDBTK-a"; then
            for SAMPLE in "${SAMPLES[@]}"; do
                update_status "$SAMPLE" "GTDBTK-a" "SKIPPED"
            done
        elif [[ -d "$OUTFILTER_GTDBTK" ]]; then
        if should_run_step "$SAMPLE" "GTDBTK-a" || [[ ! -s "${GTDBTK_AFTER_DIR}/classify/after.bac120.classify.tree.1.tree" ]] || [[ ! -s "${GTDBTK_AFTER_DIR}/classify/after.backbone.bac120.classify.tree" ]] || [[ ! -s "${GTDBTK_AFTER_DIR}/classify/after.bac120.summary.tsv" ]] || [[ ! -s "${GTDBTK_AFTER_DIR}/classify/after.bac120.tree.mapping.tsv" ]]; then
            update_status "$SAMPLE" "GTDBTK-a" "RUNNING"

    # Run GTDB-Tk safely via conda run
    conda run -n qassfilt_gtdbtk gtdbtk classify_wf \
        --genome_dir "$OUTFILTER_GTDBTK" \
        --out_dir "$GTDBTK_AFTER_DIR" \
        --cpus "$GTDBTK_THREADS" \
        --extension fasta \
        --skip_ani_screen \
        --pplacer_cpus "$GTDBTK_THREADS" \
        --force \
        --prefix after \
        >>"$GTDBTKLOG" 2>&1

    if [[ $? -eq 0 ]]; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "GTDBTK-a" "OK"
        done
    else
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "GTDBTK-a" "FAIL" "$GTDBTKLOG"
        done
    fi
fi
fi
fi
fi
}

run_abritamr_before() {
if [[ "${ABRITAMR_MODE:-0}" -eq 1 ]]; then

    OUTPUT_PATH="$(realpath -m "$OUTPUT_PATH")"
    ABRITAMRLOG="${OUTPUT_PATH}/logs/abritamr.log"

    mkdir -p "$(dirname "$ABRITAMRLOG")"
    mkdir -p "${OUTPUT_PATH}/raw/abritamr"

    CONTIGS_BEFORE_ABRITAMR="${OUTPUT_PATH}/contigs_before"
    ABRITAMR_BEFORE_OUT="${OUTPUT_PATH}/raw/abritamr/before"

    if is_skipped "ABRITAMR-b"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-b" "SKIPPED"
        done
    elif [[ -d "$CONTIGS_BEFORE_ABRITAMR" && $(find "$CONTIGS_BEFORE_ABRITAMR" -type f \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.fasta" -o -iname "*.fas" -o -iname "*.ffn" \) | wc -l) -gt 0 ]]; then
        if should_run_step "$SAMPLE" "ABRITAMR-b" || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_matches.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_partials.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/summary_virulence.txt" ]] || [[ ! -s "$ABRITAMR_BEFORE_OUT/abritamr.txt" ]]; then
            update_status "$SAMPLE" "ABRITAMR-b" "RUNNING"
                mkdir -p "$ABRITAMR_BEFORE_OUT"

            conda activate qassfilt_abritamr >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_abritamr >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_abritamr after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_abritamr activated on second attempt."
                    fi
                    fi

            # Create .tab mapping file
            find "$CONTIGS_BEFORE_ABRITAMR" -type f \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.fasta" -o -iname "*.fas" -o -iname "*.ffn" \) | awk -F/ '{
                file=$NF; sub(/\.[^.]+$/, "", file);
                print file "_before\t" $0
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
fi
}

run_abritamr_after() {

if [[ "${ABRITAMR_MODE:-0}" -eq 1 ]]; then

    OUTPUT_PATH="$(realpath -m "$OUTPUT_PATH")"
    ABRITAMRLOG="${OUTPUT_PATH}/logs/abritamr.log"

    mkdir -p "$(dirname "$ABRITAMRLOG")"
    mkdir -p "${OUTPUT_PATH}/raw/abritamr"
    
    OUTFILTER_ABRITAMR="${OUTPUT_PATH}/contigs_filtered/"
    ABRITAMR_AFTER_OUT="${OUTPUT_PATH}/raw/abritamr/after"

    if is_skipped "ABRITAMR-a"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRITAMR-a" "SKIPPED"
        done
    elif [[ -d "$OUTFILTER_ABRITAMR" && $(find "$OUTFILTER_ABRITAMR" -type f \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.fasta" -o -iname "*.fas" -o -iname "*.ffn" \) | wc -l) -gt 0 ]]; then
        if should_run_step "$SAMPLE" "ABRITAMR-a" || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_matches.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_partials.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/summary_virulence.txt" ]] || [[ ! -s "$ABRITAMR_AFTER_OUT/abritamr.txt" ]]; then
            update_status "$SAMPLE" "ABRITAMR-a" "RUNNING"
                mkdir -p "$ABRITAMR_AFTER_OUT"
            conda activate qassfilt_abritamr >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_abritamr >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_abritamr after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_abritamr activated on second attempt."
                    fi
                    fi

            # Create .tab mapping file
            find "$OUTFILTER_ABRITAMR" -type f \( -iname "*.fa" -o -iname "*.fna" -o -iname "*.fasta" -o -iname "*.fas" -o -iname "*.ffn" \) | awk -F/ '{
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
}

run_abricate_before() {

if [[ "${ABRICATE_MODE:-0}" -eq 1 ]]; then
    ABRICATELOG="${OUTPUT_PATH}/logs/abricate.log"
    mkdir -p "${OUTPUT_PATH}/raw/abricate/"

    # --- Run on CONTIGS_BEFORE_ABRICATE ---
    shopt -s nullglob; CONTIGS_BEFORE_ABRICATE=( "$OUTPUT_PATH/contigs_before/"*.fa "$OUTPUT_PATH/contigs_before/"*.fna "$OUTPUT_PATH/contigs_before/"*.fasta "$OUTPUT_PATH/contigs_before/"*.fas "$OUTPUT_PATH/contigs_before/"*.ffn ); shopt -u nullglob
    ABRICATE_BEFORE_PREFIX="${OUTPUT_PATH}/raw/abricate/before"

    if is_skipped "ABRICATE-b"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-b" "SKIPPED"
        done
    elif (( ${#CONTIGS_BEFORE_ABRICATE[@]} > 0 )); then
        if should_run_step "$SAMPLE" "ABRICATE-b" || [[ ! -s "${OUTPUT_PATH}/raw/abricate/before_vfdb.summary.tsv" ]]; then
                update_status "$SAMPLE" "ABRICATE-b" "RUNNING"
            conda activate qassfilt_abricate >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_abricate >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_abricate after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_abricate activated on second attempt."
                    fi
                    fi

            ABRICATE_DBS=$(abricate --list | awk 'NR>1 {print $1}')
            for DB in $ABRICATE_DBS; do
                DB_PREFIX="${ABRICATE_BEFORE_PREFIX}_${DB}"
                echo "[$(date '+%F %T')] Running ABRICATE (before) with database: $DB" >>"$ABRICATELOG"
                abricate $ABRICATE_EXTRA_OPTS --db "$DB" "${CONTIGS_BEFORE_ABRICATE[@]}" > "${DB_PREFIX}.tsv" 2>>"$ABRICATELOG"

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
fi
}
run_abricate_after() {
    if [[ "${ABRICATE_MODE:-0}" -eq 1 ]]; then
    ABRICATELOG="${OUTPUT_PATH}/logs/abricate.log"
    mkdir -p "${OUTPUT_PATH}/raw/abricate/"
    
    # --- Run on OUTFILTER_ABRICATE ---
    shopt -s nullglob; OUTFILTER_ABRICATE=( "${OUTPUT_PATH}/contigs_filtered/"*.fa "${OUTPUT_PATH}/contigs_filtered/"*.fna "${OUTPUT_PATH}/contigs_filtered/"*.fasta "${OUTPUT_PATH}/contigs_filtered/"*.fas "${OUTPUT_PATH}/contigs_filtered/"*.ffn ); shopt -u nullglob
    ABRICATE_AFTER_PREFIX="${OUTPUT_PATH}/raw/abricate/filtered"

    if is_skipped "ABRICATE-a"; then
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "ABRICATE-a" "SKIPPED"
        done
    elif (( ${#OUTFILTER_ABRICATE[@]} > 0 )); then
        if should_run_step "$SAMPLE" "ABRICATE-a" || [[ ! -s "${OUTPUT_PATH}/raw/abricate/filtered_vfdb.summary.tsv" ]]; then
                update_status "$SAMPLE" "ABRICATE-a" "RUNNING"

            conda activate qassfilt_abricate >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_abricate >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_abricate after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_abricate activated on second attempt."
                    fi
                    fi

            ABRICATE_DBS=$(abricate --list | awk 'NR>1 {print $1}')
            for DB in $ABRICATE_DBS; do
                DB_PREFIX="${ABRICATE_AFTER_PREFIX}_${DB}"
                echo "[$(date '+%F %T')] Running ABRICATE (after) with database: $DB" >>"$ABRICATELOG"
                abricate $ABRICATE_EXTRA_OPTS --db "$DB" "${OUTFILTER_ABRICATE[@]}" > "${DB_PREFIX}.tsv" 2>>"$ABRICATELOG"

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
}

run_multiqc() {
		if is_skipped "MULTIQC"; then
			for SAMPLE in "${SAMPLES[@]}"; do
				update_status "$SAMPLE" "MULTIQC" "SKIPPED"
			done
		elif should_run_step "$SAMPLE" "MULTIQC" || [[ ! -s "${OUTPUT_PATH}/multiqc_reports/QAssfilt_QUAST_CheckM2_MultiQC_Report.html" ]] || [[ ! -s "${OUTPUT_PATH}/multiqc_reports/QAssfilt_GTDB-Tk_Kraken2_MultiQC_Report.html" ]] || [[ ! -s "${OUTPUT_PATH}/multiqc_reports/QAssfilt_Fastp_MultiQC_Report.html" ]] || [[ ! -s "${OUTPUT_PATH}/multiqc_reports/QAssfilt_Abricate_Report.html" ]] || [[ ! -s "${OUTPUT_PATH}/multiqc_reports/QAssfilt_abritAMR_Report.html" ]]; then
                update_status "$SAMPLE" "MULTIQC" "RUNNING"
			conda activate qassfilt_multiqc >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    echo "[WARN] First activation failed, retrying..."
                    conda activate qassfilt_multiqc >/dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        echo "⚠️ Failed to activate qassfilt_multiqc after retry. Exiting."
                        exit 1
                    else
                        echo "[INFO] Conda environment qassfilt_multiqc activated on second attempt."
                    fi
                    fi

			LOG_FILE="${OUTPUT_PATH}/logs/multiqc.log"
			mkdir -p "${OUTPUT_PATH}/logs"
			mkdir -p "${OUTPUT_PATH}/multiqc_reports"

			RUN_ANY=0

			# --- Fastp MultiQC ---
			if [[ -d "${OUTPUT_PATH}/fastp_file" ]]; then
				mkdir -p "${OUTPUT_PATH}/multiqc_reports"
        multiqc "${OUTPUT_PATH}/fastp_file" \
            -o "${OUTPUT_PATH}/multiqc_reports" \
            --fn_as_s_name \
            --title "QAssfilt_Fastp_Report" \
            --filename "QAssfilt_Fastp_MultiQC_Report.html" \
            --force \
            --module fastp \
            --cl-config '{"max_table_rows": 100000}' \
            >>"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    # --- Combined QC MultiQC (QUAST + CheckM2) ---
    QC_DIRS=()
    [[ -d "${OUTPUT_PATH}/raw/quast_before" ]]   && QC_DIRS+=("${OUTPUT_PATH}/raw/quast_before")
    [[ -d "${OUTPUT_PATH}/raw/quast_after" ]]    && QC_DIRS+=("${OUTPUT_PATH}/raw/quast_after")
    [[ -d "${OUTPUT_PATH}/raw/checkm2_before" ]] && QC_DIRS+=("${OUTPUT_PATH}/raw/checkm2_before")
    [[ -d "${OUTPUT_PATH}/raw/checkm2_after" ]]  && QC_DIRS+=("${OUTPUT_PATH}/raw/checkm2_after")

    if [[ ${#QC_DIRS[@]} -gt 0 ]]; then
        mkdir -p "${OUTPUT_PATH}/multiqc_reports"
    
        multiqc "${QC_DIRS[@]}" \
            -o "${OUTPUT_PATH}/multiqc_reports" \
            --title "QAssfilt_QUAST_CheckM2_Report" \
            --filename "QAssfilt_QUAST_CheckM2_MultiQC_Report.html" \
            --force \
            --cl-config '{"max_table_rows": 100000}' \
            >>"$LOG_FILE" 2>&1
        RUN_ANY=1
    fi

    # --- Combined Kraken2 + GTDB-Tk MultiQC ---
    MULTIQC_INPUTS=()

    [[ -d "${OUTPUT_PATH}/raw/kraken2" ]] && MULTIQC_INPUTS+=("${OUTPUT_PATH}/raw/kraken2")
    [[ -d "${OUTPUT_PATH}/raw/gtdbtk"  ]] && MULTIQC_INPUTS+=("${OUTPUT_PATH}/raw/gtdbtk")

    if (( ${#MULTIQC_INPUTS[@]} > 0 )); then
        mkdir -p "${OUTPUT_PATH}/multiqc_reports"

        multiqc "${MULTIQC_INPUTS[@]}" \
            -o "${OUTPUT_PATH}/multiqc_reports" \
            --title "QAssfilt_GTDB-Tk_Kraken2_Report" \
            --filename "QAssfilt_GTDB-Tk_Kraken2_MultiQC_Report.html" \
            --force \
            --cl-config '{"max_table_rows": 100000}' \
            >>"$LOG_FILE" 2>&1

        RUN_ANY=1
    fi

# --- Abricate MultiQC (Flat format - shows all data) ---
if [[ -d "${OUTPUT_PATH}/raw/abricate" ]]; then
    mkdir -p "${OUTPUT_PATH}/multiqc_reports"
    rm -f "${OUTPUT_PATH}/multiqc_reports/abricate_combined.tsv"
    ABRICATE_COMBINED="${OUTPUT_PATH}/multiqc_reports/abricate_combined.tsv"
    ABRICATE_HTML="${OUTPUT_PATH}/multiqc_reports/QAssfilt_Abricate_Report.html"

# Process and combine TSV files
shopt -s nullglob

# First, collect all data into a temporary file
TEMP_FILE=$(mktemp)

for file in "${OUTPUT_PATH}/raw/abricate/"*.tsv; do
    [[ "$file" == *.summary.tsv ]] && continue

    tail -n +2 "$file" | \
    awk -F'\t' '{
    # Extract basename from full path
    split($1, a, "/")
    sample = a[length(a)]
    sub(/\.(fasta|fa|fna|ffn|faa|fas)$/, "", sample)

    f1 = (sample != "" ? sample : "NA")
    f6 = ($6 != "" ? $6 : "NA")
    f12 = ($12 != "" ? $12 : "NA")
    f15 = ($15 != "" ? $15 : "NA")

    print f1 "\t" f6 "\t" f12 "\t" f15
    }'
done > "$TEMP_FILE"

# Remove unwanted rows from the combined file
awk -F'\t' '{
    # $1 = sample/stage, $2 = FILE, $3 = GENE, $4 = db, $5 = RESISTANCE
    if ($1 != "abricate" && $1 != "before" && $1 != "filtered" && !($4=="NA" && $3=="NA" && $5=="NA")) 
        print
}' "$TEMP_FILE" > "${TEMP_FILE}.cleaned"

# Overwrite the original temp file with the cleaned one
mv "${TEMP_FILE}.cleaned" "$TEMP_FILE"

shopt -u nullglob

# Combine rows with same Sample ID and Database
ABRICATE_TMP=$(mktemp)

python3 << PYTHON_SCRIPT > "$ABRICATE_TMP"
from collections import defaultdict
import sys

data = defaultdict(lambda: {"genes": set(), "resistance": set()})

with open("${TEMP_FILE}", "r") as f:
    for line in f:
        if line.strip():
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 4:
                sample, gene, database, resistance = parts[:4]
                key = (sample, database)
                data[key]["genes"].add(gene)
                data[key]["resistance"].add(resistance)

print("Sample\tDatabase\tGenes\tResistance")

if not data:
    sys.exit(0)

for (sample, database), values in sorted(data.items()):
    genes = "; ".join(sorted(values["genes"]))
    resistance = "; ".join(sorted(values["resistance"]))
    print(f"{sample}\t{database}\t{genes}\t{resistance}")
PYTHON_SCRIPT

# Atomically replace final file
mv "$ABRICATE_TMP" "$ABRICATE_COMBINED"

#HTML Report
if [[ ! -s "$ABRICATE_COMBINED" ]]; then
    echo ""
else

ABRICATE_COMBINED="$ABRICATE_COMBINED" \
ABRICATE_HTML="$ABRICATE_HTML" \
python3 << 'PYTHON_HTML'
import pandas as pd
import os
from pathlib import Path

# Load combined TSV
input_file = os.environ["ABRICATE_COMBINED"]
output_file = Path(os.environ["ABRICATE_HTML"])

df = pd.read_csv(input_file, sep="\t")

# HTML start
html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>QAssfilt ABRicate Report</title>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.dataTables.min.css">
<script src="https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/colreorder/1.6.2/css/colReorder.dataTables.min.css">
<script src="https://cdn.datatables.net/colreorder/1.6.2/js/dataTables.colReorder.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/colresize/1.0.2/css/dataTables.colResize.min.css">
<script src="https://cdn.datatables.net/colresize/1.0.2/js/dataTables.colResize.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/searchpanes/2.2.0/css/searchPanes.dataTables.min.css">
<script src="https://cdn.datatables.net/searchpanes/2.2.0/js/dataTables.searchPanes.min.js"></script>
<link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" />
<script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
<style>
body {{ font-family: Arial, sans-serif; margin:20px; background:#f4f6f7; }}
h1 {{ border-bottom:3px solid #16a085; }}
.select2-results__option::before {{
    content: "☐ ";
    font-size: 14px;
}}

.select2-results__option--selected::before {{
    content: "☑ ";
}}
/* --- Force Select2 dropdown arrow visibility --- */
.select2-container--default.select2-container--open .select2-selection--multiple {{
    border-color: #aaa;
}}

.select2-container--default .select2-selection--multiple .select2-selection__arrow {{
    display: block; /* make sure it’s visible */
    position: absolute;
    top: 50%;
    right: 6px;
    width: 20px;
    height: 20px;
    transform: translateY(-50%);
}}

.select2-container--default .select2-selection--multiple .select2-selection__arrow b {{
    border-color: #555 transparent transparent transparent;
    border-style: solid;
    border-width: 6px 5px 0 5px;
}}
#table th,
#table td {{
    white-space: nowrap;       /* no wrapping */
}}
</style>
</head>
<body>
<h1>QAssfilt ABRicate Report</h1>

<table id="table" class="display" style="width:100%">
<thead>
<tr>
{''.join([f'<th>{c}</th>' for c in df.columns])}
</tr>
<tr>
{''.join(['<th><input type="text" placeholder="🔎︎"><br><select class="multi-select" multiple style="width:100%"><option value="">All</option></select></th>' for c in df.columns])}
</tr>
</thead>
<tbody>
"""

# Table rows
for _, row in df.iterrows():
    html += "<tr>"
    for c in df.columns:
        val = "" if pd.isna(row[c]) else row[c]
        html += f"<td>{val}</td>"
    html += "</tr>"

html += """
</tbody>
</table>

<script>
$(document).ready(function() {

    var table = $('#table').DataTable({
        pageLength: 25,
        orderCellsTop: true,
        colReorder: true,
        colResize: true,

        dom: "<'dt-buttons-container'B>rt<'length-container'l><'table-info'i><'pagination'p>",
        buttons: [
            'copyHtml5',
            'csvHtml5',
            'excelHtml5',
            'pdfHtml5',
            'print'
        ],

        initComplete: function () {
            var api = this.api();

            api.columns().every(function (i) {
                var column = this;

                // second header row cell
                var headerCell = $(column.header())
                    .closest('thead')
                    .find('tr:eq(1) th:eq(' + i + ')');

                var input  = headerCell.find('input');
                var select = headerCell.find('select');

                /* ---------- TEXT SEARCH ---------- */
                input.on('keyup change clear', function () {
                    if (column.search() !== this.value) {
                        column.search(this.value, false, true).draw();
                    }
                });

                /* ---------- SELECT2 FILTER ---------- */
                select.select2({
                    placeholder: "Filter ⌵",
                    allowClear: true,
                    closeOnSelect: false,
                    width: 'resolve'
                });

                column.data().unique().sort().each(function (d) {
                    if (d !== "") {
                        select.append(
                            '<option value="' + d + '">' + d + '</option>'
                        );
                    }
                });

                select.on('change', function () {
                    var values = $(this).val();

                    if (!values || values.length === 0 || values.includes("")) {
                        column.search('').draw();
                        return;
                    }

                    var regex = values
                        .map(v => '^' + $.fn.dataTable.util.escapeRegex(v) + '$')
                        .join('|');

                    column.search(regex, true, false).draw();
                });
            });
        }
    });

});
</script>
</body>
</html>
"""

output_file.write_text(html)
PYTHON_HTML
RUN_ANY=1
fi
fi

# ===============================
# ABRITAMR HTML reports
# ===============================
ABRITAMR_DIR="${OUTPUT_PATH}/raw/abritamr"
REPORT_DIR="${OUTPUT_PATH}/multiqc_reports"

ABRITAMR_COMBINED="${REPORT_DIR}/abritamr_combined.tsv"
ABRITAMR_HTML="${REPORT_DIR}/QAssfilt_abritAMR_Report.html"

mkdir -p "$REPORT_DIR"
rm -f "$ABRITAMR_COMBINED"

# ===============================
# COMBINE summary_matches.txt
# ===============================

FILE_BEFORE="${ABRITAMR_DIR}/before/summary_matches.txt"
FILE_AFTER="${ABRITAMR_DIR}/after/summary_matches.txt"

# =========================
# CHECK INPUT FILES
# =========================
INPUT_FILES=()

[[ -f "$FILE_BEFORE" ]] && INPUT_FILES+=("$FILE_BEFORE")
[[ -f "$FILE_AFTER"  ]] && INPUT_FILES+=("$FILE_AFTER")

# =========================
# HANDLE NO INPUT FILES
# =========================
if [[ ! -s "$INPUT_FILES" ]]; then
    echo ""
else
    echo ""

# =========================
# MERGE LOGIC
# =========================
awk -F'\t' '
BEGIN {
    OFS="\t"
}

# ---------- First file ----------
NR == FNR {
    if (FNR == 1) {
        for (i = 1; i <= NF; i++) {
            col[$i] = i
            headers[i] = $i
        }
        maxcol = NF
        next
    }

    sid = $1
    samples[sid] = 1

    for (i = 2; i <= NF; i++) {
        data[sid, i] = $i
    }
    next
}

# ---------- Second (and later) files ----------
FNR == 1 {
    for (i = 1; i <= NF; i++) {
        if (!($i in col)) {
            col[$i] = ++maxcol
            headers[maxcol] = $i
        }
        map[i] = col[$i]
    }
    next
}

{
    sid = $1
    samples[sid] = 1

    for (i = 2; i <= NF; i++) {
        c = map[i]

        if ($i == "")
            continue

        if (data[sid, c] != "")
            data[sid, c] = data[sid, c] ";" $i
        else
            data[sid, c] = $i
    }
}

END {
    # Print header
    printf "%s", headers[1]
    for (i = 2; i <= maxcol; i++)
        printf OFS "%s", headers[i]
    print ""

    # Print rows (sorted by Sample ID)
    n = asorti(samples, sorted_samples)
    for (j = 1; j <= n; j++) {
        sid = sorted_samples[j]
        printf "%s", sid
        for (i = 2; i <= maxcol; i++)
            printf OFS "%s", data[sid, i]
        print ""
    }
}
' "${INPUT_FILES[@]}" > "$ABRITAMR_COMBINED"
fi

# ===============================
# GENERATE INTERACTIVE HTML
# ===============================
if [[ ! -s "$ABRITAMR_COMBINED" ]]; then
    echo ""
else
ABRITAMR_COMBINED="$ABRITAMR_COMBINED" \
ABRITAMR_HTML="$ABRITAMR_HTML" \
python3 << 'PYTHON_HTML'
import pandas as pd
import os
from pathlib import Path

# Load combined TSV
input_file = os.environ["ABRITAMR_COMBINED"]
output_file = Path(os.environ["ABRITAMR_HTML"])

df = pd.read_csv(input_file, sep="\t")

# HTML start
html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>QAssfilt abritAMR Report</title>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.dataTables.min.css">
<script src="https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/colreorder/1.6.2/css/colReorder.dataTables.min.css">
<script src="https://cdn.datatables.net/colreorder/1.6.2/js/dataTables.colReorder.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/colresize/1.0.2/css/dataTables.colResize.min.css">
<script src="https://cdn.datatables.net/colresize/1.0.2/js/dataTables.colResize.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/searchpanes/2.2.0/css/searchPanes.dataTables.min.css">
<script src="https://cdn.datatables.net/searchpanes/2.2.0/js/dataTables.searchPanes.min.js"></script>
<link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" />
<script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
<style>
body {{ font-family: Arial, sans-serif; margin:20px; background:#f4f6f7; }}
h1 {{ border-bottom:3px solid #16a085; }}
.select2-results__option::before {{
    content: "☐ ";
    font-size: 14px;
}}

.select2-results__option--selected::before {{
    content: "☑ ";
}}
/* --- Force Select2 dropdown arrow visibility --- */
.select2-container--default.select2-container--open .select2-selection--multiple {{
    border-color: #aaa;
}}

.select2-container--default .select2-selection--multiple .select2-selection__arrow {{
    display: block; /* make sure it’s visible */
    position: absolute;
    top: 50%;
    right: 6px;
    width: 20px;
    height: 20px;
    transform: translateY(-50%);
}}

.select2-container--default .select2-selection--multiple .select2-selection__arrow b {{
    border-color: #555 transparent transparent transparent;
    border-style: solid;
    border-width: 6px 5px 0 5px;
}}
}}
#table th,
#table td {{
    white-space: nowrap;       /* no wrapping */
}}
</style>
</head>
<body>
<h1>QAssfilt abritAMR Report</h1>

<table id="table" class="display" style="width:100%">
<thead>
<tr>
{''.join([f'<th>{c}</th>' for c in df.columns])}
</tr>
<tr>
{''.join(['<th><input type="text" placeholder="🔎︎"><br><select class="multi-select" multiple style="width:100%"><option value="">All</option></select></th>' for c in df.columns])}
</tr>
</thead>
<tbody>
"""

# Table rows
for _, row in df.iterrows():
    html += "<tr>"
    for c in df.columns:
        val = "" if pd.isna(row[c]) else row[c]
        html += f"<td>{val}</td>"
    html += "</tr>"

html += """
</tbody>
</table>

<script>
$(document).ready(function() {

    var table = $('#table').DataTable({
        pageLength: 25,
        orderCellsTop: true,
        colReorder: true,
        colResize: true,

        dom: "<'dt-buttons-container'B>rt<'length-container'l><'table-info'i><'pagination'p>",
        buttons: [
            'copyHtml5',
            'csvHtml5',
            'excelHtml5',
            'pdfHtml5',
            'print'
        ],

        initComplete: function () {
            var api = this.api();

            api.columns().every(function (i) {
                var column = this;

                // second header row cell
                var headerCell = $(column.header())
                    .closest('thead')
                    .find('tr:eq(1) th:eq(' + i + ')');

                var input  = headerCell.find('input');
                var select = headerCell.find('select');

                /* ---------- TEXT SEARCH ---------- */
                input.on('keyup change clear', function () {
                    if (column.search() !== this.value) {
                        column.search(this.value, false, true).draw();
                    }
                });

                /* ---------- SELECT2 FILTER ---------- */
                select.select2({
                    placeholder: "Filter ⌵",
                    allowClear: true,
                    closeOnSelect: false,
                    width: 'resolve'
                });

                column.data().unique().sort().each(function (d) {
                    if (d !== "") {
                        select.append(
                            '<option value="' + d + '">' + d + '</option>'
                        );
                    }
                });

                select.on('change', function () {
                    var values = $(this).val();

                    if (!values || values.length === 0 || values.includes("")) {
                        column.search('').draw();
                        return;
                    }

                    var regex = values
                        .map(v => '^' + $.fn.dataTable.util.escapeRegex(v) + '$')
                        .join('|');

                    column.search(regex, true, false).draw();
                });
            });
        }
    });

});
</script>
</body>
</html>
"""

output_file.write_text(html)
PYTHON_HTML
RUN_ANY=1
fi

    MQ_EXIT=$?
    conda deactivate >/dev/null 2>&1 || true

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
}

cleaning_up () {
ABR_DIR="$OUTPUT_PATH/raw/abritamr"

if [[ -d "$ABR_DIR" ]]; then
    for sub in before after; do
        if [[ -d "$ABR_DIR/$sub" ]]; then
            find "$ABR_DIR/$sub" -mindepth 1 -maxdepth 1 -type d -exec rm -rf -- {} +
        fi
    done
fi

MQC_DIR="$OUTPUT_PATH/multiqc_reports"

if [[ -d "$MQC_DIR" ]]; then
    find "$MQC_DIR" \
        -mindepth 1 -maxdepth 1 \
        -type d \
        -exec rm -rf -- {} +
fi

if [[ $CONTIG_MODE -eq 1 ]]; then
    rm -rf "${OUTPUT_PATH}/contigs_before"
fi

rm -f "$OUTPUT_PATH/multiqc_reports/abritamr_combined.tsv"
rm -f "$OUTPUT_PATH/multiqc_reports/abricate_combined.tsv"
}

# =========================
# RUN PIPELINE FOR ALL SAMPLES (90% CPU, thread-aware)
# =========================

if command -v nproc >/dev/null 2>&1; then
    TOTAL_CORES=$(nproc)
elif command -v getconf >/dev/null 2>&1; then
    TOTAL_CORES=$(getconf _NPROCESSORS_ONLN)
else
    TOTAL_CORES=1
fi

CORES_ALLOWED=$(( TOTAL_CORES * 90 / 100 ))   # 90% of total cores
if [[ $CORES_ALLOWED -lt 1 ]]; then CORES_ALLOWED=1; fi

# threads to allocate to each process_sample invocation
# choose based on how heavy each job is (example: 4 or 8). Adjust to taste.
THREADS_PER_JOB=${THREADS_PER_JOB:-$THREADS}

# compute how many concurrent jobs we should run
MAX_JOBS=$(( CORES_ALLOWED / THREADS_PER_JOB ))
if [[ $MAX_JOBS -lt 1 ]]; then MAX_JOBS=1; fi

# ------------------------------
# PID TRACKING (for competitive mode)
# ------------------------------
declare -a PIDS=()

# ------------------------------
# Cleanup finished PIDs
# ------------------------------
cleanup_finished_pids() {
    local new_pids=()
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            new_pids+=("$pid")   # still running
        else
            wait "$pid" 2>/dev/null
        fi
    done
    PIDS=("${new_pids[@]}")  # reindex
}

run_stage1() {
    local SAMPLE="$1"
    local R1="$2"
    local R2="$3"

    if [[ "${CONTIG_MODE:-0}" -eq 0 ]]; then
        run_fastp "$SAMPLE" "$R1" "$R2" || return 1
        run_spades "$SAMPLE" || return 1
    fi
}

run_stage2() {
    local SAMPLE="$1"

    run_quast_before "$SAMPLE" || return 1
    run_checkm2_before "$SAMPLE" || return 1
    run_filter "$SAMPLE" || return 1
}

run_stage3() {
    local SAMPLE="$1"

    run_quast_after "$SAMPLE" || return 1
    run_checkm2_after "$SAMPLE" || return 1
}

run_stage4() {
    local SAMPLE="$1"

    if [[ "${KRAKEN2_MODE:-0}" -eq 1 ]]; then
        run_kraken2_before "$SAMPLE" || return 1
        run_kraken2_after "$SAMPLE" || return 1
    fi
}

run_stage5() {

    # -------------------------
    # GTDBTK (independent B/A)
    # -------------------------
    if [[ "${GTDBTK_MODE:-0}" -eq 1 ]]; then
        run_gtdbtk_before &
        PID_GTDBTK_B=$!

        run_gtdbtk_after &
        PID_GTDBTK_A=$!
    fi

    # -------------------------
    # ABRITAMR (A depends on B)
    # -------------------------
    if [[ "${ABRITAMR_MODE:-0}" -eq 1 ]]; then
        run_abritamr_before &
        PID_ABRITAMR_B=$!
    fi

    # -------------------------
    # ABRICATE (A depends on B)
    # -------------------------
    if [[ "${ABRICATE_MODE:-0}" -eq 1 ]]; then
        run_abricate_before &
        PID_ABRICATE_B=$!
    fi

    # -------------------------
    # Wait for ABRITAMR before, then start after
    # -------------------------
    if [[ -n "$PID_ABRITAMR_B" ]]; then
        wait "$PID_ABRITAMR_B"
        run_abritamr_after &
        PID_ABRITAMR_A=$!
    fi

    # -------------------------
    # Wait for ABRICATE before, then start after
    # -------------------------
    if [[ -n "$PID_ABRICATE_B" ]]; then
        wait "$PID_ABRICATE_B"
        run_abricate_after &
        PID_ABRICATE_A=$!
    fi

    wait
    # -------------------------
    # FINAL AGGREGATION & CLEANUP
    # -------------------------
    run_multiqc || return 1
    sleep 0.1
    cleaning_up || return 1
    sleep 0.1
}

process_competitive_mode() {

    # ---------- STAGE 1: fastp + spades ----------
    if [[ "${CONTIG_MODE:-0}" -eq 0 ]]; then
        for SAMPLE in "${SAMPLES[@]}"; do
            R1="${PAIRS["$SAMPLE,1"]:-}"
            R2="${PAIRS["$SAMPLE,2"]:-}"

            cleanup_finished_pids
            while (( ${#PIDS[@]} >= MAX_JOBS )); do
                sleep 0.1
                cleanup_finished_pids
            done

            (
                export OMP_NUM_THREADS="$THREADS_PER_JOB"
                THREADS="$THREADS_PER_JOB"
                run_stage1 "$SAMPLE" "$R1" "$R2"
            ) &

            PIDS+=($!)
        done
        wait
        PIDS=()  # BARRIER: all samples finish Stage 1
        else
        # CONTIG_MODE enabled → skip fastp + spades
            for SAMPLE in "${SAMPLES[@]}"; do
                update_status "$SAMPLE" "FASTP" "SKIPPED"
                update_status "$SAMPLE" "SPADES" "SKIPPED"
            done
        fi

    # ---------- STAGE 2: quast_before + checkm2_before + filter ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        cleanup_finished_pids
        while (( ${#PIDS[@]} >= MAX_JOBS )); do
            sleep 0.1
            cleanup_finished_pids
        done

        (
            export OMP_NUM_THREADS="$THREADS_PER_JOB"
            THREADS="$THREADS_PER_JOB"
            run_stage2 "$SAMPLE"
        ) &

        PIDS+=($!)
    done
    wait
    PIDS=()  # BARRIER: all samples finish Stage 2

    # ---------- STAGE 3: quast_after + checkm2_after ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        cleanup_finished_pids
        while (( ${#PIDS[@]} >= MAX_JOBS )); do
            sleep 0.1
            cleanup_finished_pids
        done

        (
            export OMP_NUM_THREADS="$THREADS_PER_JOB"
            THREADS="$THREADS_PER_JOB"
            run_stage3 "$SAMPLE"
        ) &

        PIDS+=($!)
    done
    wait
    PIDS=()  # BARRIER: all samples finish Stage 3

        # ---------- STAGE 4: kraken_before & kraken2_after ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        cleanup_finished_pids
        while (( ${#PIDS[@]} >= MAX_JOBS )); do
            sleep 0.1
            cleanup_finished_pids
        done

        (
            export OMP_NUM_THREADS="$THREADS_PER_JOB"
            THREADS="$THREADS_PER_JOB"
            run_stage4 "$SAMPLE"
        ) &

        PIDS+=($!)
    done
    wait
    PIDS=()  # BARRIER: all samples finish Stage 4

    # ---------- STAGE 5: final summary ----------
    run_stage5
}

process_sequential_mode() {

    if [[ "${CONTIG_MODE:-0}" -eq 0 ]]; then
        for SAMPLE in "${SAMPLES[@]}"; do
            R1="${PAIRS["$SAMPLE,1"]:-}"
            R2="${PAIRS["$SAMPLE,2"]:-}"
            run_stage1 "$SAMPLE" "$R1" "$R2"
        done
    else
        # CONTIG_MODE is enabled → skip Stage 1
        for SAMPLE in "${SAMPLES[@]}"; do
            update_status "$SAMPLE" "FASTP" "SKIPPED"
            update_status "$SAMPLE" "SPADES" "SKIPPED"
        done
    fi

    # ---------- STAGE 2 ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        run_stage2 "$SAMPLE"
    done

    # ---------- STAGE 3 ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        run_stage3 "$SAMPLE"
    done

    # ---------- STAGE 4 ----------
    for SAMPLE in "${SAMPLES[@]}"; do
        run_stage4 "$SAMPLE"
    done

    # ---------- STAGE 5: final summary ----------
    run_stage5
}

# Execution dispatcher
if [[ "$COMPETITIVE_MODE" -eq 1 ]]; then
    process_competitive_mode
else
    process_sequential_mode
fi

# =========================
# END TIMER + FINAL STATUS
# =========================
clear    # clear screen before showing final status

echo "QAssfilt Pipeline final status:"
column -t -s$'\t' "$STATUS_FILE"
echo ""
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
echo "Start date: $(date -d @"$START_TIME" '+%Y-%m-%d %H:%M:%S')" | tee -a $PARAM_LOG
echo "End date:   $(date -d @"$END_TIME" '+%Y-%m-%d %H:%M:%S')" | tee -a $PARAM_LOG
echo "Total runtime: ${RUNTIME} seconds (~$(printf '%02d:%02d:%02d\n' \
     $((RUNTIME/3600)) $(((RUNTIME/60)%60)) $((RUNTIME%60))))" | tee -a $PARAM_LOG
echo ""
echo "----------------------------------------------------------"
echo "               QAssfilt Pipeline completed!"
echo ""
printf "%-18s : %s\n" "Please find the output here"              "$(realpath -m "$OUTPUT_PATH")"
echo ""
echo "All rights reserved. © 2025 QAssfilt v${VERSION_QAssfilt}, Samrach Han" | tee -a $PARAM_LOG
echo ""
echo "Citation: Han S., Khan F., Guillard B., Cheng S., Rahi P. (2025). QAssfilt Pipeline. GitHub: https://github.com/hsamrach/QAssfilt" | tee -a $PARAM_LOG
