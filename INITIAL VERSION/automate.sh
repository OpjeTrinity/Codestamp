#!/bin/bash

# Function to identify the program language based on content
identify_language() {
  local file=$1

  # Read the first few lines to detect the language
  head -n 10 "$file" | grep -iqE 'class\s+[A-Za-z0-9_]+' && echo "java" && return
  head -n 10 "$file" | grep -iqE 'def\s+[A-Za-z0-9_]+' && echo "python" && return
  head -n 10 "$file" | grep -iqE 'public\s+class\s+[A-Za-z0-9_]+' && echo "java" && return
  head -n 10 "$file" | grep -iqE '#include\s+' && echo "cpp" && return
  head -n 10 "$file" | grep -iqE 'function\s+[A-Za-z0-9_]+' && echo "javascript" && return
  head -n 10 "$file" | grep -iqE '<\?php' && echo "php" && return

  # Default to unknown if no pattern matched
  echo "unknown"
}

# Function to add student information as a block comment
add_student_info() {
  local file=$1
  local name=$2
  local batch=$3
  local roll_no=$4
  local language=$5
  local program_title=$6

  # Set comment prefix and suffix based on detected language
  case $language in
    "cpp" | "c" | "h" | "java")
      comment_prefix="/*"
      comment_suffix="*/"
      ;;
    "python" | "rb" | "pl" | "php")
      comment_prefix="'''"
      comment_suffix="'''"
      ;;
    "javascript" | "html" | "css")
      comment_prefix="/*"
      comment_suffix="*/"
      ;;
    *)
      zenity --error --text="Unsupported language $language for $file. Cannot add student info."
      return
      ;;
  esac

  # Construct the multi-line comment text with program title
  comment="$comment_prefix\n"
  comment="$comment\nProgram Title: ${program_title:-"Untitled Program"}"
  comment="$comment\nStudent Name: $name"
  comment="$comment\nClass: $class"
  comment="$comment\nRoll No: $roll_no"
  comment="$comment\n$comment_suffix"

  # Insert the comment block at the top of the file
  temp_file=$(mktemp)
  echo -e "$comment" > $temp_file
  cat "$file" >> $temp_file
  mv $temp_file "$file"
}

# Function to convert programming language file to text file
convert_to_text() {
  local input_file=$1
  local output_file="${input_file%.*}.txt"

  # Just copy the content of the source file to a .txt file
  cp "$input_file" "$output_file"
}

# Get student details in separate dialogs
name=$(zenity --entry --title="Student Info" --text="Enter the student's name:" --width=300)
class=$(zenity --entry --title="Student Info" --text="Enter the class:" --width=300)
roll_no=$(zenity --entry --title="Student Info" --text="Enter the roll number:" --width=300)

# Exit if any of the fields are empty
if [ -z "$name" ] || [ -z "$class" ] || [ -z "$roll_no" ]; then
  zenity --error --text="All fields are required! Exiting."
  exit 1
fi

# Ask the user to select files
files=$(zenity --file-selection --title="Select the program files" --file-filter="*.*" --multiple --separator="|")
if [ -z "$files" ]; then
  # If no files selected, offer a "Select All Files" button
  directory=$(zenity --file-selection --directory --title="Select a directory with the files")
  if [ -z "$directory" ]; then
    zenity --error --text="No directory selected. Exiting."
    exit 1
  fi
  
  # Select all files in the directory
  files=$(find "$directory" -type f -name '*.*' | tr '\n' '|')
  if [ -z "$files" ]; then
    zenity --error --text="No files found in the selected directory. Exiting."
    exit 1
  fi
fi

# Show a warning dialog instructing the user to enter program titles in the correct order
zenity --info --title="Important Information" --text="Please make sure to enter the program titles in the **exact order** as the files you selected. Each program title corresponds to a file in the same order." --width=400

# Ask for multiple program titles (one per line), instructing the user to enter them in order
program_titles=$(zenity --text-info --title="Enter Program Titles" --width=400 --height=300 --editable \
--text="Please enter the program titles in the exact order for each of the files selected, one per line.\nPress OK when done:")

# Exit if no titles are entered
if [ -z "$program_titles" ]; then
  zenity --error --text="No program titles entered. Exiting."
  exit 1
fi

# Convert the input into an array of program titles (splitting by new lines)
IFS=$'\n' read -r -d '' -a program_titles_array <<< "$program_titles"

# Check if the number of program titles matches the number of files
num_files=$(echo "$files" | tr '|' '\n' | wc -l)
num_titles=${#program_titles_array[@]}

if [ "$num_files" -ne "$num_titles" ]; then
  zenity --error --text="The number of files does not match the number of titles entered. Exiting."
  exit 1
fi

# Ask if all files are the same type
same_type=$(zenity --question --text="Are all the selected files of the same program type?" --width=300 --ok-label="Yes" --cancel-label="No")
if [ $? -eq 0 ]; then
  # If all files are the same, select language once
  language=$(zenity --list --radiolist --title="Program Language" --text="Select the program language" --column="Select" --column="Language" \
    TRUE "java" FALSE "python" FALSE "cpp" FALSE "javascript" FALSE "php")
else
  # Otherwise, ask for the language of each file individually
  language=""
  IFS="|" # Set the separator to handle multiple files
  i=0
  for file in $files; do
    # Automatically identify language
    detected_language=$(identify_language "$file")
    
    # Ask user to specify language if detected is "unknown"
    if [ "$detected_language" = "unknown" ]; then
      detected_language=$(zenity --list --radiolist --title="Program Language" --text="Select the program language for $file" --column="Select" --column="Language" \
        TRUE "java" FALSE "python" FALSE "cpp" FALSE "javascript" FALSE "php")
    fi

    # Add the student info to the file with corresponding program title
    add_student_info "$file" "$name" "$class" "$roll_no" "$detected_language" "${program_titles_array[$i]}"
    i=$((i+1))
  done
  exit 0
fi

# Create a folder to store the converted text files
output_folder="Converted_Files"
mkdir -p "$output_folder"

# Process each selected file
IFS="|" # Set the separator to handle multiple files
i=0
for file in $files; do
  # Add student info to the file with corresponding program title
  add_student_info "$file" "$name" "$class" "$roll_no" "$language" "${program_titles_array[$i]}"
  
  # Convert the file to a .txt version
  convert_to_text "$file"

  # Move the .txt file to the output folder
  mv "${file%.*}.txt" "$output_folder/"
  
  i=$((i+1))  # Increment the index for the next file
done

# After processing all files, show a single success window
zenity --info --text="All files have been processed successfully!\nStudent information has been added, and converted to .txt.\nThe converted .txt files are located in the '$output_folder' folder."
