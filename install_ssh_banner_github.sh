#!/bin/bash

# This script automates the installation and configuration of a dynamic SSH banner.
# It requires root privileges to modify system files and services.

# --- Configuration Variables ---
BANNER_GENERATOR_SCRIPT="/etc/ssh/generate_sshd_banner.sh"
DYNAMIC_BANNER_FILE="/etc/ssh/sshd_dynamic_banner.txt"
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
CRON_JOB_ENTRY="*/5 * * * * ${BANNER_GENERATOR_SCRIPT} >/dev/null 2>&1"

# --- Static Owner Information (Customize these!) ---
OWNER_NAME="[EXAMPLE]"
OWNER_EMAIL="[example@example.com]"
OWNER_PHONE="[555-555-5555]"

# --- ASCII Art ---
# IMPORTANT: The 'EOF_ART' marker must be on a line by itself, with no leading or trailing whitespace.
read -r -d '' CUSTOM_ASCII_ART << 'EOF_ART'

███████╗██╗  ██╗ █████╗ ███╗   ███╗██████╗ ██╗     ███████╗
██╔════╝╚██╗██╔╝██╔══██╗████╗ ████║██╔══██╗██║     ██╔════╝
█████╗   ╚███╔╝ ███████║██╔████╔██║██████╔╝██║     █████╗  
██╔══╝   ██╔██╗ ██╔══██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝  
███████╗██╔╝ ██╗██║  ██║██║ ╚═╝ ██║██║     ███████╗███████╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝

EOF_ART

# --- Check for Root Privileges ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use 'sudo ./install_ssh_banner.sh'"
   exit 1
fi

echo "Starting dynamic SSH banner installation..."

# --- 1. Create the Banner Generation Script ---
echo "Creating banner generation script: ${BANNER_GENERATOR_SCRIPT}"
cat << EOF > "${BANNER_GENERATOR_SCRIPT}"
#!/bin/bash

# Define the output file for the banner
BANNER_FILE="${DYNAMIC_BANNER_FILE}"

# Set a robust PATH for cron execution
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Define static owner information
OWNER_NAME="${OWNER_NAME}"
OWNER_EMAIL="${OWNER_EMAIL}"
OWNER_PHONE="${OWNER_PHONE}"

# Get dynamic system information
SYSTEM_NAME=\$(hostname)
IP_ADDRESS=\$(hostname -I | awk '{print \$1}' | head -n 1) # Gets the first IPv4 address
# OS_VERSION detection
OS_VERSION=\$(
    if [ -f /etc/os-release ]; then
        grep -E '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"'
    elif command -v lsb_release &>/dev/null; then
        lsb_release -ds
    elif [ -f /etc/issue ]; then
        head -n 1 /etc/issue | sed 's/\\\\n//g;s/\\\\l//g'
    else
        echo "Unknown OS"
    fi
)
LOGIN_TIME=\$(date +"%Y-%m-%d %H:%M:%S %Z")

# Define box characters
CORNER_TOP_LEFT="╔"
CORNER_TOP_RIGHT="╗"
CORNER_BOTTOM_LEFT="╚"
CORNER_BOTTOM_RIGHT="╝"
HORIZONTAL_LINE="═"
VERTICAL_LINE="║"

# Calculate padding for centering
# Max content width is 63 characters (excluding vertical lines and padding)
MAX_CONTENT_WIDTH=63

# Function to calculate visual width of a string
# This helps with multi-byte characters that are single-width (like box-drawing chars)
get_visual_width() {
    echo -n "\$1" | wc -m
}

# Function to print a centered line (for single lines)
print_centered() {
    local text="\$1"
    local visual_width=\$(get_visual_width "\$text")
    local padding_left=\$(( (MAX_CONTENT_WIDTH - visual_width) / 2 ))
    local padding_right=\$(( MAX_CONTENT_WIDTH - visual_width - padding_left ))
    printf "${VERTICAL_LINE}%*s%s%*s${VERTICAL_LINE}\n" "\$padding_left" "" "\$text" "\$padding_right" ""
}

# Function to print multi-line ASCII art within the box
print_ascii_art() {
    local art_lines="\$1"
    IFS=\$'\n' # Set Internal Field Separator to newline for iterating lines
    for line in \$art_lines; do
        print_centered "\$line"
    done
    unset IFS # Reset IFS
}

