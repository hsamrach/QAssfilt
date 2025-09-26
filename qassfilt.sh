#!/usr/bin/env bash
source ~/miniconda3/etc/profile.d/conda.sh
set -euo pipefail

# =========================
# CONFIGURATION WITH DEFAULTS
# =========================
INPUT_PATH=""
OUTPUT_PATH=""
INPUT_DIR_DEPTH=1
CHECKM2DB_PATH=""
SPADES_THREADS=32
FASTP_THREADS=16
CHECKM2_THREADS=16
QUAST_REFERENCE=""
QUAST_THREADS=16
SEQKIT_MIN_COV=10
SEQKIT_MIN_LENGTH=500
SKIP_STEPS="" # Skip any step you want
CONTIG_MODE=0
INIT_MODE=0
VERSION_QAssfilt=1.0

# Free-form options
FASTP_EXTRA_OPTS=""
SPADES_EXTRA_OPTS=""

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
        --SPADES_THREADS|-st) SPADES_THREADS="$2"; shift 2 ;;
        --FASTP_THREADS|-ft) FASTP_THREADS="$2"; shift 2 ;;
        --CHECKM2_THREADS|-ct) CHECKM2_THREADS="$2"; shift 2 ;;
        --QUAST_THREADS|-qt) QUAST_THREADS="$2"; shift 2 ;;
        --QUAST_REFERENCE|-qr) QUAST_REFERENCE="$2"; shift 2 ;;
        --SEQKIT_MIN_COV|-mc) SEQKIT_MIN_COV="$2"; shift 2 ;;
        --SEQKIT_MIN_LENGTH|-ml) SEQKIT_MIN_LENGTH="$2"; shift 2 ;;
        --skip) SKIP_STEPS="$2"; shift 2 ;;
        --fastp) FASTP_EXTRA_OPTS="$2"; shift 2 ;;
        --spades) SPADES_EXTRA_OPTS="$2"; shift 2 ;;
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
			echo "  --CHECKM2DB_PATH, -d [DIR]      	Path to checkm2 database directory (optional; if not given, pipeline will auto-manage)"
            echo "  --SPADES_THREADS, -st [INT]     	Threads for spades (default: $SPADES_THREADS)"
            echo "  --FASTP_THREADS, -ft [INT]      	Threads for fastp (default: $FASTP_THREADS)"
            echo "  --CHECKM2_THREADS, -ct [INT]    	Threads for CheckM2 (default: $CHECKM2_THREADS)"
            echo "  --QUAST_THREADS, -qt [INT]      	Threads for QUAST (default: $QUAST_THREADS)"
            echo "  --QUAST_REFERENCE, -qr [FILE]   	Path to reference sequence for QUAST (optional)"
            echo "  --SEQKIT_MIN_COV, -mc [INT]     	Minimum (≤) contig coverage to be filtered (default: $SEQKIT_MIN_COV)"
            echo "  --SEQKIT_MIN_LENGTH, -ml [INT]  	Minimum (≤) contig length to be filtered (default: $SEQKIT_MIN_LENGTH)"
            echo "  --skip [LIST]                 	Skip tool(s) you don't want to use in the pipeline (space-separated)"
            echo "                             		e.g.: --skip \"FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a MULTIQC\""
            echo "  --fastp [STRING]                	Options/parameters to pass directly to fastp"
            echo "                             		e.g.: \"-q 30 -u 30 -e 15 -l 50 -5 -3\""
            echo "  --spades [STRING]               	Options/parameters to pass directly to SPAdes"
            echo "                             		e.g.: \"--isolate --careful --cov-cutoff auto\""
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
    REQUIRED_ENVS=(qassfilt_fastp qassfilt_spades qassfilt_quast qassfilt_checkm2 qassfilt_seqkit qassfilt_multiqc)
    REQUIRED_TOOLS=(fastp spades.py quast.py checkm2 seqkit multiqc)

    # Clear SKIP_STEPS; populate exactly from user input
    SKIP_STEPS=()

    local skip_checkm2_a=0
    local skip_checkm2_b=0

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
                ;;
            quast-b)
                SKIP_STEPS+=(QUAST-b)
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
            *)
                echo "[!] Warning: Unknown skip step '$s', ignoring."
                ;;
        esac
    done

    # Remove duplicates
    SKIP_STEPS=($(printf "%s\n" "${SKIP_STEPS[@]}" | sort -u))

    # Env/tool skipping for QUAST
    if [[ " ${SKIP_STEPS[*]} " =~ QUAST-a && " ${SKIP_STEPS[*]} " =~ QUAST-b ]]; then
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
    step="${step^^}"
    for s in "${SKIP_STEPS[@]}"; do
        if [[ "$step" == "${s^^}" ]]; then
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
    [qassfilt_multiqc]="MULTIQC"
)

