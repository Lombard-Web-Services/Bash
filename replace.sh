# By Thibaut LOMBARD (LombardWeb)
# Replace a string by another recursively
# With rename, find, sed, grep
# Execute : chmod +x replace.sh 

#!/bin/bash
# Function to install dependencies
install_dependencies() {
 case "$(uname -s)" in
  Linux*)
   if command -v apt-get >/dev/null 2>&1; then
    echo "Installing rename dependency for Debian/Ubuntu..."
    sudo apt-get update && sudo apt-get install -y rename
   elif command -v yum >/dev/null 2>&1; then
    echo "Installing rename dependency for RHEL/CentOS..."
    sudo yum install -y rename
   else
    echo "Warning: Could not determine package manager. Please install 'rename' manually."
   fi
   ;;
  *)
   echo "Warning: Unsupported OS for automatic dependency installation. Please install 'rename' manually."
   ;;
 esac
}

# Function to display usage
usage() {
 echo "Usage: $0 \"search_string\" \"replace_string\" [-i directory] [-v] [--opt {str_replace|fld_replace|comb_replace}]"
 echo "Examples:"
 echo "  $0 \"old\" \"new\"     # Default: comb_replace in current directory"
 echo "  $0 \"old\" \"new\" -i /path -v    # comb_replace in specified directory with verbose output"
 echo "  $0 \"old\" \"new\" -i /path --opt str_replace"
 exit 1
}

# Check minimum arguments
[ $# -lt 2 ] && usage

# Default values
SEARCH_STRING="$1"
REPLACE_STRING="$2"
DIRECTORY="$(pwd)"
OPERATION="comb_replace"
VERBOSE=false

# Parse arguments
shift 2
while [ $# -gt 0 ]; do
 case "$1" in
  -i)
   shift
   if [ -n "$1" ]; then
    if [ -d "$1" ]; then
     case "$1" in
      /*) DIRECTORY="$1" ;;
      *)  DIRECTORY="$(pwd)/$1" ;;
     esac
    else
     echo "Error: Directory '$1' does not exist"
     exit 1
    fi
   else
    echo "Error: No directory specified after -i"
    exit 1
   fi
   shift
   ;;
  -v)
   VERBOSE=true
   shift
   ;;
  --opt)
   shift
   case "$1" in
    str_replace|fld_replace|comb_replace)
     OPERATION="$1"
     ;;
    *)
     echo "Error: Invalid operation. Use str_replace, fld_replace, or comb_replace"
     exit 1
     ;;
   esac
   shift
   ;;
  *)
   echo "Unknown option: $1"
   usage
   ;;
 esac
done

DIRECTORY="${DIRECTORY%/}"

# Check and install dependencies
command -v rename >/dev/null 2>&1 || install_dependencies

# Function to escape strings for sed
escape_for_sed() {
 printf '%s' "$1" | sed 's/[\/&|]/\\&/g'
}

# Function to replace string in files
replace_in_files() {
 if [ "$VERBOSE" = true ]; then
  echo "Replacing '$SEARCH_STRING' with '$REPLACE_STRING' in file contents..."
 fi
 local changes_made=0
 local temp_file=$(mktemp)
 local escaped_search=$(escape_for_sed "$SEARCH_STRING")
 local escaped_replace=$(escape_for_sed "$REPLACE_STRING")
 
 find "$DIRECTORY" -type f -exec sh -c '
  for file; do
   if grep -q -F "$0" "$file" 2>/dev/null; then
    grep -n -F "$0" "$file" | while IFS=: read -r line_num content; do
     echo "Replacing '\''$0'\'' with '\''$1'\'' in file $file line $line_num" >> "$2"
    done
    sed -i "s|$3|$4|g" "$file" 2>/dev/null
   fi
  done
 ' "$SEARCH_STRING" "$REPLACE_STRING" "$temp_file" "$escaped_search" "$escaped_replace" {} +
 
 if [ "$VERBOSE" = true ]; then
  if [ -s "$temp_file" ]; then
   changes_made=$(wc -l < "$temp_file")
   echo "String replacement summary in $DIRECTORY:"
   cat "$temp_file"
   echo "Total replacements made: $changes_made"
  else
   echo "No string replacements were made in file contents"
  fi
 fi
 rm -f "$temp_file"
}

# Function to replace in directory/file names
replace_in_names() {
 if [ "$VERBOSE" = true ]; then
  echo "Replacing '$SEARCH_STRING' with '$REPLACE_STRING' in directory/file names..."
 fi
 local changes_made=0
 local temp_file=$(mktemp)
 local escaped_search=$(escape_for_sed "$SEARCH_STRING")
 local escaped_replace=$(escape_for_sed "$REPLACE_STRING")
 
 find "$DIRECTORY" -depth -name "*$SEARCH_STRING*" -execdir sh -c '
  for file; do
   new_name=$(echo "$file" | sed "s|$0|$1|g")
   if [ "$file" != "$new_name" ]; then
    rename "s|$0|$1|g" "$file" 2>/dev/null
    echo "Renamed: $file -> $new_name" >> "$2"
   fi
  done
 ' "$escaped_search" "$escaped_replace" "$temp_file" {} +
 
 if [ "$VERBOSE" = true ]; then
  if [ -s "$temp_file" ]; then
   changes_made=$(wc -l < "$temp_file")
   echo "Name replacement summary in $DIRECTORY:"
   cat "$temp_file"
   echo "Total names modified: $changes_made"
  else
   echo "No name replacements were made"
  fi
 fi
 rm -f "$temp_file"
}

# Execute operation
case "$OPERATION" in
 str_replace)
  replace_in_files
  ;;
 fld_replace)
  replace_in_names
  ;;
 comb_replace)
  replace_in_files
  echo ""  # Add a blank line between operations for clarity if verbose
  replace_in_names
  ;;
esac
