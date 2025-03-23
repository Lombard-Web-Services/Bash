#!/bin/bash
# By thibaut LOMBARD (LombardWeb)
# This script permit to take a full page screenshot 
# perform Optical Character Recognition on the Image
# and output result in CSV or TXT

# Default values
URL=""
SAVE_CSV=false
SAVE_TXT=false
ENABLE_JS=false
CSV_DELIMITER=";"  # Default delimiter
PNG_FILE=""
CSV_FILE=""
TXT_FILE=""

# Usage message
usage() {
 echo "Usage: $0 -u <URL> [-c] [-t] [-j] [-d <delimiter>] [-p <png_file>] [-s <csv_file>] [-x <txt_file>]"
 echo "  -u <URL>   : Specify the URL to capture (required)"
 echo "  -c   : Save output as CSV with specified delimiter"
 echo "  -t   : Save output as raw TXT without post-processing"
 echo "  -j   : Enable JavaScript in wkhtmltoimage (default: disabled)"
 echo "  -d <delimiter>: Set CSV delimiter (default: ';')"
 echo "  -p <png_file> : Specify PNG screenshot filename (default: derived from URL)"
 echo "  -s <csv_file> : Specify CSV output filename (default: derived from URL)"
 echo "  -x <txt_file> : Specify TXT output filename (default: derived from URL)"
 echo "At least one of -c or -t must be specified."
 exit 1
}

# Function to generate default filename from URL and current date/time
generate_filename() {
 local url="$1"
 local ext="$2"
 # Extract domain from URL (e.g., example.com from https://www.example.com/path)
 local domain=$(echo "$url" | sed -E 's|^https?://(www\.)?([^/]+).*|\2|')
 # Get current date and time in format dd-mm-yyyy_hh_mm_ss
 local datetime=$(date +"%d-%m-%Y_%H_%M_%S")
 echo "${domain}_${datetime}.${ext}"
}

# Parse command-line options
while getopts "u:ctjd:p:s:x:" opt; do
 case $opt in
  u) URL="$OPTARG" ;;
  c) SAVE_CSV=true ;;
  t) SAVE_TXT=true ;;
  j) ENABLE_JS=true ;;
  d) CSV_DELIMITER="$OPTARG" ;;
  p) PNG_FILE="$OPTARG" ;;
  s) CSV_FILE="$OPTARG" ;;
  x) TXT_FILE="$OPTARG" ;;
  ?) usage ;;
 esac
done

# Check if URL is provided
if [ -z "$URL" ]; then
 echo "Error: URL is required."
 usage
fi

# Check if at least one output format is specified
if [ "$SAVE_CSV" = false ] && [ "$SAVE_TXT" = false ]; then
 echo "Error: At least one of -c or -t must be specified."
 usage
fi

# Check if wkhtmltoimage is installed
if ! command -v wkhtmltoimage &> /dev/null; then
 echo "wkhtmltoimage is not installed. Please install it first."
 exit 1
fi

# Check if tesseract is installed
if ! command -v tesseract &> /dev/null; then
 echo "tesseract is not installed. Please install it first."
 exit 1
fi

# Set default filenames if not provided
[ -z "$PNG_FILE" ] && PNG_FILE=$(generate_filename "$URL" "png")
[ -z "$CSV_FILE" ] && [ "$SAVE_CSV" = true ] && CSV_FILE=$(generate_filename "$URL" "csv")
[ -z "$TXT_FILE" ] && [ "$SAVE_TXT" = true ] && TXT_FILE=$(generate_filename "$URL" "txt")

# Temporary file for Tesseract output (will be renamed or processed)
TEMP_TXT="${TXT_FILE%.txt}_temp.txt"

# Set XDG_RUNTIME_DIR if not already set
if [ -z "$XDG_RUNTIME_DIR" ]; then
 export XDG_RUNTIME_DIR="/tmp/runtime-$USER"
 mkdir -p "$XDG_RUNTIME_DIR"
 chmod 700 "$XDG_RUNTIME_DIR"
fi

# Build wkhtmltoimage command based on JavaScript setting
WKHTML_CMD="wkhtmltoimage --format png --width 1280"
if [ "$ENABLE_JS" = true ]; then
 WKHTML_CMD="$WKHTML_CMD --enable-javascript"
 echo "Capturing screenshot of $URL with JavaScript enabled..."
else
 echo "Capturing screenshot of $URL with JavaScript disabled..."
fi
WKHTML_CMD="$WKHTML_CMD \"$URL\" \"$PNG_FILE\" 2>/dev/null"

# Capture full-page screenshot using wkhtmltoimage, suppressing warnings
eval "$WKHTML_CMD"

# Check if the screenshot was created successfully
if [ ! -f "$PNG_FILE" ]; then
 echo "Failed to create screenshot."
 exit 1
fi

echo "Screenshot saved as $PNG_FILE"

# Perform OCR using Tesseract and save raw text to a temporary file
echo "Performing OCR on $PNG_FILE..."
tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l eng

# Check if the OCR output file was created
if [ ! -f "$TEMP_TXT" ]; then
 echo "Failed to perform OCR."
 rm -f "$PNG_FILE"
 exit 1
fi

echo "OCR completed"

# Process output based on flags
if [ "$SAVE_CSV" = true ]; then
 echo "Converting to CSV with delimiter '$CSV_DELIMITER', preserving CR and LF..."
 awk -v delim="$CSV_DELIMITER" '
 {
  # Skip empty lines but preserve them in output
  if ($0 == "") {
   print "";
   next;
  }
  # Split on spaces/tabs, join with delimiter, preserve line endings
  gsub(/[ \t]+/, delim);
  # Remove leading/trailing delimiters
  sub("^" delim "+", "");
  sub(delim "+$", "");
  print $0;
 }' "$TEMP_TXT" > "$CSV_FILE"

 if [ ! -f "$CSV_FILE" ]; then
  echo "Failed to create CSV file."
  rm -f "$PNG_FILE" "$TEMP_TXT"
  exit 1
 fi
 echo "CSV file saved as $CSV_FILE"
fi

if [ "$SAVE_TXT" = true ]; then
 mv "$TEMP_TXT" "$TXT_FILE"
 if [ ! -f "$TXT_FILE" ]; then
  echo "Failed to save TXT file."
  rm -f "$PNG_FILE"
  exit 1
 fi
 echo "Raw TXT file saved as $TXT_FILE"
else
 rm -f "$TEMP_TXT"  # Clean up if TXT not requested
fi

echo "Done! Screenshot remains in working directory as $PNG_FILE"
