#!/bin/bash

# Function to validate if input is a number
validate_number() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "Invalid input. Please enter a valid number."
        return 1
    fi
    return 0
}

# Function to validate if sleep time is within range
validate_sleep_time() {
    if (( $1 < 15 || $1 > 120 )); then
        echo "Invalid input. Please enter a number between 15 and 120."
        return 1
    fi
    return 0
}

total_download=0
total_upload=0

# Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
    echo "speedtest-cli is not installed. Installing..."
    
    # Install speedtest-cli
    if command -v apt-get &> /dev/null; then
        if ! sudo apt-get install speedtest-cli; then
            echo "ERROR: Failed to install speedtest-cli. Please install it manually."
            exit 1
        fi
    elif command -v dnf &> /dev/null; then
        if ! sudo dnf install speedtest-cli; then
            echo "ERROR: Failed to install speedtest-cli. Please install it manually."
            exit 1
        fi
    else
        echo "ERROR: Unable to install speedtest-cli. Please install it manually."
        exit 1
    fi

    echo "speedtest-cli has been installed successfully."
fi

current_time=$(date +%s)

read -p "\033[37mWhen do you want to execute the script? [Now/Delay/Specific]: \033[0m" execution_choice
execution_choice=$(echo "$execution_choice" | tr '[:upper:]' '[:lower:]')

if [[ $execution_choice == "now" ]]; then
    # Execute the script immediately
    echo -e "\033[92mExecuting the script now...\033[0m"

elif [[ $execution_choice == "delay" ]]; then
    read -p "\033[37mEnter the delay in seconds: \033[0m" delay
    execute_time=$((current_time + delay))
    echo "\033[92mExecuting the script after $delay seconds...\033[0m"
    sleep $delay

elif [[ $execution_choice == "specific" ]]; then
    read -p "\033[37mEnter the specific time in HH:MM format: \033[0m" specific_time
    specific_time_seconds=$(date -d "$specific_time" +%s)
    
    if [[ $specific_time_seconds -gt $current_time ]]; then
        sleep_duration=$((specific_time_seconds - current_time))
        echo "\033[92mExecuting the script at $specific_time...\033[0m"
        sleep $sleep_duration
    else
        echo "\033[31mInvalid time. Please provide a future time.\033[0m"
        exit 1
    fi

else
    echo -e "\033[31mInvalid choice. Exiting.\033[0m"
    exit 1
fi


# Prompt the user to input the number of tests
while true; do
    read -p "\033[37mEnter the number of tests: \033[0m" num_tests
    if validate_number "$num_tests"; then
        break
    fi
done

# Prompt the user to input the sleep time between tests
while true; do
    read -p "\033[37mEnter the sleep time between tests (in seconds): \033[0m" sleep_time
    if validate_number "$sleep_time" && validate_sleep_time "$sleep_time"; then
        break
    fi
done

# Initialize the output directory with a dummy value
output_directory="dummy"

# Prompt the user to input the custom output directory
read -p "\033[37mEnter the custom output directory path (default: current directory): \033[0m" output_directory

# Check if the output directory is still the initial dummy value
if [[ "$output_directory" == "dummy" ]]; then
  # Set the output directory to the current directory
  output_directory="$(pwd)"
  echo "Using current directory: $output_directory"
fi

# Use the custom output directory if provided
output_directory="${output_directory:-.}"

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
    echo "Average Download, Average Upload, Timestamp" > "$results_filename"
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
    #echo "AAAAAAAAAAA $total_download, $total_upload, AAAAAAAAA"


    # Sleep for the specified time before running the next test
    sleep $sleep_time

    # Append the results to the results CSV file
    echo "$download, $upload, $(date +"%Y-%m-%d %H:%M:%S")" >> "$results_filename"
done

# Calculate the average download and upload speeds
average_download=$(echo "scale=2; $total_download / $num_tests" | bc) 
average_upload=$(echo "scale=2; $total_upload / $num_tests" | bc) 


# Print the results
echo ""
echo "Average download speed: $average_download mb/s"
echo "Average upload speed: $average_upload mb/s"
echo ""
echo "Results appended to $results_filename"
echo "Error logs appended to $errors_filename"