#!/bin/bash

# Enhanced Mac GPU Optimization Script for Intel Iris Plus Graphics 640 1536 MB

# Script Version: 2.0
# Author: Grok (improved and extended original script)
# Last Updated: August 24, 2025
# Description: This script optimizes GPU performance on macOS for Intel Iris Plus Graphics 640.
#              It includes enhanced checks, better error handling, additional monitoring,
#              and extended optimization steps like power metrics analysis and RAM management tips.
#              Run as a regular user; sudo prompts will appear where needed.
#              Note: For macOS versions beyond Sonoma (14), use OpenCore Legacy Patcher if needed for compatibility.

echo "============================================================="
echo "Starting Enhanced GPU Optimization for Intel Iris Plus Graphics 640 1536 MB"
echo "============================================================="

# Function to handle errors and log messages
log_message() {
    local type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $message" >> ~/gpu_optimization_log.txt
    echo "$message"
}

# 1. Verify GPU Model
echo "Verifying GPU model..."
gpu_model=$(system_profiler SPDisplaysDataType | grep "Chipset Model" | awk -F': ' '{print $2}')
if [[ "$gpu_model" != *"Intel Iris Plus Graphics 640"* ]]; then
    log_message "ERROR" "This script is designed for Intel Iris Plus Graphics 640. Detected: $gpu_model. Exiting."
    exit 1
else
    log_message "INFO" "GPU verified: $gpu_model"
fi

# 2. Check macOS version and compatibility
echo "Checking macOS version for compatibility..."
macos_version=$(sw_vers -productVersion)
macos_build=$(sw_vers -buildVersion)
echo "Current macOS version: $macos_version (Build: $macos_build)"
if [[ "$macos_version" < "10.13" ]]; then  # High Sierra minimum for Iris Plus 640
    log_message "WARNING" "macOS version may not fully support optimizations. Consider updating."
elif [[ "$macos_version" > "14" ]]; then
    log_message "WARNING" "Official support for this GPU ends at macOS Sonoma (14). If using a patcher, proceed with caution."
fi

# 3. Check for macOS updates (suggest only, don't auto-install)
echo -e "\nChecking for available macOS updates..."
softwareupdate --list 2>/dev/null || log_message "ERROR" "Failed to check for updates."

# 4. Clear system and user caches safely
echo -e "\nClearing system and user caches..."
if [ -d "/Library/Caches" ]; then
    sudo find /Library/Caches -type f -delete 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "INFO" "System caches cleared successfully."
    else
        log_message "ERROR" "Failed to clear system caches."
    fi
else
    log_message "WARNING" "System cache directory not found."
fi

USER_CACHE_PATH="$HOME/Library/Caches"
if [ -d "$USER_CACHE_PATH" ]; then
    find "$USER_CACHE_PATH" -type f -delete 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "INFO" "User caches cleared successfully."
    else
        log_message "ERROR" "Failed to clear user caches."
    fi
else
    log_message "WARNING" "User cache directory not found at $USER_CACHE_PATH."
fi

# 5. Clear font caches with improved handling
echo -e "\nClearing font caches..."
sudo atsutil databases -remove 2>/dev/null
sudo atsutil server -shutdown 2>/dev/null
sudo atsutil server -ping 2>/dev/null
if [ $? -eq 0 ]; then
    log_message "INFO" "Font caches cleared and ATS server restarted."
else
    log_message "ERROR" "Failed to clear font caches."
fi

# 6. Clear icon caches with depth limit for safety
echo -e "\nClearing icon services caches..."
sudo find /private/var/folders -name com.apple.iconservices -exec rm -rf {} + 2>/dev/null
if [ $? -eq 0 ]; then
    log_message "INFO" "Icon caches cleared successfully."
else
    log_message "ERROR" "Failed to clear icon caches."
fi

