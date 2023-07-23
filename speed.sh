#!/bin/bash

# Function to validate if input is a number
validate_number() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        printf "\e[91mInvalid input. Please enter a valid number.\e[0m\n"
        return 1
    fi
    return 0
}

# Function to validate if sleep time is within range
validate_sleep_time() {
    if (( $1 < 15 || $1 > 120 )); then
        printf "\e[91mInvalid input. Please enter a number between 15 and 120.\e[0m\n"
        return 1
    fi
    return 0
}

# Function to validate if the directory exists and is writable
validate_directory() {
    if [[ ! -d "$1" ]]; then
        echo "Directory '$1' does not exist. Creating it..."
        mkdir -p "$1" || {
            echo "Failed to create the directory '$1'. Please provide a valid directory path."
            return 1
        }
    fi

    if [[ ! -w "$1" ]]; then
        echo "Directory '$1' is not writable. Please provide a writable directory path."
        return 1
    fi

    return 0
}

total_download=0
total_upload=0

# Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
    echo "speedtest-cli is not installed. Installing..."
    
#    # Use sudo once to acquire necessary privileges for package manager commands
#    if ! sudo true; then
#        echo "ERROR: Unable to get superuser privileges. Please install speedtest-cli manually with appropriate permissions."
#        exit 1
#    fi
    # Install speedtest-cli
    if command -v apt-get &> /dev/null; then
        if ! sudo apt-get install speedtest-cli; then
            printf "\e[91ERROR: Failed to install speedtest-cli. Please install it manually.\e[0m"
            exit 1
        fi
    elif command -v dnf &> /dev/null; then
        if ! sudo dnf install speedtest-cli; then
            printf "\e[91ERROR: Failed to install speedtest-cli. Please install it manually.\e[0m"
            exit 1
        fi
    elif command -v pacman &> /dev/null; then
        if ! sudo pacman -S speedtest-cli; then
            printf "\e[91ERROR: Failed to install speedtest-cli. Please install it manually.\e[0m"
            exit 1
        fi    
    else
        printf "\e[91ERROR: Unable to install speedtest-cli. Please install it manually.\e[0m"
        exit 1
    fi

    printf "\e[92mspeedtest-cli has been installed successfully.\e[0m\n"
fi

current_time=$(date +%s)

read -p $'\033[37mWhen do you want to execute the script? [Now/Delay/Specific]: \033[0m' execution_choice
execution_choice=$(echo "$execution_choice" | tr '[:upper:]' '[:lower:]')

if [[ $execution_choice == "now" ]]; then
    # Execute the script immediately
    printf "\e[92mExecuting the script now...\e[0m\n"

elif [[ $execution_choice == "delay" ]]; then
    while true; do
        read -p $'\033[37mEnter the delay in seconds: \033[0m' delay
        if [[ -n "$delay" ]]; then
            if validate_number "$delay"; then
              break
            fi
        else
         printf "\e[91mInput cannot be empty. Please enter a valid number.\e[0m\n"
        fi
    done
    execute_time=$((current_time + delay))
    printf "\033[92mExecuting the script after $delay seconds...\e[0m\n"
    sleep $delay

elif [[ $execution_choice == "specific" ]]; then
    read -p $'\033[37mEnter the specific time in HH:MM format: \033[0m\n' specific_time
    specific_time_seconds=$(date -d "$specific_time" +%s)
    
    if [[ $specific_time_seconds -gt $current_time ]]; then
        sleep_duration=$((specific_time_seconds - current_time))
        printf "\033[92mExecuting the script at $specific_time...\e[0m\n"
        sleep $sleep_duration
    else
        printf "\033[31mInvalid time. Please provide a future time.\e[0m\n"
        exit 1
    fi

else
    printf "\033[31mInvalid choice. Exiting.\e[0m\n"
    exit 1
fi


# Prompt the user to input the number of tests
while true; do
    read -p $'\033[37mEnter the number of tests: \033[0m' num_tests
    if [[ -n "$num_tests" ]]; then
        if validate_number "$num_tests"; then
            break
        fi
    else
        printf "\e[91mInput cannot be empty. Please enter a valid number.\e[0m\n"
    fi
done

# Prompt the user to input the sleep time between tests
while true; do
    read -t 10 -p $'\e[37mEnter the sleep time between tests (in seconds): \e[0m' sleep_time
    valid_input=true

    if [[ -z "$sleep_time" ]]; then
        printf "\e[91mInput cannot be empty. Please enter a valid number between 15 and 120.\e[0m\n"
        valid_input=false
    elif ! validate_number "$sleep_time" || ! validate_sleep_time "$sleep_time"; then
#        printf "\e[91mInvalid input. Please enter a valid number between 15 and 120.\e[0m\n"
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
printf "\033[92mTotal expected duration: $minutes minutes $seconds seconds \e[0m\n"

# Initialize the output directory with a default value
default_output_directory="$(pwd)/results"
output_directory="$default_output_directory"

# Prompt the user to input the custom output directory
read -p $'\033[37mEnter the custom output directory path (default: new directory): \033[0m' user_input

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
        echo "Default output directory '$output_directory' is not writable. Exiting."
        exit 1
    }
fi
echo "Using output directory: $output_directory"

# Initialize variables to store the total download and upload speeds
total_download=0
total_upload=0

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
        echo "Error: $error_message at $error_timestamp ($note)"
        
        continue
    fi

    # Extract the download and upload speeds from the output
    #download=$(echo $output | grep Download | awk '{print $2}')
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


# Print the results
echo
printf "\e[1mAverage download speed:\e[0m \e[32m$average_download mb/s\e[0m\n"
printf "\e[1mAverage upload speed:\e[0m \e[32m$average_upload mb/s\e[0m\n"
printf "\e[1mResults appended to:\e[0m \e[36m$results_filename\e[0m\n"
printf "\e[1mError logs appended to:\e[0m \e[36m$errors_filename\e[0m\n"