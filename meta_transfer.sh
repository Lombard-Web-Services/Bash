# By thibaut LOMBARD (LombardWeb)
# This script permit to transfer metadata instantly from one place to another
# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
 echo "Error: exiftool is not installed. Please install it first."
 exit 1
fi

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
 echo "Usage: $0 <source_file_or_directory> <destination_file_or_directory>"
 exit 1
fi

source_path="$1"
dest_path="$2"

# Check if source exists
if [ ! -e "$source_path" ]; then
 echo "Error: Source '$source_path' does not exist"
 exit 1
fi

# Check if destination exists
if [ ! -e "$dest_path" ]; then
 echo "Error: Destination '$dest_path' does not exist"
 exit 1
fi

# List of metadata tags we want to copy with variations
tags=(
 "FileModifyDate"
 "FileAccessDate"
 "FileInodeChangeDate"
 "ShutterSpeed"
 "CreateDate"
 "DateTimeOriginal"
 "ModifyDate"
 "CircleOfConfusion"
 "FieldOfView"
 "FocalLength"
 "HyperfocalDistance"
 "LightValue"
 "ScaleFactorTo35mmEquivalent"
 "Aperture"
 "GPSCoordinates"
 "AndroidVersion"
 "AndroidManufacturer"
 "AndroidModel"
 "TrackCreateDate"
 "QuickTime:TrackCreateDate"
 "MP4:TrackCreateDate"
 "TrackModifyDate"
 "QuickTime:TrackModifyDate"
 "MP4:TrackModifyDate"
 "MediaCreateDate"
 "QuickTime:MediaCreateDate"
 "MP4:MediaCreateDate"
 "MediaModifyDate"
 "QuickTime:MediaModifyDate"
 "MP4:MediaModifyDate"
 "GPSLatitude"
 "GPSLongitude"
 "Rotation"
 "GPSPosition"
)

# List of date tags to compare and update
date_tags=(
 "MediaCreateDate"
 "MediaModifyDate"
 "CreateDate"
 "ModifyDate"
 "TrackCreateDate"
 "TrackModifyDate"
)

# File date tags to set from ModifyDate or TrackModifyDate
file_date_tags=(
 "FileModifyDate"
 "FileAccessDate"
 "FileInodeChangeDate"
)

