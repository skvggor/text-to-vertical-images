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

# Number of images to generate
NUM_IMGS=5

# Distribute the paragraphs evenly among the 5 images:
# For each image i (0 to NUM_IMGS-1):
#   start_index = floor(i * num_paragraphs / NUM_IMGS)
#   end_index   = floor((i+1) * num_paragraphs / NUM_IMGS) - 1

echo "Total paragraphs found: $num_paragraphs"
echo "Generating $NUM_IMGS images..."

for ((i = 0; i < NUM_IMGS; i++)); do
  # Calculate the start and end indices for the paragraphs in this group
  start_index=$((i * num_paragraphs / NUM_IMGS))
  end_index=$((((i + 1) * num_paragraphs) / NUM_IMGS - 1))

  group_text=""
  # Concatenate the paragraphs in this group, separating them with two newlines
  for ((j = start_index; j <= end_index; j++)); do
    # Ensure the index does not exceed the number of paragraphs
    if [ $j -ge "$num_paragraphs" ]; then
      break
    fi
    group_text+="${paragraphs[j]}"
    # If this is not the last paragraph in the group, add two newlines
    if [ $j -lt $end_index ]; then
      group_text+=$'\n\n'
    fi
  done

  # Define the output file name (e.g.: image_01.png, image_02.png, ...)
  output=$(printf "image_%02d.png" $((i + 1)))

  # Create a temporary file to store the text
  tmpfile=$(mktemp)
  # Using -e ensures that \n is interpreted as a newline
  echo -e "$group_text" >"$tmpfile"

  magick -size 1000x1270 \
    -background white \
    -fill black \
    -gravity NorthWest \
    -font /home/skvggor/.local/share/fonts/NerdFonts/IosevkaNerdFont-Regular.ttf \
    -pointsize 40 \
    -interline-spacing 20 \
    caption:@"$tmpfile" \
    -gravity center \
    -background white \
    -extent 1080x1350 \
    -gravity southeast \
    -fill black \
    -font /home/skvggor/.local/share/fonts/NerdFonts/IosevkaNerdFont-Regular.ttf \
    -pointsize 30 \
    -annotate +40+40 "$((${i} + 1))/$NUM_IMGS" \
    "$output"

  echo "Created image: $output"
  rm "$tmpfile"
done

echo "Process completed."
