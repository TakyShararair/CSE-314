#!/usr/bin/bash


usage() {
  echo "Usage: $0 -i input.txt"
  exit 1
}

if [ "$1" != "-i" ] || [ -z "$2" ]; then
  usage
fi

input="$2"

if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  echo " Error : Input file does not exist or is not readable "
  exit 1
fi



mapfile -t lines < "$input"


convertLangToExtension() {
    declare -A langExten
    langExten["cpp"]="cpp"
    langExten["c"]="c"
    langExten["sh"]="sh"
    langExten["python"]="py"

    read -a convertLangToExtensionFileTypes <<< ${lines[2]}

    convertLangToExtensionResult=""
    for convertLangToExtensionFileType in "${convertLangToExtensionFileTypes[@]}"
    do
        convertLangToExtensionResult="$convertLangToExtensionResult "${langExten[$convertLangToExtensionFileType]}""
    done
    lines[2]=$convertLangToExtensionResult
}


if [ "${#lines[@]}" -ne 11 ]; then
  echo " Error : Input file is not exactly same format "
  exit 1
fi

c=$(echo "${lines[0]}" | tr -d '\r')

if [ "$c" == "true" ] || [ "$c" == "false" ]; then
    echo "Archive format is OK"
else
    echo "Error: Archive format is not OK"
    exit 1
fi

if [ "$c" == "true" ]; then

    if ! [[ "${lines[1]}" =~ ^(zip|rar|tar)(\ (zip|rar|tar))* ]]; then
        echo "Error: (Allowed Archived Formats) must contain 'zip', 'rar', or 'tar'."
        exit 1
    fi
fi

if ! [[ "${lines[2]}" =~ ^(c|cpp|python|sh)(\ (c|cpp|python|sh))* ]]; then
    echo "Error: (Allowed Programming Languages) must contain 'c', 'cpp', 'python', or 'sh'."
    exit 1
fi

if ! [[ "${lines[3]}" =~ ^[0-9]+ ]]; then
    echo "Error: This is  must be a number."
    exit 1
fi

m=$(echo "${lines[4]}" | tr -d '\r')

if ! [[ "${lines[4]}" =~ ^[0-9]+ ]]; then
    echo "Error: This is must be a number."
    exit 1
fi

d=$(echo "${lines[5]}" | tr -d '\r')


if [ ! -d "$d" ]; then
    echo "Error: This must be a valid directory."
    exit 1 
fi

if ! [[ "${lines[6]}" =~ ^[0-9]+\ [0-9]+ ]]; then
    echo "Error: Student ID Range must contain two numbers."
    exit 1
fi


e=$(echo "${lines[7]}" | tr -d '\r')

if [ ! -f "$e" ]; then
    echo "Error: This must be a valid file path."
    exit 1
fi

v=$(echo "${lines[8]}" | tr -d '\r')

if ! [[ "${lines[8]}" =~ ^[0-9]+ ]]; then
    echo "Error:Penalty for Submission Guidelines Violations must be a number."
    exit 1
fi


p=$(echo "${lines[9]}" | tr -d '\r')

if [ ! -f "$p" ]; then
    echo "Error: This must be a valid file path."
    exit 1
fi

v=$(echo "${lines[10]}" | tr -d '\r')

if ! [[ $v =~ ^[0-9]+$ ]] || [ $v -lt 0 ]; then
    echo "Error: Plagiarism Penalty must be grater than 0 %"
    exit 1
fi


convertLangToExtension

allowed_languages=("c" "cpp" "py" "sh")
allowed_formats=("zip" "rar" "tar")

working_directory="${lines[5]//[[:space:]]/}"


student_id_start="${lines[6]%% *}"  # Starting student ID
student_id_end="${lines[6]##* }" 
student_id_start=$(echo "$student_id_start" | xargs)
student_id_end=$(echo "$student_id_end" | xargs)

expected_output_file="${lines[7]}"

submitted=()


