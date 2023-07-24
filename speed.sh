#!/bin/bash

#############################################################################
####################### START OF VARIABLES SECTION ##########################

current_time=$(date +%s)
timestamp=$(date +"%Y-%m-%d-%H-%M-%S")

# Initialize variables to store the total download and upload speeds
total_download=0
total_upload=0

#colours
RED="\033[31m"
GREEN="\033[32m"
CYAN="\033[36m"
COLOR_RESET="\033[0m"

no_number_input="${RED}Invalid input. Please enter a valid number.${COLOR_RESET}\n"
failed_cli_install="${RED}ERROR: Failed to install speedtest-cli. Please install it manually.${COLOR_RESET}\n"
invalid_sleep_time="${RED}Invalid input. Please enter a number between 15 and 120.${COLOR_RESET}\n"
empty_user_input="${RED}Input cannot be empty. Please enter a valid number.${COLOR_RESET}\n"
STRING_5="CONNECTED LINK SPEED: "

#############################################################################
########################## START OF FUNTION SECTION #########################

# Function to validate if input is a number
validate_number() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        printf "$no_number_input"
        return 1
    fi
    return 0
}

# Function to validate if sleep time is within range
validate_sleep_time() {
    if (( $1 < 15 || $1 > 120 )); then
        printf "$invalid_sleep_time"
        return 1
    fi
    return 0
}

# Function to validate if the directory exists and is writable
validate_directory() {
    if [[ ! -d "$1" ]]; then
        echo "Directory '$1' does not exist. Creating it..."
        mkdir -p "$1" || {
            printf "${RED}Failed to create the directory '$1'. Please provide a valid directory path.${COLOR_RESET}\n"
            return 1
        }
    fi

    if [[ ! -w "$1" ]]; then
        printf "${RED}Directory '$1' is not writable. Please provide a writable directory path.${COLOR_RESET}\n"
        return 1
    fi

    return 0
}

# Function to install Homebrew on macOS
install_homebrew() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# Function to print a message inside a box-like format
print_boxed_message() {
    local message="$1"
    local line="------------------------------------------------------------"
    echo "+$line+"
    echo "|${GREEN}${message}${COLOR_RESET}|"
    echo "+$line+"
}

#############################################################################
##################### SPEEDTEST-CLI CHECK SECTION ###########################


    # Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
        echo "speedtest-cli is not installed. Installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then  
        # Install speedtest-cli
        if command -v apt-get &> /dev/null; then
            if ! sudo apt-get install speedtest-cli; then
                printf "${failed_cli_install}"
                exit 1
            fi
        elif command -v dnf &> /dev/null; then
            if ! sudo dnf install speedtest-cli; then
                printf "${failed_cli_install}"
                exit 1
            fi
        elif command -v pacman &> /dev/null; then
            if ! sudo pacman -S speedtest-cli; then
                printf "${failed_cli_install}"
                exit 1
            fi    
        else
            printf "${failed_cli_install}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            if ! brew install speedtest-cli; then
                printf "${failed_cli_install}"
                exit 1
            fi
        else
            echo "Homebrew is required to install speedtest-cli on macOS."

            # Prompt the user if they want to install Homebrew
            read -p "Do you want to install Homebrew? [y/n]: " choice
            if [[ $choice =~ ^[Yy]$ ]]; then
                install_homebrew
                if ! command -v brew &> /dev/null; then
                    printf "${RED}ERROR: Failed to install Homebrew. Please install it manually.${COLOR_RESET}\n"
                    exit 1
                fi

                # Homebrew installed successfully, now install speedtest-cli
                if ! brew install speedtest-cli; then
                    printf "${failed_cli_install}\n"
                exit 1
                fi
            else
                printf "${RED}Aborted installation. Please install Homebrew and speedtest-cli manually.${COLOR_RESET}\n"
                exit 1
            fi
        fi
    else
       printf "${RED}ERROR: Unable to determine the operating system. Please install speedtest-cli manually.${COLOR_RESET}"
        exit 1
    fi   
    printf "${GREEN}speedtest-cli has been installed successfully.${COLOR_RESET}\n"

fi

#############################################################################
############################## TIME OF EXECUTION ############################

read -p "${CYAN}When do you want to execute the script? [Now/Delay/Specific]: ${COLOR_RESET}" execution_choice
execution_choice=$(echo "$execution_choice" | tr '[:upper:]' '[:lower:]')

if [[ $execution_choice == "now" ]]; then
    # Execute the script immediately
    printf "${GREEN}Executing the script now...${COLOR_RESET}\n"

elif [[ $execution_choice == "delay" ]]; then
    while true; do
        read -p "${CYAN}Enter the delay in seconds: ${COLOR_RESET}" delay
        if [[ -n "$delay" ]]; then
            if validate_number "$delay"; then
              break
            fi
        else
         printf "$empty_user_input"
        fi
    done
    execute_time=$((current_time + delay))
    printf "${GREEN}Executing the script after $delay seconds...${COLOR_RESET}\n"
    sleep $delay