process_file() {
 local source_file="$1"
 local dest_file="$2"
 
 if [ ! -f "$source_file" ] || [ ! -f "$dest_file" ]; then
  echo "Error: Source or destination is not a file"
  return 1
 fi

 echo "Debug: Date-related tags in $source_file:"
 exiftool -a -s "$source_file" | grep -i -E "Date|Time|Track|Media|File"
 
 # Get existing tags from source file as an array
 mapfile -t existing_tags < <(exiftool -j "$source_file" | grep -oE '"[^"]+":' | sed 's/":$//;s/"//g')
 
 # Build tag arguments only for existing tags
 tag_args=""
 index=0
 
 echo "Debug: Checking requested tags..."
 while [ $index -lt ${#tags[@]} ]; do
  current_tag="${tags[$index]}"
  tag_found=false
  
  for existing_tag in "${existing_tags[@]}"; do
   if [ "$current_tag" = "$existing_tag" ]; then
    tag_found=true
    echo "Debug: Found exact match for $current_tag"
    break
   fi
  done
  
  case "$tag_found" in
   true)
    tag_args="$tag_args -$current_tag"
    ;;
   false)
    echo "Debug: No match for $current_tag"
    ;;
  esac
  
  ((index++))
 done

 # Copy initial metadata
 if [ -n "$tag_args" ]; then
  echo "Debug: Executing initial exiftool copy with args: $tag_args"
  exiftool -v -overwrite_original -P $tag_args -srcfile "$source_file" "$dest_file"
 fi

 # Compare and update specific date tags
 echo "Debug: Comparing date tags between source and destination..."
 for date_tag in "${date_tags[@]}"; do
  original_date=""
  for variation in "$date_tag" "QuickTime:$date_tag" "MP4:$date_tag"; do
   original_date=$(exiftool -s -"$variation" "$source_file" | grep -o "[0-9]\{4\}:[0-9]\{2\}:[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
   [ -n "$original_date" ] && break
  done
  
  if [ -n "$original_date" ]; then
   dest_date=$(exiftool -s -"$date_tag" "$dest_file" | grep -o "[0-9]\{4\}:[0-9]\{2\}:[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
   
   if [ -n "$dest_date" ] && [ "$dest_date" != "$original_date" ]; then
    echo "Debug: $date_tag differs (source: $original_date, dest: $dest_date), updating..."
    exiftool -overwrite_original "-$date_tag=$original_date" "$dest_file"
    if [ $? -eq 0 ]; then
     echo "Updated $date_tag in $(basename "$dest_file") to match source"
    else
     echo "Failed to update $date_tag in $(basename "$dest_file")"
    fi
   elif [ -z "$dest_date" ]; then
    echo "Debug: $date_tag not present in destination, setting to $original_date"
    exiftool -overwrite_original "-$date_tag=$original_date" "$dest_file"
    if [ $? -eq 0 ]; then
     echo "Set $date_tag in $(basename "$dest_file") to match source"
    else
     echo "Failed to set $date_tag in $(basename "$dest_file")"
    fi
   else
    echo "Debug: $date_tag matches source ($original_date), no update needed"
   fi
  else
   echo "Debug: No valid date found for $date_tag in source"
  fi
 done

 # Set File* dates to match ModifyDate or TrackModifyDate
 echo "Debug: Setting File* dates..."
 modify_date=""
 for variation in "ModifyDate" "QuickTime:ModifyDate" "MP4:ModifyDate"; do
  modify_date=$(exiftool -s -"$variation" "$source_file" | grep -o "[0-9]\{4\}:[0-9]\{2\}:[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
  [ -n "$modify_date" ] && break
 done
 
 if [ -z "$modify_date" ]; then
  for variation in "TrackModifyDate" "QuickTime:TrackModifyDate" "MP4:TrackModifyDate"; do
   modify_date=$(exiftool -s -"$variation" "$source_file" | grep -o "[0-9]\{4\}:[0-9]\{2\}:[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
   [ -n "$modify_date" ] && break
  done
 fi

 if [ -n "$modify_date" ]; then
  for file_tag in "${file_date_tags[@]}"; do
   dest_file_date=$(exiftool -s -"$file_tag" "$dest_file" | grep -o "[0-9]\{4\}:[0-9]\{2\}:[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
   if [ -n "$dest_file_date" ] && [ "$dest_file_date" != "$modify_date" ]; then
    echo "Debug: Setting $file_tag to $modify_date (was $dest_file_date)"
    exiftool -overwrite_original "-$file_tag=$modify_date" "$dest_file"
    if [ $? -eq 0 ]; then
     echo "Updated $file_tag in $(basename "$dest_file") to $modify_date"
    else
     echo "Failed to update $file_tag in $(basename "$dest_file")"
    fi
   elif [ -z "$dest_file_date" ]; then
    echo "Debug: Setting $file_tag to $modify_date (was not present)"
    exiftool -overwrite_original "-$file_tag=$modify_date" "$dest_file"
    if [ $? -eq 0 ]; then
     echo "Set $file_tag in $(basename "$dest_file") to $modify_date"
    else
     echo "Failed to set $file_tag in $(basename "$dest_file")"
    fi
   else
    echo "Debug: $file_tag already matches $modify_date, no update needed"
   fi
  done
 else
  echo "Debug: No valid ModifyDate or TrackModifyDate found in source to set File* dates"
 fi

 # Final verification
 if [ -n "$tag_args" ] || [ -n "$original_date" ] || [ -n "$modify_date" ]; then
  if [ $? -eq 0 ]; then
   echo "Successfully processed metadata for: $(basename "$source_file")"
   echo "Debug: Final destination tags:"
   exiftool -a -s "$dest_file" | grep -i -E "Date|Time|Track|Media|File"
   return 0
  else
   echo "Failed to process metadata for: $(basename "$source_file")"
   return 1
  fi
 else
  echo "No matching metadata tags found in: $(basename "$source_file")"
  return 0
 fi
}

# Recursive function to process directories and subdirectories
process_directory() {
 local src_dir="$1"
 local dst_dir="$2"
 
 # Ensure destination directory exists
 if [ ! -d "$dst_dir" ]; then
  mkdir -p "$dst_dir" || {
   echo "Error: Could not create destination directory $dst_dir"
   return 1
  }
 fi

 # Use find to process all files recursively
 while IFS= read -r source_file; do
  if [ -f "$source_file" ]; then
   # Calculate relative path and corresponding destination file
   relative_path="${source_file#$src_dir/}"
   dest_file="$dst_dir/$relative_path"
   
   # Ensure destination subdirectory exists
   dest_subdir=$(dirname "$dest_file")
   if [ ! -d "$dest_subdir" ]; then
    mkdir -p "$dest_subdir" || {
     echo "Error: Could not create destination subdirectory $dest_subdir"
     continue
    }
   fi
   
   if [ -f "$dest_file" ]; then
    process_file "$source_file" "$dest_file" && ((count++))
   else
    echo "Warning: No matching destination file found for: $relative_path"
   fi
  fi
 done < <(find "$src_dir" -type f)
}

# Main processing logic
count=0
echo "Starting metadata copy process..."

if [ -f "$source_path" ]; then
 # Single file mode
 if [ -f "$dest_path" ]; then
  process_file "$source_path" "$dest_path" && ((count++))
 else
  echo "Error: Destination must be a file when source is a file"
  exit 1
 fi
elif [ -d "$source_path" ]; then
 # Directory mode with subdirectories
 if [ ! -d "$dest_path" ]; then
  echo "Error: Destination must be a directory when source is a directory"
  exit 1
 fi
 
 process_directory "$source_path" "$dest_path"
else
 echo "Error: Source must be a file or directory"
 exit 1
fi

echo "Process completed. Metadata copied for $count files."
