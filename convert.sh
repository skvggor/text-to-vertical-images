#!/bin/bash
if ! command -v convert &>/dev/null; then
  echo "Error: ImageMagick (convert) is not installed."
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 file.txt"
  exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: file '$INPUT_FILE' not found."
  exit 1
fi

paragraphs=()
current=""

while IFS= read -r line || [ -n "$line" ]; do
  if [[ -z "$line" ]]; then
    # Blank line indicates the end of a paragraph (if there is accumulated content)
    if [ -n "$current" ]; then
      paragraphs+=("$current")
      current=""
    fi
  else
    # If there is already content, add a newline before concatenating
    if [ -n "$current" ]; then
      current+=$'\n'"$line"
    else
      current="$line"
    fi
  fi
done <"$INPUT_FILE"

# Add the last paragraph, if present
if [ -n "$current" ]; then
  paragraphs+=("$current")
fi

# Total number of paragraphs found
num_paragraphs=${#paragraphs[@]}

if [ "$num_paragraphs" -eq 0 ]; then
  echo "No paragraphs found in the file."
  exit 1
fi

# Define maximum characters per image (adjust as needed)
MAX_CHARS_PER_IMAGE=700

# Divide the text into groups based on size, without breaking in the middle of a paragraph
groups=()
group_text=""
group_count=0

for p in "${paragraphs[@]}"; do
  # If adding the current paragraph exceeds the limit and there is already accumulated content, finalize the group
  if [ $group_count -gt 0 ] && [ $((group_count + ${#p})) -gt $MAX_CHARS_PER_IMAGE ]; then
    groups+=("$group_text")
    group_text=""
    group_count=0
  fi
  # Append the paragraph to the group (with two newlines)
  group_text+="$p"$'\n\n'
  group_count=$((group_count + ${#p}))
done

# Add the last group, if any
if [ -n "$group_text" ]; then
  groups+=("$group_text")
fi

NUM_IMGS=${#groups[@]}

# Create the output directory with the current date (format dd-mm-yyyy)
current_date=$(date +"%d-%m-%Y")
output_dir="output/$current_date"
mkdir -p "$output_dir"

echo "Total paragraphs found: $num_paragraphs"
echo "Generating $NUM_IMGS images..."

for ((i = 0; i < NUM_IMGS; i++)); do
  # Define the output file name (e.g.: 01-output.png, 02-output.png, ...)
  output=$(printf "%02d-output.png" $((i + 1)))
  output_path="$output_dir/$output"

  # Create a temporary file to store the text
  tmpfile=$(mktemp)
  # Using -e ensures that \n is interpreted as a newline
  echo -e "${groups[i]}" >"$tmpfile"

  magick -size 1000x1270 \
    -background white \
    -fill black \
    -gravity NorthWest \
    -font ~/.local/share/fonts/NerdFonts/IosevkaNerdFont-Regular.ttf \
    -pointsize 40 \
    -interline-spacing 20 \
    caption:@"$tmpfile" \
    -gravity center \
    -background white \
    -extent 1080x1350 \
    -gravity southeast \
    -fill black \
    -font ~/.local/share/fonts/NerdFonts/IosevkaNerdFont-Regular.ttf \
    -pointsize 30 \
    -annotate +40+40 "$((${i} + 1))/$NUM_IMGS" \
    "$output_path"

  echo "Created image: $output_path"
  rm "$tmpfile"
done

echo "Process completed."