declare -A TOOLS
TOOLS=(
    [qassfilt_fastp]="fastp"
    [qassfilt_spades]="spades.py"
    [qassfilt_quast]="quast.py"
    [qassfilt_checkm2]="checkm2"
    [qassfilt_seqkit]="seqkit"
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

        # Create env if not exist (empty env, no package)
        if ! conda env list | awk '{print $1}' | grep -q "^${ENV}$"; then
            echo "⚠️  Environment '$ENV' not found. Creating..."
            conda create -y -n "$ENV" python=3.10 \
                || { echo "❌ Failed to create env $ENV"; exit 1; }
        else
            echo "✅ Environment '$ENV' exists."
			  # Activate environment to check tool version
            conda activate "$ENV" || { echo "❌ Failed to activate env $ENV"; exit 1; }

            case "$TOOL" in
				fastp)
					if command -v fastp &>/dev/null; then
						fastp_ver=$(fastp --version 2>/dev/null) || { echo "❌ Could not get fastp version!"; exit 1; }
						echo "✅ fastp version: $fastp_ver"
					else
						echo "❌ fastp not found in $ENV!"
						exit 1
					fi
					;;
				spades.py)
					if command -v spades.py &>/dev/null; then
						spades_ver=$(spades.py --version 2>/dev/null) || { echo "❌ Could not get SPAdes version!"; exit 1; }
						echo "✅ SPAdes version: $spades_ver"
					else
						echo "❌ SPAdes not found in $ENV!"
						exit 1
					fi
					;;
				seqkit)
					if command -v seqkit &>/dev/null; then
						seqkit_ver=$(seqkit version 2>/dev/null) || { echo "❌ Could not get seqkit version!"; exit 1; }
						echo "✅ seqkit version: $seqkit_ver"
					else
						echo "❌ seqkit not found in $ENV!"
						exit 1
					fi
					;;
				quast.py)
					if command -v quast.py &>/dev/null; then
						quast_ver=$(quast.py --version 2>/dev/null) || { echo "❌ Could not get QUAST version!"; exit 1; }
						echo "✅ QUAST version: $quast_ver"
					else
						echo "❌ QUAST not found in $ENV!"
						exit 1
					fi
					;;
				multiqc)
					if command -v multiqc &>/dev/null; then
						multiqc_ver=$(multiqc --version 2>/dev/null) || { echo "❌ Could not get MultiQC version!"; exit 1; }
						echo "✅ MultiQC version: $multiqc_ver"
					else
						echo "❌ MultiQC not found in $ENV!"
						exit 1
					fi
					;;
				checkm2)
					if command -v checkm2 &>/dev/null; then
						checkm2_ver=$(checkm2 --version 2>/dev/null) || { echo "❌ Could not get CheckM2 version!"; exit 1; }
						echo "✅ CheckM2 version: $checkm2_ver"
					else
						echo "❌ CheckM2 not found in $ENV!"
						exit 1
					fi
					;;
				*)
					echo "❌ Unknown tool $TOOL for environment $ENV"
					exit 1
					;;
			esac

			conda deactivate
        fi

        conda activate "$ENV"
        BIN_PATH="$CONDA_PREFIX/bin"

        # Install tool manually if missing
        if ! command -v "$TOOL" &>/dev/null; then
            echo "⚠️  $TOOL not found in $ENV. Installing $TOOL..."
            case "$TOOL" in
				fastp)
					echo "⚠️ Installing fastp..."

					# Remove old folder if exists
					[[ -d fastp_dir ]] && rm -rf fastp_dir

					# Download the latest build
					wget http://opengene.org/fastp/fastp || { echo "❌ Failed to download fastp"; exit 1; }
					chmod a+x ./fastp

					# Store under conda share folder
					mkdir -p "$CONDA_PREFIX/share/fastp/bin"
					mv fastp "$CONDA_PREFIX/share/fastp/bin/"

					# Symlink to $BIN_PATH
					ln -sf "$CONDA_PREFIX/share/fastp/bin/fastp" "$BIN_PATH/fastp"

					# Verify installation
					if ! fastp --version &>/dev/null; then
						echo "❌ fastp installation failed or binary not working!"
						exit 1
					fi

					echo "[INFO] fastp installation complete: $(fastp --version)"
					;;

				spades.py)
					echo "⚠️ Installing SPAdes..."
					[[ -d SPAdes-4.2.0-Linux ]] && rm -rf SPAdes-4.2.0-Linux

					wget -O SPAdes-4.2.0-Linux.tar.gz https://github.com/ablab/spades/releases/download/v4.2.0/SPAdes-4.2.0-Linux.tar.gz
					tar -xzf SPAdes-4.2.0-Linux.tar.gz

					# Move SPAdes into the conda environment share folder
					mkdir -p "$CONDA_PREFIX/share/"
					mv SPAdes-4.2.0-Linux "$CONDA_PREFIX/share/spades"

					# Symlink the main entry point into $BIN_PATH
					ln -sf "$CONDA_PREFIX/share/spades/bin/spades.py" "$BIN_PATH/spades.py"

					# Optional: symlink all other executables too
					for exe in "$CONDA_PREFIX/share/spades/bin/"*; do
						ln -sf "$exe" "$BIN_PATH/$(basename "$exe")"
					done

					rm -f SPAdes-4.2.0-Linux.tar.gz
					echo "[INFO] SPAdes installation complete."
					;;

				quast.py)
					echo "⚠️ Installing QUAST..."
					
					# Remove old folder if exists
					[[ -d quast ]] && rm -rf quast
					
					# Clone repository
					git clone https://github.com/ablab/quast.git
					cd quast || { echo "❌ Failed to enter quast folder"; exit 1; }
					
					# Install QUAST and dependencies
					python setup.py install || { echo "❌ QUAST installation failed"; exit 1; }
					
					cd ..
					rm -rf quast
					
					# Verify installation
					if ! quast.py --version &>/dev/null; then
						echo "❌ QUAST installation failed, binary not working!"
						exit 1
					fi

					echo "[INFO] QUAST installation complete: $(quast.py --version)"
					;;

				checkm2)
					echo "⚠️ Installing CheckM2 automatically..."

					# Remove old checkm2 folder if it exists
					[[ -d checkm2 ]] && rm -rf checkm2

					# Clone repository recursively to get all submodules
					git clone --recursive https://github.com/chklovski/checkm2.git
					cd checkm2 || { echo "Failed to enter checkm2 folder"; exit 1; }

					# Always install/update environment dependencies from checkm2.yml
					echo "[INFO] Installing dependencies from checkm2.yml"
					conda env update -n qassfilt_checkm2 -f checkm2.yml --prune

					# Activate the environment
					conda activate qassfilt_checkm2 || { echo "Failed to activate 'qassfilt_checkm2' environment"; exit 1; }

					# Install CheckM2 itself
					echo "[INFO] Installing CheckM2 in the environment"
					python setup.py install

					# Go back and clean up
					cd ..
					rm -rf checkm2

					echo "[INFO] CheckM2 installation complete."

					# Verify installation
					if checkm2 --version >/dev/null 2>&1; then
						echo "✅ CheckM2 is installed and ready."
					else
						echo "❌ CheckM2 installation failed!"
						exit 1
					fi

					conda deactivate
					;;

				seqkit)
					wget -O seqkit.tar.gz https://github.com/shenwei356/seqkit/releases/download/v2.10.1/seqkit_linux_amd64.tar.gz
					tar -xzf seqkit.tar.gz
					mv seqkit "$BIN_PATH/"
					rm -f seqkit.tar.gz
					    # Check version to confirm install worked
					if ! "$BIN_PATH/seqkit" version &>/dev/null; then
						echo "❌ seqkit installation failed, binary not working!"
						exit 1
					fi

					echo "[INFO] seqkit installation complete: $($BIN_PATH/seqkit version)"
					;;

				multiqc)
					echo "⚠️ Installing MultiQC..."
					pip install --upgrade multiqc || { echo "❌ Failed to install MultiQC"; exit 1; }

					# Check version to confirm install worked
					if ! multiqc --version &>/dev/null; then
						echo "❌ MultiQC installation failed, binary not working!"
						exit 1
					fi

					echo "[INFO] MultiQC installation complete: $(multiqc --version)"
					;;
            esac
        else
            echo "✅ $TOOL already installed in $ENV."
        fi

        # Show tool version
        if [[ "$TOOL" == "seqkit" ]]; then
            seqkit version
        else
            "$TOOL" --version || echo "⚠️  Could not get version for $TOOL"
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
                    echo "⚠️  CheckM2 DB not found, downloading..."
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
    echo "QAssfilt required environments, tools, and CheckM2 database are available."
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