extract_archive() {
    local file="$1"
    local student_id="$2"
    local extension="$3"

    case "$extension" in
        zip)
           unzip -q "$file" -d "/mnt/e/submission/" >/dev/null 2>&1
           ;;
        rar)
           unrar x "$file" "/mnt/e/submission/" >/dev/null 2>&1
           ;;
        tar)
           tar -xf "$file" -C "/mnt/e/submission/" >/dev/null 2>&1
           ;;
        *)
          echo " Unsupported archive format: $extension"
          #echo "$student_id,0,0,0,issue case #2" >> "marks_file"
          return 1
          ;;
    esac
}

mkdir -p "/mnt/e/submission"
mkdir -p "/mnt/e/checked"
mkdir -p "/mnt/e/issued"

find "/mnt/e/submission" -mindepth 1 -delete
find "/mnt/e/checked" -mindepth 1 -delete
find "/mnt/e/issued" -mindepth 1 -delete

marks_file="marks.csv"
echo "id,marks,marks_deducted,total_marks,remarks" >> "$marks_file"

for submission in "$working_directory"/*; 
do
   filename=$(basename -- "$submission")
   student_id="${filename%%.*}"
   extension="${filename##*.}"
   student_id=$(echo "$student_id" | xargs)

   student_id=$(echo "$student_id" | tr -d -c '0-9')
   student_id_start=$(echo "$student_id_start" | tr -d -c '0-9')
   student_id_end=$(echo "$student_id_end" | tr -d -c '0-9')

     if [[ "$student_id" -ge "$student_id_start" ]] && [[ "$student_id" -le "$student_id_end" ]]; then
          
            # Create a directory for each student based on their ID
            c=$(echo "${lines[0]}" | tr -d '\r')
            is_folder=0

            if [ "$c" == "true" ];then
                student_dir="/mnt/e/submission/$student_id" 
        
               # Case 1: If the submission is a folder, check if the name is valid and skip unarchiving
               if [ -d "$submission" ]; then                
                  is_folder=1
                  cp -r "$submission" "$student_dir/"
               fi 
                 
           

                # Case 2: Check if the archive format is allowed
                 read -a allowed_input_formats <<< "${lines[1]}"
                 if [[ " ${allowed_input_formats[@]} " =~ " $extension " ]]; then
                      # Unarchive the file
                      if ! extract_archive "$submission" "$student_id" "$extension"; then
                      continue  # Skip this file if unsupported archive format (case 2)
                      fi
                 else
                     if [ "$is_folder" -eq 0 ]; then
                          submitted+=($student_id)
                          f_marks="${lines[8]}"
                          f_marks="-$f_marks"                 
                          f_marks=$(echo "$f_marks" | tr -d '\n' | tr -d '\r')
                          e_marks="${lines[8]}"                 
                          e_marks=$(echo "$e_marks" | tr -d '\n' | tr -d '\r')
                          mv "/mnt/e/submission/$student_id" "/mnt/e/issued/"
                          echo "$student_id,0,$e_marks,$f_marks,issue case #2" >> "$marks_file"
                          continue 
                     fi      
                  fi

                 extracted_folder_name=$(find "/mnt/e/submission/" -mindepth 1 -maxdepth 1 -type d -exec basename {} +)

                 if [[ $extracted_folder_name != $student_id ]]; then
                       submitted+=("$student_id")
                       fi_marks=${lines[8]}             
                       fi_marks=$(echo "$fi_marks" | tr -d '\n' | tr -d '\r')
                       fi1_marks=${lines[8]}               
                       fi1_marks=$(echo "$fi_marks" | tr -d '\n' | tr -d '\r')
                       fi_marks=$((total_marks+fi1_marks))                
                       echo "$student_id,$total_marks,$fi1_marks,$fi_marks,issue case #4" >> "$marks_file"
                       mv "/mnt/e/submission/$extracted_folder_name" "/mnt/e/submission/$student_id"
                 fi

                 file_path=$(find "/mnt/e/submission/$student_id/" -mindepth 1 -name "$student_id*")
                 file_extension="${file_path##*.}"
                 read -a allowed_lan <<< "${lines[2]}"

                 #case 3 
                 if [[ ! " ${allowed_lan[@]} " =~ " $file_extension " ]]; then
                 
                      submitted+=($student_id)
                      fin_marks="${lines[8]}"
                      fin_marks="-$fin_marks"                  
                      fin_marks=$(echo "$fin_marks" | tr -d '\n' | tr -d '\r')
                      d_marks="${lines[8]}"                    
                      d_marks=$(echo "$d_marks" | tr -d '\n' | tr -d '\r')
                      mv "/mnt/e/submission/$student_id" "/mnt/e/issued/"
                      echo "$student_id,0,$d_marks,$fin_marks,issue case #3" >> "$marks_file"
                      continue
                  fi

                 # Case 4: If the extracted folder name does not match the student ID, log the issue
                  extracted_folder=$(basename "$(dirname "$file_path")")
                  if [[ "$extracted_folder" != "$student_id" ]]; then
                   echo "Warning: Extracted folder name does not match student ID for $student_id"            
                  fi     

                   output_file="$student_dir/${student_id}_output.txt"
                    case "$file_extension" in
                    c|cpp)
                       g++ "$file_path" -o "$student_dir/$student_id.out" && "$student_dir/$student_id.out" > "$output_file"
                       ;;
                    py)
                       python3 "$file_path" > "$output_file"
                       ;;
                    sh)
                       bash "$file_path" > "$output_file"
                       ;;
                     *)
                       echo "Unsupported language: $file_extension"
                      ;;
                  esac
        

            else
                   student_dir="/mnt/e/submission/$student_id" 
                   mkdir -p $student_dir
                   cp -r "$submission" "$student_dir/"

                   file_path=$(find "/mnt/e/submission/$student_id/" -mindepth 1 -name "$student_id*")

                   file_extension="${file_path##*.}"
                    #case 3 
                    read -a allowed_input_languages <<< "${lines[2]}"
                    if ! [[ "${allowed_input_languages[@]}" =~ "$file_extension" ]]; then
                       echo "Error: Submission file $file for student $student_id is not in an allowed language."
                       submitted+=("$student_id")
                       fi_marks=${lines[8]}
                       fi_marks="-$fi_marks"
                       fi_marks=$(echo "$fi_marks" | tr -d '\n' | tr -d '\r')
                       de_marks=${lines[8]}
                       de_marks=$(echo "$de_marks" | tr -d '\n' | tr -d '\r')
                       mv "/mnt/e/submission/$student_id" "/mnt/e/issued/"
                       echo "$student_id,0,$de_marks,$fi_marks,issue case #3" >> "$marks_file"
                       continue
                    fi

                     output_file="$student_dir/${student_id}_output.txt"
                     case "$file_extension" in
                    c|cpp)
                        g++ "$file_path" -o "$student_dir/$student_id.out" && "$student_dir/$student_id.out" > "$output_file"
                        ;;
                    py)
                        python3 "$file_path" > "$output_file"
                        ;;
                     sh)
                        bash "$file_path" > "$output_file"
                        ;;
                     *)
                        echo "Unsupported language: $file_extension"
                       ;;
                     esac

               fi

                   expected_file="/mnt/e/2005098/expected_output.txt"
                    # Compare the generated output with the expected output file
                   mismatch_count=0
                   if [ -f "$expected_file" ] && [ -f "$output_file" ]; then
                       line_num=0   
                       # Read both files line by line and compare
                      while IFS= read -r expected_line || [ -n "$expected_line" ]; do
                          IFS= read -r output_line <&3 || [ -n "$output_line" ]       
                          # Increment the line number counter
                           line_num=$((line_num + 1))
                           expected_line=$(echo "$expected_line" | sed 's/[\r\n]*//g')
                           output_line=$(echo "$output_line" | sed 's/[\r\n]*//g') 
                            # Compare the lines, and if they don't match, increment the mismatch count
                           if [ "$expected_line" != "$output_line" ]; then                 
                               mismatch_count=$((mismatch_count + 1))
                           fi

                     done < "$expected_file" 3< "$output_file"
        
                       penalty_missing_output="${lines[4]}"
                       total_marks="${lines[3]}"
                       mismatch_count=${mismatch_count//[!0-9]/} # Remove non-numeric characters
                       penalty_missing_output=${penalty_missing_output//[!0-9]/} # Remove non-numeric characters
                       marks_deducted_for_line=$((mismatch_count*penalty_missing_output))              
                       total_marks=${total_marks//[!0-9]/}
                       marks_deducted_for_line=${marks_deducted_for_line//[!0-9]/}
                       marks_deducted=0
                       is_plagiarism=0
                       plagiarism_file="/mnt/e/2005098/plagiarism.txt"
                       mapfile -t plagiarism_ids < "$plagiarism_file"

                      for plagiarism_id in "${plagiarism_ids[@]}"
                        do  
                        # Strip whitespaces if necessary
                        plagiarism_id=$(echo "$plagiarism_id" | tr -d '[:space:]')
                        student_id=$(echo "$student_id" | tr -d '[:space:]')

                        if [ "$plagiarism_id" = "$student_id" ]; then                      
                                total_marks=$((total_marks-marks_deducted_for_line))                     
                                final_marks="${lines[3]}"
                                final_marks="-$final_marks"                    
                                final_marks=$(echo "$final_marks" | tr -d '\n' | tr -d '\r')
                                submitted+=("$student_id")
                                is_plagiarism=1
                                mv "/mnt/e/submission/$student_id" "/mnt/e/checked/"
                                echo "$student_id,$total_marks,$marks_deducted,$final_marks,Plagiarism detected" >> "$marks_file"
                                break
                      
                        fi
                      done

                         if [ "$is_plagiarism" -eq 0 ]; then
                             total_marks=$((total_marks-marks_deducted_for_line))
                             if [ "$is_folder" -eq 0 ];then
                                 final_marks=$((total_marks-marks_deducted))
                                 submitted+=("$student_id")
                                 mv "/mnt/e/submission/$student_id" "/mnt/e/checked/"
                                 echo "$student_id,$total_marks,$marks_deducted,$final_marks" >> "$marks_file"
                            else                     
                                final_marks=$((total_marks-marks_deducted))
                                cut_for_issue="${lines[8]}"                  
                                 cut_for_issue=$(echo "$cut_for_issue" | tr -d '\n' | tr -d '\r')
                                final_marks=$((final_marks-cut_for_issue))
                                submitted+=("$student_id")
                                 mv "/mnt/e/submission/$student_id" "/mnt/e/checked/"
                                 echo "$student_id,$total_marks,$cut_for_issue,$final_marks, issue case #1" >> "$marks_file"
                             fi
        
                           fi   
                       fi
           fi
done


  student_id_start=$(echo "$student_id_start" | tr -d '\r' | xargs)
  student_id_end=$(echo "$student_id_end" | tr -d '\r' | xargs)

   for(( i=$student_id_start; i<=$student_id_end; i++ ))
     do
     is_exist=0
     for id in "${submitted[@]}" 
        do
        x=$(echo "$id" | tr -d '\r' | xargs)
           if [[  "$x" =~ "$i" ]]; then
              is_exist=1
              break
           fi
     done
     if [ "$is_exist" -eq 0 ]; then
        echo "$i,0,0,0, Missing Submission" >> "$marks_file"
     fi
  done

# Define the file name
marks_file="marks.csv"
# Sort the file based on the first column (student_id), using ',' as the delimiter
# Skip the header by temporarily storing it, then concatenate it with the sorted data
header=$(head -n 1 "$marks_file")
tail -n +2 "$marks_file" | sort -t, -k1,1n > sorted_marks.csv

# Add the header back to the sorted data
echo "$header" > "$marks_file"
cat sorted_marks.csv >> "$marks_file"

# Remove the temporary sorted file
rm sorted_marks.csv