elif [[ $execution_choice == "specific" ]]; then
    read -p "${CYAN}Enter the specific time in HH:MM format: ${COLOR_RESET}" specific_time
    specific_time_seconds=$(date -d "$specific_time" +%s)
    
    if [[ $specific_time_seconds -gt $current_time ]]; then
        sleep_duration=$((specific_time_seconds - current_time))
        printf "${GREEN}Executing the script at $specific_time...${COLOR_RESET}\n"
        sleep $sleep_duration
    else
        printf "${RED}Invalid time. Please provide a future time.${COLOR_RESET}\n"
        exit 1
    fi

else
    printf "${RED}Invalid choice. Exiting.${COLOR_RESET}\n"
    exit 1
fi

#############################################################################
########################## NUM OF TEST AND SLEEP ############################


# Prompt the user to input the number of tests
while true; do
    read -p "${CYAN}Enter the number of tests: ${COLOR_RESET}" num_tests
    if [[ -n "$num_tests" ]]; then
        if validate_number "$num_tests"; then
            break
        fi
    else
        printf "$empty_user_input"
    fi
done

# Prompt the user to input the sleep time between tests
while true; do
    read -p "${CYAN}Enter the sleep time between tests (in seconds): ${COLOR_RESET}\n" sleep_time
    valid_input=true

    if [[ -z "$sleep_time" ]]; then
        printf "$invalid_sleep_time"
        valid_input=false
    elif ! validate_number "$sleep_time" || ! validate_sleep_time "$sleep_time"; then
        valid_input=false
    fi

    if $valid_input; then
        break
    fi
done

# Calculate the total expected duration
total_duration=$((num_tests * sleep_time))

# Convert the total duration to minutes and seconds
minutes=$((total_duration / 60))
seconds=$((total_duration % 60))

# Print the total expected duration
printf "${GREEN}Total expected duration: $minutes minutes $seconds seconds ${COLOR_RESET}\n"

#############################################################################
############################## DIRECTORY INIT ###############################

# Initialize the output directory with a default value
default_output_directory="$(pwd)/results"
output_directory="$default_output_directory"

# Prompt the user to input the custom output directory
read -p "${CYAN}Enter the custom output directory path (default: new directory): ${COLOR_RESET}" user_input

# Check if the user gave custom directory
if [[ ! -z "$user_input" ]]; then
   # Use the custom output directory if provided
    output_directory="$user_input"
fi

# Validate the output directory
if ! validate_directory "$output_directory"; then
    # Fall back to the default output directory if validation fails
    output_directory="$default_output_directory"
    validate_directory "$output_directory" || {
        printf "${RED}Default output directory '$output_directory' is not writable. Exiting.${COLOR_RESET}\n"
        exit 1
    }
fi
echo "Using output directory: $output_directory"

#############################################################################
######################### CALCULATION OF RESULTS ############################

# Create a timestamp for the CSV filename
timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
results_filename="$output_directory/speedtest_results.csv"
errors_filename="$output_directory/speedtest_errors.csv"

# Check if the results CSV file exists
if [ ! -f "$results_filename" ]; then
    # Initialize the results CSV file with column headers
    echo "Average Download mb/s, Average Upload mb/s, Timestamp" > "$results_filename"
fi

# Check if the errors CSV file exists
if [ ! -f "$errors_filename" ]; then
    # Initialize the errors CSV file with column headers
    echo "Error, Timestamp, Note" > "$errors_filename"
fi

# Loop for the specified number of tests
for i in $(seq 1 $num_tests); do
    # Run the speed test and store the output in a variable
    output=$(speedtest-cli --bytes --secure 2>&1)

    # Check if speedtest-cli encountered an error
    if [ $? -ne 0 ]; then
        error_message="Speed test failed to complete"
        error_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        # Perform a 4-packet ping to Google nameservers
        ping_result=$(ping -c 4 8.8.8.8 2>&1)
        ping_status=$?
        
        # Check the ping status
        if [ $ping_status -eq 0 ]; then
            note="Ping to Google nameservers successful"
        else
            note="Ping to Google nameservers failed"
        fi
        
        echo "$error_message, $error_timestamp, $note" >> "$errors_filename"
        printf "${RED}Error: $error_message at $error_timestamp ($note)${COLOR_RESET}\n"
        
        continue
    fi

    # Extract the download and upload speeds from the output
    download=$(echo "$output" | awk '/Download:/ {print $2}' )
    upload=$(echo "$output" | awk '/Upload:/ {print $2}' )

    # Add the current download and upload speeds to the total
    total_download=$(echo "$total_download + $download" | bc -l)
    total_upload=$(echo "$total_upload + $upload" | bc -l)

    # Sleep for the specified time before running the next test
    sleep $sleep_time

    # Append the results to the results CSV file
    echo "$download, $upload, $(date +"%Y-%m-%d %H:%M:%S")" >> "$results_filename"
done

# Calculate the average download and upload speeds
average_download=$(echo "scale=2; $total_download / $num_tests" | bc) 
average_upload=$(echo "scale=2; $total_upload / $num_tests" | bc) 

#########################################################
#################### Print the results###################
# Print the final results inside a box
echo
print_boxed_message "Average download speed: ${CYAN}${average_download} mb/s${COLOR_RESET}"
print_boxed_message "Average upload speed: ${CYAN}${average_upload} mb/s${COLOR_RESET}"
print_boxed_message "Results appended to: ${CYAN}${results_filename}${COLOR_RESET}"
print_boxed_message "Error logs appended to: ${CYAN}${errors_filename}${COLOR_RESET}"