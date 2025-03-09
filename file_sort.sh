#!/bin/bash
# by Thibaut LOMBARD
#./file_sorter.sh -d /path/to/dir -m size -o desc -p column
#./file_sorter.sh -d `pwd` -s 5Mb -c kmeans -1 size -2 extension

# Script Name: file_sorter.sh
# Usage: ./file_sorter.sh [options]

# Log files
DEBUG_LOG="debug.log"
RESULT_LOG="result.log"

# Default values
DIR="."
SIZE_FILTER=""
SORT_MODE="size"
META_ORDER="desc"
DISPLAY_MODE="column"
COMBINED_SORT="no"
ML_ALGO="bandits"
CLASSIFIER1="size"
CLASSIFIER2=""
CLASSIFIER3=""
CLASSIFIER4=""
CLASSIFIER5=""

# Arrays to store file details
declare -a FILE_NAMES
declare -a FILE_DATES
declare -a FILE_EXTS
declare -a FILE_SIZES_MB
declare -a FILE_SIZES_GB
declare -a FILE_FOLDERS

# Function to log debug messages
log_debug() {
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$DEBUG_LOG"
}

# Function to log results
log_result() {
    echo "$1" >> "$RESULT_LOG"
}

# Function to parse size filter
parse_size() {
    case "$1" in
        *M) echo "${1%M} * 1024 * 1024" | bc ;;
        *G) echo "${1%G} * 1024 * 1024 * 1024" | bc ;;
        *) echo "$1" ;;
    esac
}

# Function to collect file details with size filter
collect_file_details() {
    log_debug "Collecting file details from $DIR with size filter $SIZE_FILTER"
    local files=($(find "$DIR" -type f))
    local index=0

    for file in "${files[@]}"; do
        local size_bytes=$(stat --format="%s" "$file")
        if [ -n "$SIZE_FILTER" ] && [ "$(echo "$size_bytes < $SIZE_FILTER" | bc)" -eq 1 ]; then
            log_debug "Excluding $file (size $size_bytes bytes < $SIZE_FILTER bytes)"
            continue
        fi
        FILE_NAMES[$index]=$(basename "$file")
        FILE_DATES[$index]=$(stat --format="%Y" "$file" | xargs -I {} date -d @{} '+%Y-%m-%d %H:%M:%S')
        FILE_EXTS[$index]=$(echo "$file" | awk -F'.' '{if (NF>1) print $NF; else print "no_ext"}')
        FILE_SIZES_MB[$index]=$(echo "scale=2; $size_bytes / 1024 / 1024" | bc)
        FILE_SIZES_GB[$index]=$(echo "scale=2; $size_bytes / 1024 / 1024 / 1024" | bc)
        FILE_FOLDERS[$index]=$(dirname "$file")
        ((index++))
    done

    log_debug "Collected details for $index files after filtering"
    printf '%s\n' "${FILE_EXTS[@]}" | sort -u > /tmp/extensions_list
}

# Sorting functions using arrays
sort_by_size() {
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        echo "${FILE_SIZES_MB[$i]} ${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_GB[$i]}"
    done | sort -n${META_ORDER:0:1} | awk '{print $2 " " $3 " " $4 " " $1 " " $5}'
}

sort_by_name() {
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        echo "${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}"
    done | sort ${META_ORDER} | awk '{print $1 " " $2 " " $3 " " $4 " " $5}'
}

sort_by_folder() {
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        echo "${FILE_FOLDERS[$i]} ${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}"
    done | sort ${META_ORDER} | awk '{print $2 " " $3 " " $1 " " $4 " " $5}'
}

sort_by_extension() {
    local extensions=($(cat /tmp/extensions_list))
    log_result "Sorting by extensions: ${extensions[*]}"
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        echo "${FILE_EXTS[$i]} ${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}"
    done | sort ${META_ORDER} | awk '{print $2 " " $3 " " $4 " " $5 " " $6}'
}

sort_by_date() {
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        echo "${FILE_DATES[$i]} ${FILE_NAMES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}"
    done | sort ${META_ORDER} | awk '{print $2 " " $1 " " $3 " " $4 " " $5}'
}

# Combined sort with ML simulation
combined_sort() {
    log_debug "Starting combined sort with $ML_ALGO"
    if [ "$ML_ALGO" == "bandits" ]; then
        bandits_sort
    else
        kmeans_sort
    fi
}

