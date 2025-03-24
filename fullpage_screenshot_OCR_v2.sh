#!/bin/bash
# By thibaut LOMBARD (LombardWeb)
# V2 including network features and chromium dom processing
# This script takes a full-page screenshot, performs OCR, and outputs results with strict single-mode selection

# Default values
URL=""
SCREENSHOT_TOOL="wkhtmltoimage"
SCREEN_WIDTH=1280
SCREEN_HEIGHT=1920
ENABLE_JS=false
DELAY=""
OCR_LANG="eng"
CSV_DELIMITER=";"
OUTPUT_FOLDER="generated"
OUTPUT_MODE="all"  # Default: Screenshot + TXT OCR + CSV OCR + DOM (Chromium only)
PROXY=""  # Empty by default, no proxy unless specified

# Usage message
usage() {
 echo "Usage: $0 -u <URL> [options]"
 echo "  -u <URL>   : Specify the URL to capture (required)"
 echo "  -r <tool>  : Screenshot tool: 'wkhtmltoimage' or 'chromium' (default: 'wkhtmltoimage')"
 echo "  -w <width> : Screen width in pixels (default: 1280)"
 echo "  -h <height>: Screen height in pixels (default: 1920)"
 echo "  -j         : Enable JavaScript execution (default: disabled)"
 echo "  -e <delay> : Delay in milliseconds for JS execution (optional, supports decimals)"
 echo "  -l <lang>  : OCR language (default: 'eng')"
 echo "  -d <delim> : CSV delimiter (default: ';')"
 echo "  -f <folder>: Output folder (default: 'generated')"
 echo "  -p <ip:port>: Enable SOCKS5 proxy for Chromium (e.g., '127.0.0.1:9050')"
 echo "Output modes (exactly one required, or none for default):"
 echo "  -s         : Screenshot only"
 echo "  -c         : Screenshot + CSV OCR"
 echo "  -t         : Screenshot + TXT OCR"
 echo "  -C         : CSV OCR only (delete screenshot after)"
 echo "  -T         : TXT OCR only (delete screenshot after)"
 echo "  -m         : DOM content only (Chromium only)"
 echo "  -a         : Screenshot + TXT OCR + CSV OCR"
 echo "Default (no mode specified): Screenshot + TXT OCR + CSV OCR + DOM (Chromium only)"
 exit 1
}

generate_filename() {
 local url="$1"
 local ext="$2"
 local domain=$(echo "$url" | sed -E 's|^https?://(www\.)?([^/]+).*|\2|')
 local datetime=$(date +"%d-%m-%Y_%H_%M_%S")
 echo "${domain}_${datetime}.${ext}"
}

cleanup() {
 rm -f "$PNG_FILE" "$TEMP_TXT" "$CSV_FILE" "$TXT_FILE" "$HTML_FILE"
 exit 1
}

trap cleanup INT TERM

# Parse options with while loop
OUTPUT_COUNT=0
while getopts "u:r:w:h:je:l:d:f:sctCTma:p:" opt; do
 case $opt in
  u) URL="$OPTARG" ;;
  r) SCREENSHOT_TOOL="$OPTARG" ;;
  w) SCREEN_WIDTH="$OPTARG" ;;
  h) SCREEN_HEIGHT="$OPTARG" ;;
  j) ENABLE_JS=true ;;
  e) DELAY="$OPTARG" ;;
  l) OCR_LANG="$OPTARG" ;;
  d) CSV_DELIMITER="$OPTARG" ;;
  f) OUTPUT_FOLDER="$OPTARG" ;;
  s) OUTPUT_MODE="screenshot_only"; ((OUTPUT_COUNT++)) ;;
  c) OUTPUT_MODE="screenshot_csv"; ((OUTPUT_COUNT++)) ;;
  t) OUTPUT_MODE="screenshot_txt"; ((OUTPUT_COUNT++)) ;;
  C) OUTPUT_MODE="csv_only"; ((OUTPUT_COUNT++)) ;;
  T) OUTPUT_MODE="txt_only"; ((OUTPUT_COUNT++)) ;;
  m) OUTPUT_MODE="dom_only"; ((OUTPUT_COUNT++)) ;;
  a) OUTPUT_MODE="screenshot_txt_csv"; ((OUTPUT_COUNT++)) ;;
  p) PROXY="$OPTARG" ;;
  ?) usage ;;
 esac