# Define your ASCII art here using a heredoc
# IMPORTANT: The 'EOF_ART_INNER' marker must be on a line by itself, with no leading or trailing whitespace.
read -r -d '' ASCII_ART_INNER << 'EOF_ART_INNER'
${CUSTOM_ASCII_ART}
EOF_ART_INNER

# Generate the banner content and redirect to the banner file
{
echo "${CORNER_TOP_LEFT}\$(printf '%*s' "\$MAX_CONTENT_WIDTH" | tr ' ' "${HORIZONTAL_LINE}")${CORNER_TOP_RIGHT}"
print_ascii_art "\$ASCII_ART_INNER" # Insert the ASCII art here
echo "${VERTICAL_LINE}\$(printf '%*s' "\$MAX_CONTENT_WIDTH" | tr ' ' "${HORIZONTAL_LINE}")${VERTICAL_LINE}" # Separator line
print_centered "System Name: \${SYSTEM_NAME}"
print_centered "IP Address: \${IP_ADDRESS}"
print_centered "OS Version: \${OS_VERSION}"
print_centered "Login Time: \${LOGIN_TIME}"
echo "${VERTICAL_LINE}\$(printf '%*s' "\$MAX_CONTENT_WIDTH" | tr ' ' "${HORIZONTAL_LINE}")${VERTICAL_LINE}" # Separator line
print_centered "Owner: \${OWNER_NAME}"
print_centered "Email: \${OWNER_EMAIL}"
print_centered "Phone: \${OWNER_PHONE}"
echo "${CORNER_BOTTOM_LEFT}\$(printf '%*s' "\$MAX_CONTENT_WIDTH" | tr ' ' "${HORIZONTAL_LINE}")${CORNER_BOTTOM_RIGHT}"
} > "\${BANNER_FILE}"
EOF

# --- 2. Make the Script Executable ---
echo "Setting execute permissions for ${BANNER_GENERATOR_SCRIPT}"
chmod +x "${BANNER_GENERATOR_SCRIPT}"

# --- 3. Generate the Initial Banner File ---
echo "Generating initial banner file: ${DYNAMIC_BANNER_FILE}"
"${BANNER_GENERATOR_SCRIPT}"

# --- 4. Configure sshd_config ---
echo "Configuring sshd_config: ${SSHD_CONFIG_FILE}"
# Check if Banner line exists and replace it, otherwise add it
if grep -qE "^[[:space:]]*Banner" "${SSHD_CONFIG_FILE}"; then
    sed -i "s|^[[:space:]]*Banner.*|Banner ${DYNAMIC_BANNER_FILE}|" "${SSHD_CONFIG_FILE}"
    echo "  - Updated existing 'Banner' directive."
else
    echo "Banner ${DYNAMIC_BANNER_FILE}" >> "${SSHD_CONFIG_FILE}"
    echo "  - Added 'Banner' directive."
fi

# Ensure UsePAM is enabled (important for Banner to work)
if grep -qE "^[[:space:]]*UsePAM[[:space:]]+no" "${SSHD_CONFIG_FILE}"; then
    sed -i "s|^[[:space:]]*UsePAM[[:space:]]+no|UsePAM yes|" "${SSHD_CONFIG_FILE}"
    echo "  - Changed 'UsePAM no' to 'UsePAM yes'."
elif ! grep -qE "^[[:space:]]*UsePAM[[:space:]]+yes" "${SSHD_CONFIG_FILE}"; then
    echo "UsePAM yes" >> "${SSHD_CONFIG_FILE}"
    echo "  - Added 'UsePAM yes' directive."
fi


# --- 5. Set up a Cron Job for Dynamic Updates ---
echo "Setting up cron job for dynamic updates"
# Add cron job if it doesn't already exist
(crontab -l 2>/dev/null | grep -v -F "${BANNER_GENERATOR_SCRIPT}" ; echo "${CRON_JOB_ENTRY}") | crontab -
echo "  - Cron job added/updated to run every 5 minutes."

# --- 6. Restart the SSH Service ---
echo "Restarting SSH service..."
if command -v systemctl &>/dev/null; then
    systemctl restart sshd
elif command -v service &>/dev/null; then
    service sshd restart
else
    echo "Warning: Could not find systemctl or service command. Please restart SSH manually."
fi

echo "Dynamic SSH banner setup complete!"
echo "Please test by trying to SSH into your system."