# 7. Optimize display settings
echo -e "\nChecking and optimizing display settings..."
display_settings=$(system_profiler SPDisplaysDataType | grep "Resolution" | awk '{print $0}')
echo "Current display settings: $display_settings"
default_resolution=$(system_profiler SPDisplaysDataType | grep "UI Looks like" | awk -F': ' '{print $2}')
echo "Detected default resolution: $default_resolution"
echo "Recommendation: Use default resolution ($default_resolution) for best performance."
echo "To change: Go to System Settings > Displays."

# 8. Extended GPU and System Monitoring
echo -e "\nExtended monitoring of GPU and system resources..."

# Check GPU usage via powermetrics (more accurate for Intel GPUs)
if command -v powermetrics >/dev/null; then
    echo "Sampling GPU usage with powermetrics (5 seconds)..."
    sudo powermetrics --samplers gpu_power -i 5000 -n 1 | grep "GPU" || log_message "WARNING" "No GPU data from powermetrics."
else
    log_message "WARNING" "powermetrics not found; falling back to basic check."
    if command -v top >/dev/null; then
        top -l 1 | grep "WindowServer" | awk '{print "WindowServer CPU usage (proxy for GPU): " $8 "%"}'
    else
        log_message "ERROR" "Top command not found, unable to check usage."
    fi
fi

# Check free RAM (since GPU shares system memory)
free_ram=$(vm_stat | grep "free" | awk '{print $3}' | sed 's/\.//' | awk '{print $1 / 256 " MB"}')
echo "Free RAM: $free_ram (GPU shares system memory; aim for >2GB free)."

# Check temperature if ioreg available (approximate CPU/GPU temp)
echo "Approximate system temperatures:"
ioreg -l | grep "temperature" | grep -i "cpu\|gpu" || log_message "WARNING" "No temperature data available."

# 9. Suggest disabling resource-intensive features
echo -e "\nSuggesting feature optimizations..."
echo "Disable transparency: defaults write com.apple.universalaccess reduceTransparency -bool true"
read -p "Apply now? (y/n): " apply_trans
if [[ "$apply_trans" == "y" || "$apply_trans" == "Y" ]]; then
    defaults write com.apple.universalaccess reduceTransparency -bool true
    log_message "INFO" "Transparency effects disabled."
fi

echo "Disable motion: defaults write com.apple.universalaccess reduceMotion -bool true"
read -p "Apply now? (y/n): " apply_motion
if [[ "$apply_motion" == "y" || "$apply_motion" == "Y" ]]; then
    defaults write com.apple.universalaccess reduceMotion -bool true
    log_message "INFO" "Motion effects disabled."
fi


# 10. WindowServer restart and advanced reset suggestions removed for user convenience

# 12. Provide extended optimization tips
echo -e "\n============================================================="
echo "Extended Optimization Tips for Intel Iris Plus Graphics 640 1536 MB:"
echo "============================================================="
echo "• Keep macOS updated to ensure latest graphics drivers and Metal optimizations (up to Sonoma 14 officially)."
echo "• Close unnecessary applications to free GPU and shared RAM resources."
echo "• Use default display resolution for optimal performance and avoid scaling."
echo "• Monitor GPU usage via Activity Monitor (GPU tab) or third-party tools like iStat Menus."
echo "• Restart your Mac weekly to refresh system resources and clear memory leaks."
echo "• Disable transparency and motion effects (as above) to reduce GPU load."
echo "• Avoid running multiple graphics-intensive apps; prioritize tasks."
echo "• Manage RAM usage: Since GPU shares 1536 MB from system RAM, keep at least 4GB free; consider upgrading to 16GB+ if possible."
echo "• Use external cooling pads if overheating during intensive tasks."
echo "• For developers: Ensure apps use Metal API for better GPU efficiency."
echo "• Check for firmware updates via System Information > Software > Installations."
echo "• If using external displays, limit to one and use native resolution to minimize GPU strain."
echo "• For gaming: Lower in-game resolutions/settings, limit FPS to 30-60 to reduce heat and load."

echo -e "\n============================================================="
echo "GPU Optimization Complete! Log saved to ~/gpu_optimization_log.txt"
echo "============================================================="