done

# Enforce exactly one output mode or default
if [ "$OUTPUT_COUNT" -gt 1 ]; then
 echo "Error: Only one output mode can be specified (-s, -c, -t, -C, -T, -m, -a)."
 usage
fi

# Validate inputs
case "$URL" in
 "") echo "Error: URL is required."; usage ;;
 https://*|http://*) ;;
 *) echo "Error: URL must start with http:// or https://"; usage ;;
esac

case "$SCREENSHOT_TOOL" in
 wkhtmltoimage|chromium) ;;
 *) echo "Error: Screenshot tool must be 'wkhtmltoimage' or 'chromium'"; usage ;;
esac

case "$DELAY" in
 ""|[0-9]*|[0-9]*.[0-9]*) ;;
 *) echo "Error: Delay (-e) must be a positive number (e.g., 2 or 2.5)"; usage ;;
esac

case "$PROXY" in
 ""|*:[0-9]*) ;;
 *) echo "Error: Proxy (-p) must be in format 'ip:port' (e.g., '127.0.0.1:9050')"; usage ;;
esac

case "$OUTPUT_MODE" in
 dom_only)
  if [ "$SCREENSHOT_TOOL" != "chromium" ]; then
   echo "Error: DOM dump (-m) is only available with Chromium"; usage
  fi
  ;;
esac

if [ -n "$PROXY" ] && [ "$SCREENSHOT_TOOL" != "chromium" ]; then
 echo "Error: Proxy (-p) is only supported with Chromium"; usage
fi

# Check dependencies
CHROMIUM_BIN=""
case "$SCREENSHOT_TOOL" in
 wkhtmltoimage)
  if ! command -v wkhtmltoimage &> /dev/null; then
   echo "wkhtmltoimage is not installed. Please install it first."
   exit 1
  fi
  ;;
 chromium)
  for bin in chromium google-chrome chromium-browser "/snap/bin/chromium"; do
   if [ -x "$(command -v "$bin" 2>/dev/null || echo "$bin")" ]; then
    CHROMIUM_BIN="$bin"
    break
   fi
  done
  if [ -z "$CHROMIUM_BIN" ]; then
   echo "Neither Chromium nor Google Chrome is installed (including Snap). Please install one first."
   exit 1
  fi
  ;;
esac

case "$OUTPUT_MODE" in
 all|screenshot_csv|screenshot_txt|csv_only|txt_only|screenshot_txt_csv)
  if ! command -v tesseract &> /dev/null; then
   echo "tesseract is not installed. Please install it first."
   exit 1
  fi
  ;;
esac

# Setup output folder and files
mkdir -p "$OUTPUT_FOLDER" || { echo "Error: Could not create output folder '$OUTPUT_FOLDER'"; exit 1; }
PNG_FILE="$OUTPUT_FOLDER/$(generate_filename "$URL" "png")"
TEMP_TXT="$OUTPUT_FOLDER/$(generate_filename "$URL" "txt")_temp.txt"
CSV_FILE="$OUTPUT_FOLDER/$(generate_filename "$URL" "csv")"
TXT_FILE="$OUTPUT_FOLDER/$(generate_filename "$URL" "txt")"
HTML_FILE="${PNG_FILE%.png}.html"

[ -z "$XDG_RUNTIME_DIR" ] && {
 export XDG_RUNTIME_DIR="/tmp/runtime-$USER"
 mkdir -p "$XDG_RUNTIME_DIR"
 chmod 700 "$XDG_RUNTIME_DIR"
}