# Simulated Bandits method
bandits_sort() {
    local rewards=()
    local counts=()
    local ext_weights=($(cat /tmp/extensions_list | awk '{print 1/NR}'))

    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        local ext_index=$(printf '%s\n' "${FILE_EXTS[@]}" | grep -n "^${FILE_EXTS[$i]}$" | cut -d: -f1)
        ext_index=$((ext_index-1))
        local weight=${ext_weights[$ext_index]:-1}
        rewards[$i]=$(echo "${FILE_SIZES_MB[$i]} * $weight" | bc)
        counts[$i]=1
    done

    local result=""
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        local ucb=$(echo "${rewards[$i]} / ${counts[$i]} + sqrt(2 * l(${#FILE_NAMES[@]}) / ${counts[$i]})" | bc -l)
        result="$result$ucb ${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}\n"
    done
    echo -e "$result" | sort -nr | cut -d' ' -f2-

    log_result "Bandits Chart (Size in MB with Extension Weights):"
    draw_bandits_chart "${rewards[@]}"
}

# Calculate WCSS for K-means
calculate_wcss() {
    local sizes_mb=("$1")
    local k="$2"
    local max_size=$(printf '%s\n' "${sizes_mb[@]}" | sort -nr | head -1)
    local step=$(echo "$max_size / $k" | bc)
    local wcss=0

    for size in "${sizes_mb[@]}"; do
        local cluster=$(echo "$size / $step" | bc)
        local centroid=$(echo "$cluster * $step + $step / 2" | bc)
        local diff=$(echo "$size - $centroid" | bc)
        local squared_diff=$(echo "$diff * $diff" | bc)
        wcss=$(echo "$wcss + $squared_diff" | bc)
    done
    echo "$wcss"
}

# Elbow method to determine optimal clusters
elbow_method() {
    local sizes_mb=("$@")
    local wcss_values=()
    local max_k=5

    log_debug "Running Elbow method for K-means"
    log_result "Elbow Method WCSS Values:"

    for ((k=1; k<=$max_k; k++)); do
        wcss=$(calculate_wcss "${sizes_mb[*]}" "$k")
        wcss_values[$k]="$wcss"
        log_result "k=$k, WCSS=$wcss"
    done

    local optimal_k=1
    local prev_diff=""
    for ((k=2; k<=$max_k; k++)); do
        local diff=$(echo "${wcss_values[$((k-1))]} - ${wcss_values[$k]}" | bc)
        if [ -n "$prev_diff" ] && [ "$(echo "$prev_diff - $diff > 0" | bc)" -eq 1 ]; then
            optimal_k=$((k-1))
            break
        fi
        prev_diff="$diff"
    done

    log_result "Optimal k (Elbow point): $optimal_k"
    echo "$optimal_k"
}

