#!/bin/bash
# By Thibaut LOMBARD (LombardWeb)
# file_sort.sh Permit to find recursively all files exceeding an especific size in Mb and sort them by date, filename or size

# Usage message
usage() {
 echo "Usage: $0 <size_in_mb> <directory_path> [-v|--verbose] [--sort-by <date|filename|size>] [--sort-order <asc|desc>]"
 exit 1
}

# Check parameters
if [ $# -lt 2 ]; then
 usage
fi

# Validate size input (positive integer)
min_size_mb="$1"
if ! [[ "$min_size_mb" =~ ^[0-9]+$ ]] || [ "$min_size_mb" -le 0 ]; then
 echo "Error: Size must be a positive integer (in MB)"
 exit 1
fi

# Convert MB to bytes (1MB = 1048576 bytes)
min_size_bytes=$((min_size_mb * 1048576))
search_dir="$2"

# Default sorting options
verbose=false
sort_by="size"
sort_order="desc"  # Default to descending

shift 2  # Shift past size and directory
while [ $# -gt 0 ]; do
 case "$1" in
  -v|--verbose)
   verbose=true
   shift
   ;;
  --sort-by)
   if [ -n "$2" ] && [[ "$2" =~ ^(date|filename|size)$ ]]; then
    sort_by="$2"
    shift 2
   else
    echo "Error: --sort-by must be followed by 'date', 'filename', or 'size'"
    usage
   fi
   ;;
  --sort-order)
   if [ -n "$2" ] && [[ "$2" =~ ^(asc|desc)$ ]]; then
    sort_order="$2"
    shift 2
   else
    echo "Error: --sort-order must be followed by 'asc' or 'desc'"
    usage
   fi
   ;;
  *)
   usage
   ;;
 esac
done

# Validate directory exists
if [ ! -d "$search_dir" ]; then
 echo "Error: Directory '$search_dir' does not exist"
 exit 1
fi

# Log files
debug_file="debug.log"
script_name=$(basename "$0" .sh)
result_file="${script_name}_result_$(date +%Y%m%d_%H%M%S).log"

# Remove existing log files at startup
[ -f "$debug_file" ] && rm "$debug_file"
rm -f "${script_name}_result_[0-9]{8}_[0-9]{6}.log"  # Regex for date: YYYYMMDD_HHMMSS

# Declare arrays
declare -A file_info
declare -a sorted_files

# Counter
count=0

# Flag to track if debug info should be written
has_errors=false

# Function to get file extension
get_extension() {
 filename=$(basename "$1")
 if [[ "$filename" =~ \. ]]; then
  echo "${filename##*.}"
 else
  echo "no_extension"
 fi
}

# Function to get filename without path
get_filename() {
 basename "$1"
}

# Sorting functions
sort_by_date() {
 if [ "$sort_order" = "desc" ]; then
  # Sort by date (descending) with full timestamp
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k1r
 else
  # Sort by date (ascending) with full timestamp
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k1
 fi
}

sort_by_filename() {
 if [ "$sort_order" = "desc" ]; then
  # Sort by filename (descending)
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k3r
 else
  # Sort by filename (ascending)
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k3
 fi
}

sort_by_size() {
 if [ "$sort_order" = "desc" ]; then
  # Sort by size (descending)
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k2nr
 else
  # Sort by size (ascending)
  printf '%s\n' "${sorted_files[@]}" | sort -t'|' -k2n
 fi
}

# Log initial messages to debug if verbose
if [ "$verbose" = true ]; then
 echo "Search started at: $(date)" >> "$debug_file"
 echo "Minimum size in bytes: $min_size_bytes" >> "$debug_file"
fi

# Count total files for progress bar
total_files=$(find "$search_dir" -type f | wc -l)
if [ "$verbose" = true ]; then
 echo "Total files to scan: $total_files" >> "$debug_file"
fi

# Check if pv is installed
if ! command -v pv >/dev/null 2>&1; then
 if [ "$verbose" = true ]; then
  echo "Warning: pv not installed, progress bar unavailable" >> "$debug_file"
 fi
 use_progress=false