# Capture screenshot or DOM
case "$SCREENSHOT_TOOL" in
 wkhtmltoimage)
  WKHTML_CMD="wkhtmltoimage --format png --width $SCREEN_WIDTH"
  case "$ENABLE_JS" in
   true)
    WKHTML_CMD="$WKHTML_CMD --enable-javascript"
    [ -n "$DELAY" ] && WKHTML_CMD="$WKHTML_CMD --javascript-delay $DELAY"
    echo "Capturing screenshot with wkhtmltoimage (JS enabled${DELAY:+, delay: ${DELAY}ms})..."
    ;;
   false)
    echo "Capturing screenshot with wkhtmltoimage (JS disabled)..."
    ;;
  esac
  WKHTML_CMD="$WKHTML_CMD \"$URL\" \"$PNG_FILE\""
  echo "Executing: $WKHTML_CMD"
  eval "$WKHTML_CMD" 2> "$OUTPUT_FOLDER/wkhtmltoimage_error.log"
  [ ! -f "$PNG_FILE" ] && {
   echo "wkhtmltoimage failed. Error log:"
   cat "$OUTPUT_FOLDER/wkhtmltoimage_error.log"
   rm -f "$OUTPUT_FOLDER/wkhtmltoimage_error.log"
   exit 1
  }
  rm -f "$OUTPUT_FOLDER/wkhtmltoimage_error.log"
  ;;
 chromium)
  CHROMIUM_CMD="$CHROMIUM_BIN --headless=new --disable-gpu --no-sandbox --hide-scrollbars"
  case "$ENABLE_JS" in
   true)
    [ -n "$DELAY" ] && CHROMIUM_CMD="$CHROMIUM_CMD --virtual-time-budget=$DELAY"
    echo "Capturing screenshot with Chromium (JS enabled${DELAY:+, delay: ${DELAY}ms}${PROXY:+, proxy: $PROXY})..."
    ;;
   false)
    CHROMIUM_CMD="$CHROMIUM_CMD --disable-javascript"
    echo "Capturing screenshot with Chromium (JS disabled${PROXY:+, proxy: $PROXY})..."
    ;;
  esac
  [ -n "$PROXY" ] && CHROMIUM_CMD="$CHROMIUM_CMD --proxy-server=\"socks5://$PROXY\""
  CHROMIUM_CMD_BASE="$CHROMIUM_CMD --window-size=${SCREEN_WIDTH},${SCREEN_HEIGHT}"
  case "$OUTPUT_MODE" in
   dom_only)
    echo "Executing: $CHROMIUM_CMD_BASE --dump-dom \"$URL\" > \"$HTML_FILE\""
    eval "$CHROMIUM_CMD_BASE --dump-dom \"$URL\" > \"$HTML_FILE\"" 2> "$OUTPUT_FOLDER/chromium_error.log"
    ;;
   *)
    echo "Executing: $CHROMIUM_CMD_BASE --screenshot=\"$PNG_FILE\" \"$URL\""
    eval "$CHROMIUM_CMD_BASE --screenshot=\"$PNG_FILE\" \"$URL\"" 2> "$OUTPUT_FOLDER/chromium_error.log"
    [ "$OUTPUT_MODE" = "all" ] && eval "$CHROMIUM_CMD_BASE --dump-dom \"$URL\" > \"$HTML_FILE\"" 2>> "$OUTPUT_FOLDER/chromium_error.log"
    ;;
  esac
  [ ! -f "$PNG_FILE" ] && [ "$OUTPUT_MODE" != "dom_only" ] && {
   echo "Chromium failed to generate screenshot. Error log:"
   cat "$OUTPUT_FOLDER/chromium_error.log"
   rm -f "$OUTPUT_FOLDER/chromium_error.log"
   exit 1
  }
  [ ! -f "$HTML_FILE" ] && [ "$OUTPUT_MODE" = "dom_only" -o "$OUTPUT_MODE" = "all" ] && {
   echo "Chromium failed to dump DOM. Error log:"
   cat "$OUTPUT_FOLDER/chromium_error.log"
   rm -f "$OUTPUT_FOLDER/chromium_error.log"
   exit 1
  }
  rm -f "$OUTPUT_FOLDER/chromium_error.log"
  ;;
esac

