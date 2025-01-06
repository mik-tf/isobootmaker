#!/bin/bash

# Part 1/3 - Script header and core functions
# Get script information dynamically
SCRIPT_NAME=$(basename "$0")
INSTALL_NAME="${SCRIPT_NAME%.*}"  # Removes the .sh extension if it exists
DISPLAY_NAME="${INSTALL_NAME^^}"  # Convert to uppercase for display
REPO_URL="https://github.com/Mik-TF/${INSTALL_NAME}"

# Script description - modify this for different uses
SCRIPT_DESC="Format a USB drive and make it bootable with ISO"

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to install the script
install() {
    echo
    echo -e "${GREEN}Installing ${DISPLAY_NAME}...${NC}"
    if sudo -v; then
        sudo cp "$0" "/usr/local/bin/${INSTALL_NAME}"
        sudo chown root:root "/usr/local/bin/${INSTALL_NAME}"
        sudo chmod 755 "/usr/local/bin/${INSTALL_NAME}"

        echo
        echo -e "${GREEN}${DISPLAY_NAME} has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}${INSTALL_NAME}${NC} command from anywhere."
        echo
        echo -e "Use ${BLUE}${INSTALL_NAME} help${NC} to see the commands."
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo
    echo -e "${GREEN}Uninstalling ${DISPLAY_NAME}...${NC}"
    if sudo -v; then
        sudo rm -f "/usr/local/bin/${INSTALL_NAME}"
        echo -e "${GREEN}${DISPLAY_NAME} has been uninstalled successfully.${NC}"
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

# Function to display help information
show_help() {
    cat << EOF
    
==========================
${DISPLAY_NAME}
==========================

This Bash CLI script can ${SCRIPT_DESC}.

Commands:
  help        Display this help message
  install     Install the script system-wide
  uninstall   Remove the script from the system

Options:
  No arguments    Run the interactive ${DISPLAY_NAME}

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
  ${INSTALL_NAME}
  ${INSTALL_NAME} help
  ${INSTALL_NAME} install
  ${INSTALL_NAME} uninstall

Reference: ${REPO_URL}

License: Apache 2.0
  
EOF
}

# Function to check for sudo privileges and request if needed
ensure_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "Requesting sudo privileges..."
        if ! sudo -v; then
            echo -e "${RED}Failed to obtain sudo privileges${NC}"
            exit 1
        fi
    fi
}

# Part 2/3 - Helper functions:

# Function to handle exit consistently
handle_exit() {
    echo -e "${BLUE}Exiting ${DISPLAY_NAME}...${NC}"
    exit 0
}

# Function to display lsblk and allow exit
show_lsblk() {
    echo
    echo -e "${BLUE}Current disk layout:${NC}"
    echo
    lsblk
    echo
    echo -e "${PURPLE}This is your current disk layout. Consider this before proceeding.${NC}"
    echo

    while true; do
        read -p "Press Enter to continue, or type 'exit' to quit: " response
        case "${response,,}" in  # Convert to lowercase
            exit ) handle_exit;;
            "" ) break;;  # Empty input (Enter key) continues
            * ) echo -e "${RED}Invalid input. Please press Enter or type 'exit'.${NC}";;
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
            * ) echo -e "${RED}Please answer 'y', 'n', or 'exit'.${NC}";;
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
                    echo -e "${BLUE}Unmounting $unmount_path...${NC}"
                    ensure_sudo
                    sudo umount -- "$unmount_path" || {
                        umount_result=$?
                        echo -e "${RED}Error unmounting $unmount_path (exit code: $umount_result)${NC}"
                    }
                fi
                break ;;
            n ) break;;
            exit ) handle_exit;;
            * ) echo -e "${RED}Please answer 'y', 'n', or 'exit'.${NC}";;
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

    echo -e "${BLUE}Downloading ISO to $filepath...${NC}"
    echo -e "${PURPLE}This may take a while depending on your internet connection...${NC}"
    
    if wget --show-progress -c "$url" -O "$filepath"; then
        echo -e "${GREEN}Download completed successfully${NC}"
        echo "$filepath"
        return 0
    else
        echo -e "${RED}Error downloading ISO${NC}"
        return 1
    fi
}

# Function to validate ISO file
validate_iso() {
    local file="$1"
    
    # Expand the path (handle ~, etc.)
    file=$(eval echo "$file")
    
    echo -e "${BLUE}Checking ISO file: $file${NC}"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File does not exist${NC}"
        return 1
    fi
    
    # Check file extension
    if [[ "$file" != *.iso ]]; then
        echo -e "${RED}Error: File does not have .iso extension${NC}"
        return 1
    fi
    
    echo -e "${GREEN}ISO file validation successful${NC}"
    return 0
}

# Part 3/3 - Main execution flow
# Verify dependencies
for cmd in dd mount rsync wget; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed. Please install it first.${NC}"
        exit 1
    fi
done

# Check for arguments
case "$1" in
    "help")
        show_help
        exit 0
        ;;
    "install")
        install
        exit 0
        ;;
    "uninstall")
        uninstall
        exit 0
        ;;
    "")
        # Continue with normal execution
        ;;
    *)
        echo -e "${RED}Invalid argument. Use '${INSTALL_NAME} help' to see available commands.${NC}"
        exit 1
        ;;
esac

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
                    echo -e "${RED}Error: Cannot use system disk as target.${NC}"
                    continue
                fi
                
                # Check if the target disk is mounted
                if mount | grep -q "$disk_to_format"; then
                    echo -e "${RED}Error: Target disk is mounted. Please unmount it first.${NC}"
                    continue
                fi
                
                break
            else
                echo -e "${RED}Error: Invalid disk format or device does not exist. Please enter /dev/sdX (e.g., /dev/sdb).${NC}"
            fi
            ;;
    esac
done

# Get ISO path or URL (with validation)
while true; do
    echo
    echo -e "${BLUE}You can either:${NC}"
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
                    echo -e "${RED}Error: Failed to download or validate ISO file.${NC}"
                fi
            else
                # Treat as local file path
                iso_input=$(eval echo "$iso_input")  # Expand the path
                if validate_iso "$iso_input"; then
                    iso_path="$iso_input"
                    break
                else
                    echo -e "${RED}Error: Invalid ISO file. Please provide a valid path to a .iso file or a download URL.${NC}"
                fi
            fi
            ;;
    esac
done

# Confirm formatting
if ! get_confirmation "Are you sure you want to format $disk_to_format? This will ERASE ALL DATA"; then
    echo
    echo -e "${BLUE}Operation cancelled.${NC}"
    echo
    exit 0
fi

# Ensure sudo privileges before writing ISO
ensure_sudo

# Write ISO to USB drive
echo -e "${BLUE}Writing ISO to USB drive... This may take several minutes...${NC}"
if sudo dd bs=4M if="$iso_path" of="$disk_to_format" status=progress conv=fdatasync; then
    echo -e "${GREEN}ISO successfully written to USB drive${NC}"
else
    echo -e "${RED}Error writing ISO to USB drive${NC}"
    exit 1
fi

# Sync to ensure all writes are complete
sync

# Ask about ejecting
if get_confirmation "Do you want to eject the disk?"; then
    echo -e "${BLUE}Ejecting $disk_to_format...${NC}"
    ensure_sudo
    sudo eject "$disk_to_format" || {
        echo -e "${RED}Error ejecting disk${NC}"
        exit 1
    }
    echo -e "${GREEN}Disk ejected successfully${NC}"
fi

echo
echo -e "${GREEN}${DISPLAY_NAME} completed successfully!${NC}"
echo