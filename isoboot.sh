#!/bin/bash

# Script to format a USB drive and make it bootable with ISO

# Function to check for sudo privileges and request if needed
ensure_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "Requesting sudo privileges..."
        if ! sudo -v; then
            echo "Failed to obtain sudo privileges"
            exit 1
        fi
    fi
}

# Function to handle exit consistently
handle_exit() {
    echo "Exiting..."
    exit 0
}

# Function to display help information
show_help() {
    cat << EOF
    
==========================
ISO USB BOOTMAKER
==========================

This Bash CLI script formats a USB drive and installs an ISO bootable image.

Options:
  help        Display this help message.

Steps:
1. Prompts for a path to unmount (optional).
2. Prompts for the disk to format (e.g., /dev/sdb).  Must be a valid device.
3. Prompts for the ISO path or download URL.
4. Checks that the ISO exists and is valid.
5. Displays the current disk layout.
6. Confirms the formatting operation.
7. Writes the ISO to the USB drive.
8. Optionally ejects the USB drive.

Requirements:
- dd
- rsync
- mount
- wget (for downloading ISO)
- A downloaded ISO or URL to download from

Example:
  $0
  $0 help

Reference: https://github.com/Mik-TF/isobootmaker

License: Apache 2.0
  
EOF
}

# Function to display lsblk and allow exit
show_lsblk() {
    echo
    echo "Current disk layout:"
    echo
    lsblk
    echo
    echo "This is your current disk layout. Consider this before proceeding."
    echo

    while true; do
        read -p "Press Enter to continue, or type 'exit' to quit: " response
        case "${response,,}" in  # Convert to lowercase
            exit ) handle_exit;;
            "" ) break;;  # Empty input (Enter key) continues
            * ) echo "Invalid input. Please press Enter or type 'exit'.";;
        esac
    done
}

# Function to get user confirmation
get_confirmation() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt (y/n/exit): " response
        case "${response,,}" in
            y ) return 0;;
            n ) return 1;;
            exit ) handle_exit;;
            * ) echo "Please answer 'y', 'n', or 'exit'.";;
        esac
    done
}

# Function to get user input with exit option
get_input() {
    local prompt="$1"
    read -p "$prompt (or type 'exit'): " input
    case "${input,,}" in
        exit ) handle_exit;;
        * ) echo "$input";;
    esac
}

# Function to handle unmounting
ask_and_unmount() {
    while true; do
        read -p "Do you want to unmount a disk? (y/n/exit): " response
        case "${response,,}" in
            y ) 
                unmount_path=$(get_input "Enter the path to unmount (e.g., /mnt/usb)")
                if [[ -n "$unmount_path" ]]; then
                    echo "Unmounting $unmount_path..."
                    ensure_sudo
                    sudo umount -- "$unmount_path" || {
                        umount_result=$?
                        echo "Error unmounting $unmount_path (exit code: $umount_result)"
                    }
                fi
                break ;;
            n ) break;;
            exit ) handle_exit;;
            * ) echo "Please answer 'y', 'n', or 'exit'.";;
        esac
    done
}

# Function to download ISO
download_iso() {
    local url="$1"
    local download_dir="$HOME/Downloads"
    local filename

    # Create Downloads directory if it doesn't exist
    mkdir -p "$download_dir"

    # Extract filename from URL
    filename=$(basename "$url")
    local filepath="$download_dir/$filename"

    echo "Downloading ISO to $filepath..."
    echo "This may take a while depending on your internet connection..."
    
    if wget --show-progress -c "$url" -O "$filepath"; then
        echo "Download completed successfully"
        echo "$filepath"
        return 0
    else
        echo "Error downloading ISO"
        return 1
    fi
}

# Function to validate ISO file
validate_iso() {
    local file="$1"
    
    # Expand the path (handle ~, etc.)
    file=$(eval echo "$file")
    
    echo "Checking ISO file: $file"  # Debug output
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File does not exist"
        return 1
    fi
    
    # Check file extension
    if [[ "$file" != *.iso ]]; then
        echo "Error: File does not have .iso extension"
        return 1
    fi
    
    echo "ISO file validation successful"
    return 0
}

# Verify dependencies
for cmd in dd mount rsync wget; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Check if help is requested
if [[ "$1" == "help" ]]; then
    show_help
    exit 0
fi

# Display initial disk layout
show_lsblk

# Ask if the user wants to unmount and perform unmount if yes
ask_and_unmount

# Get disk to format (with validation and exit option)
while true; do
    read -p "Enter the disk to format (e.g., /dev/sdb) (or type 'exit'): " disk_to_format
    case "${disk_to_format,,}" in
        exit) handle_exit;;
        *)
            if [[ "$disk_to_format" =~ ^/dev/sd[b-z]$ ]] && [[ -b "$disk_to_format" ]]; then
                # Check if it's the system disk
                if [[ "$disk_to_format" == "/dev/sda" ]]; then
                    echo "Error: Cannot use system disk as target."
                    continue
                fi
                
                # Check if the target disk is mounted
                if mount | grep -q "$disk_to_format"; then
                    echo "Error: Target disk is mounted. Please unmount it first."
                    continue
                fi
                
                break
            else
                echo "Error: Invalid disk format or device does not exist. Please enter /dev/sdX (e.g., /dev/sdb)."
            fi
            ;;
    esac
done

# Get ISO path or URL (with validation)
while true; do
    echo
    echo "You can either:"
    echo "1. Provide the path to a local ISO"
    echo "2. Provide a download URL for the ISO"
    echo
    read -p "Enter the ISO path or URL (or type 'exit'): " iso_input
    
    case "${iso_input,,}" in
        exit)
            handle_exit
            ;;
        *)
            # Check if input is a URL
            if [[ "$iso_input" =~ ^https?:// ]]; then
                # Download the ISO
                iso_path=$(download_iso "$iso_input")
                if [[ $? -eq 0 ]] && validate_iso "$iso_path"; then
                    break
                else
                    echo "Error: Failed to download or validate ISO file."
                fi
            else
                # Treat as local file path
                iso_input=$(eval echo "$iso_input")  # Expand the path
                if validate_iso "$iso_input"; then
                    iso_path="$iso_input"
                    break
                else
                    echo "Error: Invalid ISO file. Please provide a valid path to a .iso file or a download URL."
                fi
            fi
            ;;
    esac
done

# Confirm formatting
if ! get_confirmation "Are you sure you want to format $disk_to_format? This will ERASE ALL DATA"; then
    echo
    echo "Operation cancelled."
    echo
    exit 0
fi

# Ensure sudo privileges before writing ISO
ensure_sudo

# Write ISO to USB drive
echo "Writing ISO to USB drive... This may take several minutes..."
if sudo dd bs=4M if="$iso_path" of="$disk_to_format" status=progress conv=fdatasync; then
    echo "ISO successfully written to USB drive"
else
    echo "Error writing ISO to USB drive"
    exit 1
fi

# Sync to ensure all writes are complete
sync

# Ask about ejecting
if get_confirmation "Do you want to eject the disk?"; then
    echo "Ejecting $disk_to_format..."
    ensure_sudo
    sudo eject "$disk_to_format" || {
        echo "Error ejecting disk"
        exit 1
    }
    echo "Disk ejected successfully"
fi

echo
echo "ISO bootable USB created successfully!"
echo