# =========================
# PRINT INTRO ONCE
# =========================
print_intro() {
    echo "You have specified the following options:"
    echo "    INPUT_PATH          = $INPUT_PATH"
	echo "    CONTIG_MODE         = ${CONTIG_MODE_DISPLAY}"
	echo "    INPUT_DIR_DEPTH     = $INPUT_DIR_DEPTH"
	echo "    CHECKM2DB_PATH      = $CHECKM2DB_PATH"
	echo "    OUTPUT_PATH         = $OUTPUT_PATH"
    echo "    SPADES_THREADS      = $SPADES_THREADS"
    echo "    FASTP_THREADS       = $FASTP_THREADS"
    echo "    CHECKM2_THREADS     = $CHECKM2_THREADS"
    echo "    QUAST_THREADS       = $QUAST_THREADS"
    echo "    QUAST_REFERENCE     = $QUAST_REFERENCE"
    echo "    SEQKIT_MIN_COV      = $SEQKIT_MIN_COV"
    echo "    SEQKIT_MIN_LENGTH   = $SEQKIT_MIN_LENGTH"
    echo "    SKIP_STEPS          = $SKIP_STEPS"
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

# =========================
# update_status - full fixed
# =========================
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
        MULTIQC) COL=9 ;;
        *) echo "Unknown step $STEP"; return ;;
    esac

    # Initialize STATUS_FILE if not exists
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo -e "Sample\tFASTP\tSPADES\tQUAST-b\tCHECKM2-b\tFILTER\tQUAST-a\tCHECKM2-a\tMULTIQC" > "$STATUS_FILE"
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
            ROW=("-" "-" "-" "-" "-" "-" "-" "-" "-")
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
    echo -e "  CONTIG_MODE       : $CONTIG_MODE_DISPLAY"
    echo -e "  INPUT_DIR_DEPTH   : ${CYAN}$INPUT_DIR_DEPTH${RESET}"
    echo -e "  OUTPUT_PATH       : $OUTPUT_PATH"
    echo -e "  CHECKM2DB_PATH    : $CHECKM2DB_PATH"
    echo -e "  SPADES_THREADS    : ${CYAN}$SPADES_THREADS${RESET}"
    echo -e "  FASTP_THREADS     : ${CYAN}$FASTP_THREADS${RESET}"
    echo -e "  CHECKM2_THREADS   : ${CYAN}$CHECKM2_THREADS${RESET}"
    echo -e "  QUAST_THREADS     : ${CYAN}$QUAST_THREADS${RESET}"
    echo -e "  QUAST_REFERENCE   : $QUAST_REFERENCE"
    echo -e "  SEQKIT_MIN_COV    : ${CYAN}$SEQKIT_MIN_COV${RESET}"
    echo -e "  SEQKIT_MIN_LENGTH : ${CYAN}$SEQKIT_MIN_LENGTH${RESET}"
    echo -e "  SKIP_STEPS        : ${SKIP_STEPS[*]}"
    echo -e "  FASTP_EXTRA_OPTS  : ${CYAN}$FASTP_EXTRA_OPTS${RESET}"
    echo -e "  SPADES_EXTRA_OPTS : ${CYAN}$SPADES_EXTRA_OPTS${RESET}"
    echo -e "------------------------------------------------"
	echo -e "QAssfilt sample list available at : ${OUTPUT_PATH}/pipeline_status.tsv"
	echo -e ""
	echo -e "QAssfilt detail logs available at : ${OUTPUT_PATH}/logs"
    echo -e ""
	    if [[ -f "$STATUS_FILE" ]]; then
        TOTAL=$(($(wc -l < "$STATUS_FILE") - 1))
        RUNNED=$(awk 'NR>1 {for(i=2;i<=NF;i++) if($i != "-" ){print $1;break}}' "$STATUS_FILE" | wc -l)
        echo -e "Samples processed: ${CYAN}${RUNNED}${RESET}/${CYAN}${TOTAL}${RESET}"
        echo -e "------------------------------------------------"
    fi
    # Print column header (pinned)
    HEADER_FORMAT="%-45s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n"
    head -1 "$STATUS_FILE" | awk -v fmt="$HEADER_FORMAT" 'BEGIN{FS=OFS="\t"} {printf fmt,$1,$2,$3,$4,$5,$6,$7,$8,$9}'
	echo -e ""

    # -------------------------
    # Only print the current sample row
    # -------------------------
    grep "^$SAMPLE" "$STATUS_FILE" | while IFS=$'\t' read -r sample fastp spades quastb checkm2b filter quasta checkm2a multiqc; do
        for var in fastp spades quastb checkm2b filter quasta checkm2a multiqc; do
            case "${!var}" in
                RUNNING) eval "$var=\"RUNNING\"" ;;
                OK)      eval "$var=\"OK\"" ;;
                FAIL)    eval "$var=\"FAIL\"" ;;
                SKIPPED) eval "$var=\"SKIPPED\"" ;;
                *)       eval "$var=\"-\"" ;;
            esac
        done

        printf "$HEADER_FORMAT" \
            "$sample" "$fastp" "$spades" "$quastb" "$checkm2b" "$filter" "$quasta" "$checkm2a" "$multiqc"
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
    local STEPS=(FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a MULTIQC)
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
    echo -e "Sample\tFASTP\tSPADES\tQUAST-b\tCHECKM2-b\tFILTER\tQUAST-a\tCHECKM2-a\tMULTIQC" > "$STATUS_FILE"
    for SAMPLE in "${SAMPLES[@]}"; do
        echo -e "$SAMPLE\t-\t-\t-\t-\t-\t-\t-\t-" >> "$STATUS_FILE"
    done