else
 use_progress=true
fi

# Search and process files
while IFS= read -r -d '' file; do
 # Get file size in bytes with improved compatibility
 if [[ "$OSTYPE" == "darwin"* ]]; then
  size_bytes=$(stat -f %z "$file" 2>/dev/null)
 else
  size_bytes=$(stat -c %s "$file" 2>/dev/null)
 fi
 
 # Validate size
 if ! [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not read size of '$file'" >> "$debug_file"
  has_errors=true
  continue
 fi
 
 # Compare sizes
 if [ "$size_bytes" -gt "$min_size_bytes" ]; then
  # Convert to MB
  size_mb=$(echo "scale=2; $size_bytes / 1048576" | bc)
  
  # Get file date
  file_date=$(date -r "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null)
  
  # Get extension and filename
  extension=$(get_extension "$file")
  filename=$(get_filename "$file")
  
  # Get relative and absolute paths
  rel_path="${file#${search_dir}/}"
  abs_path=$(realpath "$file" 2>/dev/null || echo "Error getting absolute path")
  
  # Store in array
  file_info[$count]="$file_date|$size_mb|$filename|$extension|$rel_path|$abs_path"
  sorted_files[$count]="$file_date|$size_mb|$filename|$extension|$rel_path|$abs_path"
  
  # Display in shell
  echo "File #$count:"
  echo "  Date: $file_date"
  echo "  Size: $size_mb MB"
  echo "  Extension: $extension"
  echo "  Relative Path: $rel_path"
  echo "  Absolute Path: $abs_path"
  echo "-------------------"
  
  ((count++))
 fi
done < <(if [ "$use_progress" = true ]; then
   find "$search_dir" -type f -print0 | pv -p -s "$total_files" -F "%p" >/dev/null 2>>"$debug_file" &
   find "$search_dir" -type f -print0
   else
   find "$search_dir" -type f -print0
   fi)

# Log completion to debug if verbose
if [ "$verbose" = true ]; then
 echo "Search completed at: $(date)" >> "$debug_file"
fi

# If no errors occurred and debug.log exists but is only verbose info, remove it
if [ "$has_errors" = false ] && [ -f "$debug_file" ]; then
 if ! grep -q "Error:" "$debug_file"; then
  rm "$debug_file"
 fi
fi

# Write sorted results to result file if verbose is enabled
if [ "$verbose" = true ] && [ $count -gt 0 ]; then
 echo "Starting search for files larger than ${min_size_mb}MB in ${search_dir}" > "$result_file"
 printf "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n" "Date" "Size" "Filename" "Extension" "Relative Path" "Absolute Path" >> "$result_file"
 printf "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n" "------------------------------" "----------" "----------------------------------------" "----------" "----------------------------------------" "----------------------------------------" >> "$result_file"
 
 # Sort based on sort_by and sort_order arguments
 case "$sort_by" in
  "date")
   sort_by_date | while IFS='|' read -r file_date size_mb filename extension rel_path abs_path; do
    printf "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n" "$file_date" "$size_mb MB" "$filename" "$extension" "$rel_path" "$abs_path" >> "$result_file"
   done
   ;;
  "filename")
   sort_by_filename | while IFS='|' read -r file_date size_mb filename extension rel_path abs_path; do
    printf "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n" "$file_date" "$size_mb MB" "$filename" "$extension" "$rel_path" "$abs_path" >> "$result_file"
   done
   ;;
  "size")
   sort_by_size | while IFS='|' read -r file_date size_mb filename extension rel_path abs_path; do
    printf "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n" "$file_date" "$size_mb MB" "$filename" "$extension" "$rel_path" "$abs_path" >> "$result_file"
   done
   ;;
 esac
 
 echo "Total files found: $count" >> "$result_file"
fi

# Final console output
echo "Found $count files larger than ${min_size_mb}MB in ${search_dir}"
if [ "$verbose" = true ] && [ $count -gt 0 ]; then
 echo "Results written to: $result_file"
fi
if [ -f "$debug_file" ]; then
 echo "Debug output written to: $debug_file"
fi
