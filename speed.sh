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

read -p "When do you want to execute the script? [Now/Delay/Specific]: " execution_choice

if [[ $execution_choice == "Now" ]]; then
    # Execute the script immediately
    echo "Executing the script now..."

elif [[ $execution_choice == "Delay" ]]; then
    read -p "Enter the delay in seconds: " delay
    execute_time=$((current_time + delay))
    echo "Executing the script after $delay seconds..."
    sleep $delay

elif [[ $execution_choice == "Specific" ]]; then
    read -p "Enter the specific time in HH:MM format: " specific_time
    specific_time_seconds=$(date -d "$specific_time" +%s)
    
    if [[ $specific_time_seconds -gt $current_time ]]; then
        sleep_duration=$((specific_time_seconds - current_time))
        echo "Executing the script at $specific_time..."
        sleep $sleep_duration
    else
        echo "Invalid time. Please provide a future time."
        exit 1
    fi

else
    echo "Invalid choice. Exiting."
    exit 1
fi


# Prompt the user to input the number of tests
while true; do
    read -p "Enter the number of tests: " num_tests
    if validate_number "$num_tests"; then
        break
    fi
done

# Prompt the user to input the sleep time between tests
while true; do
    read -p "Enter the sleep time between tests (in seconds): " sleep_time
    if validate_number "$sleep_time" && validate_sleep_time "$sleep_time"; then
        break
    fi
done

# Prompt the user to input the custom output directory
read -p "Enter the custom output directory path (default: current directory): " output_directory

# Use the custom output directory if provided, otherwise use the current directory
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
    output=$(speedtest-cli --bytes)

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
    download=$(echo $output | grep Download | awk '{print $2}')
    upload=$(echo $output | grep Upload | awk '{print $2}')

    # Add the current download and upload speeds to the total
    total_download=$((total_download + download))
    total_upload=$((total_upload + upload))

    # Sleep for the specified time before running the next test
    sleep $sleep_time

    # Append the results to the results CSV file
    echo "$download, $upload, $(date +"%Y-%m-%d %H:%M:%S")" >> "$results_filename"
done

# Calculate the average download and upload speeds
average_download=$((total_download / num_tests))
average_upload=$((total_upload / num_tests))

# Print the results
echo "Average download speed: $average_download"
echo "Average upload speed: $average_upload"

echo "Results appended to $results_filename"
echo "Error logs appended to $errors_filename"