# ASCII Scatterplot function
draw_scatterplot() {
    local sizes_mb=("$1")
    local clusters=("$2")
    local k="$3"
    local max_size=$(printf '%s\n' "${sizes_mb[@]}" | sort -nr | head -1)
    local width=50
    local height=$((k + 1))

    declare -A grid
    for ((y=0; y<height; y++)); do
        for ((x=0; x<width; x++)); do
            grid[$y,$x]=" "
        done
    done

    for ((i=0; i<${#sizes_mb[@]}; i++)); do
        local x=$(echo "${sizes_mb[$i]} * $width / $max_size" | bc)
        local y=${clusters[$i]}
        if [ "$x" -ge "$width" ]; then x=$((width-1)); fi
        grid[$y,$x]="*"
    done

    log_result "Scatterplot (X: Size in MB scaled to $max_size MB, Y: Cluster 0-$((k-1))):"
    for ((y=height-1; y>=0; y--)); do
        local row="$y |"
        for ((x=0; x<width; x++)); do
            row="$row${grid[$y,$x]}"
        done
        log_result "$row"
    done
    log_result "   +$(printf '%*s' $width '' | tr ' ' '-')+"
    log_result "     0$(printf '%*s' $((width-2)) '')$max_size"
    log_result "Extensions detected: $(cat /tmp/extensions_list | tr '\n' ' ')"
}

# Simulated K-means with Elbow method
kmeans_sort() {
    optimal_k=$(elbow_method "${FILE_SIZES_MB[@]}")
    local max_size=$(printf '%s\n' "${FILE_SIZES_MB[@]}" | sort -nr | head -1)
    local step=$(echo "$max_size / $optimal_k" | bc)

    local clusters=()
    local result=""
    for ((i=0; i<${#FILE_NAMES[@]}; i++)); do
        local cluster=$(echo "${FILE_SIZES_MB[$i]} / $step" | bc)
        clusters[$i]=$cluster
        result="$result$cluster ${FILE_NAMES[$i]} ${FILE_DATES[$i]} ${FILE_FOLDERS[$i]} ${FILE_SIZES_MB[$i]} ${FILE_SIZES_GB[$i]}\n"
    done
    result=$(echo -e "$result" | sort -nr | cut -d' ' -f2-)

    log_result "K-means Chart (Size Clusters with k=$optimal_k):"
    draw_kmeans_chart "${FILE_SIZES_MB[@]}" "$step" "$optimal_k"
    draw_scatterplot "${FILE_SIZES_MB[@]}" "${clusters[@]}" "$optimal_k"

    echo "$result"
}

# Draw Bandits chart (ASCII)
draw_bandits_chart() {
    local rewards=("$@")
    log_result "Reward Distribution:"
    log_result "+----+----------+"
    log_result "| Id | Reward   |"
    log_result "+----+----------+"
    for ((i=0; i<${#rewards[@]}; i++)); do
        log_result "| $i  | ${rewards[$i]} MB |"
    done
    log_result "+----+----------+"
}

# Draw K-means chart (ASCII)
draw_kmeans_chart() {
    local sizes_mb=("$1")
    local step="$2"
    local k="$3"
    log_result "Cluster Distribution (k=$k):"
    log_result "+--------+------+"
    log_result "| Cluster| Size |"
    log_result "+--------+------+"
    for size in "${sizes_mb[@]}"; do
        local cluster=$(echo "$size / $step" | bc)
        log_result "| $cluster      | $size |"
    done
    log_result "+--------+------+"
}

# Display function
display_files() {
    local files="$1"
    if [ "$DISPLAY_MODE" == "column" ]; then
        echo "$files" | column -t
    else
        echo "$files"
    fi
}

# Log results in table format
log_results_table() {
    local result="$1"
    log_result "Results Table ($SORT_MODE, $META_ORDER):"
    log_result "+---------------------+---------------------+---------------------+------------+------------+"
    log_result "| Filename            | Date                | Directory           | Size (MB)  | Size (GB)  |"
    log_result "+---------------------+---------------------+---------------------+------------+------------+"
    echo "$result" | while read -r name date dir size_mb size_gb; do
        printf "| %-19s | %-19s | %-19s | %-10s | %-10s |\n" "$name" "$date" "$dir" "$size_mb" "$size_gb" >> "$RESULT_LOG"
    done
    log_result "+---------------------+---------------------+---------------------+------------+------------+"
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--directory) DIR="$2"; shift ;;
        -s|--size) SIZE_FILTER=$(parse_size "$2"); shift ;;
        -m|--mode) SORT_MODE="$2"; shift ;;
        -o|--order) META_ORDER="$2"; shift ;;
        -p|--display) DISPLAY_MODE="$2"; shift ;;
        -c|--combined) COMBINED_SORT="yes"; ML_ALGO="$2"; shift ;;
        -1|--class1) CLASSIFIER1="$2"; shift ;;
        -2|--class2) CLASSIFIER2="$2"; shift ;;
        -3|--class3) CLASSIFIER3="$2"; shift ;;
        -4|--class4) CLASSIFIER4="$2"; shift ;;
        -5|--class5) CLASSIFIER5="$2"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Main execution
log_debug "Script started with DIR=$DIR, SIZE_FILTER=$SIZE_FILTER, SORT_MODE=$SORT_MODE, META_ORDER=$META_ORDER, DISPLAY_MODE=$DISPLAY_MODE"

# Clean up temporary files
rm -f /tmp/extensions_list

# Collect file details with size filtering
collect_file_details

# Check if any files remain after filtering
if [ ${#FILE_NAMES[@]} -eq 0 ]; then
    log_debug "No files meet the size filter criteria"
    log_result "No files found with size >= $SIZE_FILTER bytes"
    echo "No files found with size >= $SIZE_FILTER bytes"
    exit 0
fi

# Perform sorting based on collected data
if [ "$COMBINED_SORT" == "yes" ]; then
    result=$(combined_sort)
else
    case "$SORT_MODE" in
        size) result=$(sort_by_size) ;;
        name) result=$(sort_by_name) ;;
        folder) result=$(sort_by_folder) ;;
        extension) result=$(sort_by_extension) ;;
        date) result=$(sort_by_date) ;;
        *) echo "Invalid sort mode"; exit 1 ;;
    esac
fi

# Display and log results
display_files "$result"
log_results_table "$result"

log_debug "Script completed"
rm -f /tmp/extensions_list
