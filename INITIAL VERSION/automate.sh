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
  local class=$3
  local roll_no=$4
  local language=$5

  # Extract the filename (without the path) to use as the program title
  program_title=$(basename "$file")

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
  comment="$comment\nProgram Title: $program_title"
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

# GUI to get the student's details
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

name=$(zenity --entry --title="Student Info" --text="Enter the student's name:" --width=300)
class=$(zenity --entry --title="Student Info" --text="Enter the class:" --width=300)
roll_no=$(zenity --entry --title="Student Info" --text="Enter the roll number:" --width=300)

# Check if any input is empty
if [ -z "$name" ] || [ -z "$class" ] || [ -z "$roll_no" ]; then
  zenity --error --text="All fields are required! Exiting."
  exit 1
fi

# Ask if the user wants to rename files
rename_files=$(zenity --question --text="Do you want to rename the files?" --width=300 --ok-label="Yes" --cancel-label="No")

# Ask the user to paste the list of new file names if renaming is selected
if [ $? -eq 0 ]; then
  new_names=$(zenity --entry --title="Rename Files" --text="Enter the list of new names (comma separated, e.g., apple,microsoft,google,teemu):" --width=400)

  # Check if the new names list is provided
  if [ -z "$new_names" ]; then
    zenity --error --text="No list of names provided! Exiting."
    exit 1
  fi

  # Split the comma-separated list into an array
  IFS=',' read -r -a names_array <<< "$new_names"

  # Check if the number of names matches the number of files
  num_files=$(echo "$files" | tr '|' '\n' | wc -l)
  num_names=${#names_array[@]}

  if [ "$num_files" -ne "$num_names" ]; then
    zenity --error --text="The number of files does not match the number of names in the list. Exiting."
    exit 1
  fi

  # Confirm the renaming with a warning
  zenity --warning --text="In order to correctly rename the files, both the list and the files should be in order. Proceeding will rename the files in the provided order."
else
  rename_files="no"
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
  for file in $files; do
    # Automatically identify language
    detected_language=$(identify_language "$file")
    
    # Ask user to specify language if detected is "unknown"
    if [ "$detected_language" = "unknown" ]; then
      detected_language=$(zenity --list --radiolist --title="Program Language" --text="Select the program language for $file" --column="Select" --column="Language" \
        TRUE "java" FALSE "python" FALSE "cpp" FALSE "javascript" FALSE "php")
    fi

    # Process the file based on user input
    add_student_info "$file" "$name" "$class" "$roll_no" "$detected_language"
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
  # Add student info to the file
  add_student_info "$file" "$name" "$class" "$roll_no" "$language"
  
  if [ "$rename_files" = "yes" ]; then
    # Rename the file according to the corresponding name in the list
    new_name="${names_array[$i]}"
    
    # Check if the new name is provided and rename the file
    mv "$file" "$new_name"
    file="$new_name"  # Update the filename variable to the new name
  fi
  
  # Convert the file to a .txt version
  convert_to_text "$file"

  # Move the .txt file to the output folder
  mv "${file%.*}.txt" "$output_folder/"
  
  i=$((i+1))  # Increment the index for the next file
done

# After processing all files, show a single success window
zenity --info --text="All files have been processed successfully!\nStudent information has been added, files have been renamed (if selected), and converted to .txt.\nThe converted .txt files are located in the '$output_folder' folder."

