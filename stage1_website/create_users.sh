#!/bin/bash

# Define log file and secure password file paths
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if the input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi

# Ensure the secure directory exists and set appropriate permissions
mkdir -p /var/secure
chmod 700 /var/secure
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Read the input file line by line
while IFS=";" read -r username groups; do
    # Remove any leading/trailing whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Create a personal group for the user if it doesn't exist
    if ! getent group "$username" >/dev/null; then
        groupadd "$username"
        log_message "Created group: $username"
    fi

    # Create the user with the personal group
    if ! id "$username" >/dev/null 2>&1; then
        useradd -m -g "$username" "$username"
        log_message "Created user: $username"
    else
        log_message "User $username already exists"
    fi

    # Generate a random password
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd
    log_message "Set password for user: $username"

    # Add the user to additional groups
    if [ -n "$groups" ]; then
        IFS=',' read -r -a group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            group=$(echo $group | xargs)
            if ! getent group "$group" >/dev/null; then
                groupadd "$group"
                log_message "Created group: $group"
            fi
            usermod -aG "$group" "$username"
            log_message "Added user $username to group: $group"
        done
    fi

    # Store the username and password securely
    echo "$username,$password" >> $PASSWORD_FILE

done < "$1"

log_message "User creation process completed."