# Process output based on mode
case "$OUTPUT_MODE" in
 screenshot_only)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Screenshot saved as $PNG_FILE"
  ;;
 screenshot_csv)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  echo "Converting to CSV with delimiter '$CSV_DELIMITER'..."
  awk -v delim="$CSV_DELIMITER" '{if($0=="") {print ""; next} gsub(/[ \t]+/,delim); sub("^"delim"+",""); sub(delim"+$",""); print}' "$TEMP_TXT" > "$CSV_FILE"
  [ ! -f "$CSV_FILE" ] && { echo "Failed to create CSV."; rm -f "$PNG_FILE" "$TEMP_TXT"; exit 1; }
  echo "Screenshot saved as $PNG_FILE"
  echo "CSV saved as $CSV_FILE"
  rm -f "$TEMP_TXT" "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
 screenshot_txt)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  mv "$TEMP_TXT" "$TXT_FILE"
  [ ! -f "$TXT_FILE" ] && { echo "Failed to save TXT."; rm -f "$PNG_FILE"; exit 1; }
  echo "Screenshot saved as $PNG_FILE"
  echo "TXT saved as $TXT_FILE"
  rm -f "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
 csv_only)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  echo "Converting to CSV with delimiter '$CSV_DELIMITER'..."
  awk -v delim="$CSV_DELIMITER" '{if($0=="") {print ""; next} gsub(/[ \t]+/,delim); sub("^"delim"+",""); sub(delim"+$",""); print}' "$TEMP_TXT" > "$CSV_FILE"
  [ ! -f "$CSV_FILE" ] && { echo "Failed to create CSV."; rm -f "$PNG_FILE" "$TEMP_TXT"; exit 1; }
  echo "CSV saved as $CSV_FILE"
  rm -f "$PNG_FILE" "$TEMP_TXT" "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
 txt_only)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  mv "$TEMP_TXT" "$TXT_FILE"
  [ ! -f "$TXT_FILE" ] && { echo "Failed to save TXT."; rm -f "$PNG_FILE"; exit 1; }
  echo "TXT saved as $TXT_FILE"
  rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
 dom_only)
  [ ! -f "$HTML_FILE" ] && { echo "Failed to dump DOM."; exit 1; }
  echo "DOM content saved as $HTML_FILE"
  ;;
 screenshot_txt_csv)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  echo "Converting to CSV with delimiter '$CSV_DELIMITER'..."
  awk -v delim="$CSV_DELIMITER" '{if($0=="") {print ""; next} gsub(/[ \t]+/,delim); sub("^"delim"+",""); sub(delim"+$",""); print}' "$TEMP_TXT" > "$CSV_FILE"
  [ ! -f "$CSV_FILE" ] && { echo "Failed to create CSV."; rm -f "$PNG_FILE" "$TEMP_TXT"; exit 1; }
  mv "$Temp_TXT" "$TXT_FILE"
  [ ! -f "$TXT_FILE" ] && { echo "Failed to save TXT."; rm -f "$PNG_FILE" "$CSV_FILE"; exit 1; }
  echo "Screenshot saved as $PNG_FILE"
  echo "TXT saved as $TXT_FILE"
  echo "CSV saved as $CSV_FILE"
  rm -f "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
 all)
  [ ! -f "$PNG_FILE" ] && { echo "Failed to create screenshot."; exit 1; }
  echo "Performing OCR on $PNG_FILE..."
  tesseract "$PNG_FILE" "${TEMP_TXT%.txt}" -l "$OCR_LANG" 2> "$OUTPUT_FOLDER/tesseract_error.log"
  [ ! -f "$TEMP_TXT" ] && {
   echo "Tesseract OCR failed. Error log:"
   cat "$OUTPUT_FOLDER/tesseract_error.log"
   rm -f "$PNG_FILE" "$OUTPUT_FOLDER/tesseract_error.log"
   exit 1
  }
  echo "OCR completed"
  echo "Converting to CSV with delimiter '$CSV_DELIMITER'..."
  awk -v delim="$CSV_DELIMITER" '{if($0=="") {print ""; next} gsub(/[ \t]+/,delim); sub("^"delim"+",""); sub(delim"+$",""); print}' "$TEMP_TXT" > "$CSV_FILE"
  [ ! -f "$CSV_FILE" ] && { echo "Failed to create CSV."; rm -f "$PNG_FILE" "$TEMP_TXT"; exit 1; }
  mv "$TEMP_TXT" "$TXT_FILE"
  [ ! -f "$TXT_FILE" ] && { echo "Failed to save TXT."; rm -f "$PNG_FILE" "$CSV_FILE"; exit 1; }
  echo "Screenshot saved as $PNG_FILE"
  echo "TXT saved as $TXT_FILE"
  echo "CSV saved as $CSV_FILE"
  [ "$SCREENSHOT_TOOL" = "chromium" ] && [ -f "$HTML_FILE" ] && echo "DOM content saved as $HTML_FILE"
  rm -f "$OUTPUT_FOLDER/tesseract_error.log"
  ;;
esac

echo "Done! Files saved in $OUTPUT_FOLDER/"
