#!/bin/bash
# By Thibaut LOMBARD (LombardWeb)
# This script permit to refresh the date of creation and modification date to the actual date

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
 echo "Error: exiftool is not installed. Please install it first."
 echo "On Debian/Ubuntu: sudo apt-get install libimage-exiftool-perl"
 echo "On Red Hat/Fedora: sudo dnf install perl-Image-ExifTool"
 exit 1
fi

# Default settings
VERBOSE=0
HEURISTIC=0
TARGET=""

# Parse command line options
while [ $# -gt 0 ]; do
 case "$1" in
  -v|--verbose)
   VERBOSE=1
   shift
   ;;
  --heuristic)
   HEURISTIC=1
   shift
   ;;
  *)
   if [ -z "$TARGET" ]; then
    TARGET="$1"
   else
    echo "Error: Too many arguments"
    echo "Usage: $0 [-v|--verbose] [--heuristic] <file/directory>"
    exit 1
   fi
   shift
   ;;
 esac
done

if [ -z "$TARGET" ]; then
 echo "Usage: $0 [-v|--verbose] [--heuristic] <file/directory>"
 echo "Will use current date: $(date '+%Y:%m:%d %H:%M:%S')"
 exit 1
fi

# Get current date in exiftool format
NEW_DATE=$(date '+%Y:%m:%d %H:%M:%S')

# Array of specific metadata tags to modify (when not using heuristic)
declare -a METADATA_TAGS=(
 "MediaCreateDate"
 "MediaModifyDate"
 "CreateDate"
 "ModifyDate"
 "TrackCreateDate"
 "TrackModifyDate"
)

# Array of filesystem tags to modify
declare -a FILESYSTEM_TAGS=(
 "FileModifyDate"
 "FileAccessDate"
 "FileInodeChangeDate"
)

# Function to handle verbose output
verbose() {
 if [ $VERBOSE -eq 1 ]; then
  echo "$@"
 fi
}

# Function to process a single file
process_file() {
 local file="$1"
 
 # Skip if not a regular file
 [ -f "$file" ] || return
 
 verbose "Processing: $file"
 verbose "Using date: $NEW_DATE"
 
 if [ $HEURISTIC -eq 1 ]; then
  # Heuristic mode: find all tags containing "date" or "Date" with date-like values
  exiftool -a -G1 "$file" | grep -i "date" | while IFS=: read -r tag value; do
   # Clean up tag name
   tag=$(echo "$tag" | sed 's/^\[.*\] *//;s/ *$//')
   value=$(echo "$value" | sed 's/^ *//')
   
   # Check if value matches common date patterns
   if echo "$value" | grep -qE "[0-9]{4}[:/-][0-9]{2}[:/-][0-9]{2}|[0-9]{2}[:/-][0-9]{2}[:/-][0-9]{4}"; then
    verbose "Updating heuristic tag $tag for $file"
    exiftool -overwrite_original -"$tag=$NEW_DATE" "$file" 2>/dev/null
    if [ $? -eq 0 ]; then
     verbose "Successfully updated $tag"
    else
     verbose "Failed to update $tag"
    fi
   fi
  done
 else
  # Normal mode: process specific embedded metadata tags
  i=0
  while [ $i -lt ${#METADATA_TAGS[@]} ]; do
   tag="${METADATA_TAGS[$i]}"
   if exiftool -"$tag" "$file" | grep -q "$tag"; then
    verbose "Updating $tag for $file"
    exiftool -overwrite_original -"$tag=$NEW_DATE" "$file" 2>/dev/null
    if [ $? -eq 0 ]; then
     verbose "Successfully updated $tag"
    else
     verbose "Failed to update $tag"
    fi
   else
    verbose "Skipping $tag - not present in file"
   fi
   ((i++))
  done
 fi
 
 # Always process filesystem tags
 i=0
 while [ $i -lt ${#FILESYSTEM_TAGS[@]} ]; do
  tag="${FILESYSTEM_TAGS[$i]}"
  verbose "Updating $tag for $file"
  exiftool -P -"$tag=$NEW_DATE" "$file" 2>/dev/null
  if [ $? -eq 0 ]; then
   verbose "Successfully updated $tag"
  else
   verbose "Failed to update $tag"
  fi
  ((i++))
 done
 verbose "------------------------"
}

# Main processing logic using case statement
case "$TARGET" in
 *)
  if [ -d "$TARGET" ]; then
   verbose "Processing directory recursively: $TARGET"
   find "$TARGET" -type f | while read -r file; do
    process_file "$file"
   done
  elif [ -f "$TARGET" ]; then
   process_file "$TARGET"
  else
   echo "Error: $TARGET is not a valid file or directory"
   exit 1
  fi
  ;;
esac

verbose "Processing complete!"