fi

# APPLY SKIPS
# =========================
process_skips   # <- normalize skip list
for SAMPLE in "${SAMPLES[@]}"; do
    for STEP in FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a MULTIQC; do
        if is_skipped "$STEP"; then
            update_status "$SAMPLE" "$STEP" "SKIPPED"
        fi
    done
done

# =========================
# MARK SKIPPED STEPS IMMEDIATELY
# =========================
for SAMPLE in "${SAMPLES[@]}"; do
    for STEP in FASTP SPADES QUAST-b CHECKM2-b FILTER QUAST-a CHECKM2-a MULTIQC; do
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
        echo "⚠️  Missing R1 for sample '$SAMPLE'"
        MISSING=1
    fi
    if [[ -z "${PAIRS["$SAMPLE,2"]+x}" ]]; then
        echo "⚠️  Missing R2 for sample '$SAMPLE'"
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
		}  # <-- end of process_sample()
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
		# MULTIQC - combined & separate reports
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
      description: "Extra quality metrics extracted from fastp output"
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
        mkdir -p "${OUTPUT_PATH}/multiqc_reports/qc_combined"
        multiqc "${QC_DIRS[@]}" \
            -o "${OUTPUT_PATH}/multiqc_reports/qc_combined" \
            --title "QAssfilt Assembly Quality Report (QUAST + CheckM2)" \
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
echo "----------------------------------------------------------"
printf "%-18s : %s\n" "Logs"              "${OUTPUT_PATH}/logs"
printf "%-18s : %s\n" "Fastp"             "${OUTPUT_PATH}/fastp_file"
printf "%-18s : %s\n" "SPAdes"            "${OUTPUT_PATH}/spades_file"
printf "%-18s : %s\n" "Contigs (before)"  "${OUTPUT_PATH}/contigs_before"
printf "%-18s : %s\n" "Contigs (filtered)" "${OUTPUT_PATH}/contigs_filtered"
printf "%-18s : %s\n" "QUAST (before)"    "${OUTPUT_PATH}/quast_before"
printf "%-18s : %s\n" "QUAST (after)"     "${OUTPUT_PATH}/quast_after"
printf "%-18s : %s\n" "CheckM2 (before)"  "${OUTPUT_PATH}/checkm2_before"
printf "%-18s : %s\n" "CheckM2 (after)"   "${OUTPUT_PATH}/checkm2_after"
printf "%-18s : %s\n" "MultiQC reports"   "${OUTPUT_PATH}/multiqc_reports"
echo "----------------------------------------------------------"
echo "All rights reserved. © 2025 QAssfilt, Samrach Han"
echo ""