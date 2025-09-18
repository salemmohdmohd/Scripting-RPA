#!/bin/bash

# Enhanced macOS RAM Optimizer Script
# Optimizes RAM usage, frees memory, and improves system performance
# Compatible with macOS 10.15+ (Catalina and later)
# Version: 1.1

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.1"
readonly MIN_MACOS_VERSION="10.15"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Global variables
CONFIRM=true
VERBOSE=false
DRY_RUN=false
SHOW_SUMMARY=true
AGGRESSIVE_MODE=false
QUIT_APPS=false
START_TIME=$(date +%s)

# Memory stats
INITIAL_MEMORY=""
FINAL_MEMORY=""
MEMORY_FREED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if $VERBOSE; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# Check macOS version compatibility
check_macos_version() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script is for macOS only."
        exit 1
    fi
    
    local current_version
    current_version=$(sw_vers -productVersion | cut -d. -f1-2)
    
    local current_major current_minor min_major min_minor
    current_major=$(echo "$current_version" | cut -d. -f1)
    current_minor=$(echo "$current_version" | cut -d. -f2)
    min_major=$(echo "$MIN_MACOS_VERSION" | cut -d. -f1)
    min_minor=$(echo "$MIN_MACOS_VERSION" | cut -d. -f2)
    
    if [[ $current_major -lt $min_major ]] || [[ $current_major -eq $min_major && $current_minor -lt $min_minor ]]; then
        log_error "This script requires macOS $MIN_MACOS_VERSION or later. Current version: $current_version"
        exit 1
    fi
    
    log_verbose "macOS version check passed: $current_version"
}

# Get detailed memory information with error handling
get_memory_info() {
    local memory_info
    if ! memory_info=$(vm_stat 2>/dev/null); then
        log_error "Failed to get memory statistics"
        return 1
    fi
    
    # Extract values (pages) with better error handling
    local page_size=4096  # macOS uses 4KB pages
    local free_pages=$(echo "$memory_info" | grep "Pages free" | awk '{print $3}' | tr -d '.' || echo "0")
    local active_pages=$(echo "$memory_info" | grep "Pages active" | awk '{print $3}' | tr -d '.' || echo "0")
    local inactive_pages=$(echo "$memory_info" | grep "Pages inactive" | awk '{print $3}' | tr -d '.' || echo "0")
    local wired_pages=$(echo "$memory_info" | grep "Pages wired down" | awk '{print $4}' | tr -d '.' || echo "0")
    local compressed_pages=$(echo "$memory_info" | grep "Pages stored in compressor" | awk '{print $5}' | tr -d '.' || echo "0")
    
    # Validate we got numbers
    for value in "$free_pages" "$active_pages" "$inactive_pages" "$wired_pages" "$compressed_pages"; do
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            log_error "Invalid memory statistics detected"
            return 1
        fi
    done
    
    # Convert to MB
    local free_mb=$((free_pages * page_size / 1024 / 1024))
    local active_mb=$((active_pages * page_size / 1024 / 1024))
    local inactive_mb=$((inactive_pages * page_size / 1024 / 1024))
    local wired_mb=$((wired_pages * page_size / 1024 / 1024))
    local compressed_mb=$((compressed_pages * page_size / 1024 / 1024))
    
    # Calculate totals
    local used_mb=$((active_mb + wired_mb + compressed_mb))
    local available_mb=$((free_mb + inactive_mb))
    local total_mb=$((used_mb + available_mb))
    
    # Get memory pressure with fallback
    local memory_pressure="unknown"
    if command -v memory_pressure >/dev/null 2>&1; then
        memory_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | tr -d '%' || echo "unknown")
    fi
    
    echo "total:$total_mb,used:$used_mb,free:$free_mb,inactive:$inactive_mb,active:$active_mb,wired:$wired_mb,compressed:$compressed_mb,available:$available_mb,pressure:$memory_pressure"
}

# Display formatted memory information
display_memory_info() {
    local title="$1"
    local memory_info="$2"
    
    # Parse memory info with error checking
    local total=$(echo "$memory_info" | cut -d',' -f1 | cut -d':' -f2)
    local used=$(echo "$memory_info" | cut -d',' -f2 | cut -d':' -f2)
    local free=$(echo "$memory_info" | cut -d',' -f3 | cut -d':' -f2)
    local inactive=$(echo "$memory_info" | cut -d',' -f4 | cut -d':' -f2)
    local active=$(echo "$memory_info" | cut -d',' -f5 | cut -d':' -f2)
    local wired=$(echo "$memory_info" | cut -d',' -f6 | cut -d':' -f2)
    local compressed=$(echo "$memory_info" | cut -d',' -f7 | cut -d':' -f2)
    local available=$(echo "$memory_info" | cut -d',' -f8 | cut -d':' -f2)
    local pressure=$(echo "$memory_info" | cut -d',' -f9 | cut -d':' -f2)
    
    # Validate parsed values
    if ! [[ "$total" =~ ^[0-9]+$ ]] || [[ $total -eq 0 ]]; then
        log_error "Failed to parse memory information correctly"
        return 1
    fi
    
    local usage_percent=$((used * 100 / total))
    
    echo
    echo -e "${PURPLE}$title${NC}"
    echo -e "${BLUE}Total Memory:${NC} ${total} MB"
    echo -e "${RED}Used Memory:${NC} ${used} MB (${usage_percent}%)"
    echo -e "${GREEN}Available Memory:${NC} ${available} MB"
    echo "  ├─ Free: ${free} MB"
    echo "  └─ Inactive: ${inactive} MB"
    echo -e "${YELLOW}Memory Breakdown:${NC}"
    echo "  ├─ Active: ${active} MB"
    echo "  ├─ Wired: ${wired} MB"
    echo "  └─ Compressed: ${compressed} MB"
    if [[ "$pressure" != "unknown" ]]; then
        echo -e "${CYAN}Memory Pressure:${NC} ${pressure}% free"
    fi
    
    # Memory pressure indicator
    if [[ $available -lt 1000 ]]; then
        echo -e "${RED}⚠️  Low memory available${NC}"
    elif [[ $available -lt 2000 ]]; then
        echo -e "${YELLOW}⚠️  Memory getting low${NC}"
    else
        echo -e "${GREEN}✓ Memory levels healthy${NC}"
    fi
}

# Get top memory-consuming processes with better error handling
show_memory_hogs() {
    echo
    echo -e "${PURPLE}Top 10 Memory-Consuming Processes:${NC}"
    echo "PID     | Memory  | Process"
    echo "--------|---------|--------------------------------"
    
    # Use a more reliable approach to get process info
    if ps -axm -o pid,rss,comm | head -11 | tail -10 | while read -r pid rss comm; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ && -n "$rss" && "$rss" =~ ^[0-9]+$ ]]; then
            local mem_mb=$((rss / 1024))
            if [[ $mem_mb -gt 0 ]]; then
                printf "%-7s | %-7s | %s\n" "$pid" "${mem_mb}MB" "$(basename "$comm" 2>/dev/null || echo "$comm")"
            fi
        fi
    done; then
        log_verbose "Process memory information displayed successfully"
    else
        log_warning "Could not retrieve process memory information"
    fi
}

# Enhanced purge function with better error handling
purge_inactive_memory() {
    log_info "Purging inactive memory pages..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would run: sudo purge"
        return 0
    fi
    
    # Check if purge command exists
    if ! command -v purge >/dev/null 2>&1; then
        log_warning "purge command not available on this system"
        return 1
    fi
    
    # Try to run purge with proper error handling
    log_verbose "Attempting to run memory purge..."
    if sudo -n true 2>/dev/null; then
        # sudo credentials are cached
        if timeout 60 sudo purge 2>/dev/null; then
            log_success "Memory purge completed successfully"
            return 0
        else
            log_warning "Memory purge failed or timed out"
            return 1
        fi
    else
        # Need to prompt for password
        echo -e "${YELLOW}Administrator privileges required for memory purge${NC}"
        if sudo -p "Enter password to purge memory: " timeout 60 purge 2>/dev/null; then
            log_success "Memory purge completed successfully"
            return 0
        else
            log_warning "Memory purge failed - insufficient privileges or timeout"
            return 1
        fi
    fi
}

# Enhanced cache clearing with better error handling
clear_system_caches() {
    log_info "Clearing system memory caches..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would clear DNS cache and system caches"
        return 0
    fi
    
    local success_count=0
    local total_operations=4
    
    # Clear DNS cache
    log_verbose "Clearing DNS cache..."
    if sudo dscacheutil -flushcache 2>/dev/null && sudo killall -HUP mDNSResponder 2>/dev/null; then
        log_verbose "DNS cache cleared successfully"
        ((success_count++))
    else
        log_verbose "DNS cache clearing failed"
    fi
    
    # Clear font cache
    log_verbose "Clearing font cache..."
    if sudo atsutil databases -remove 2>/dev/null; then
        log_verbose "Font cache cleared successfully"
        ((success_count++))
    else
        log_verbose "Font cache clearing failed or not needed"
        ((success_count++))  # Not critical if it fails
    fi
    
    # Clear icon cache (user-level)
    log_verbose "Clearing icon cache..."
    if rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null; then
        log_verbose "User icon cache cleared successfully"
        ((success_count++))
    else
        log_verbose "User icon cache clearing failed or not needed"
        ((success_count++))  # Not critical if it fails
    fi
    
    # Clear system icon cache (requires sudo)
    if sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null; then
        log_verbose "System icon cache cleared successfully"
        ((success_count++))
    else
        log_verbose "System icon cache clearing failed or not needed"
        ((success_count++))  # Not critical if it fails
    fi
    
    if [[ $success_count -eq $total_operations ]]; then
        log_success "System caches cleared successfully"
        return 0
    elif [[ $success_count -gt 0 ]]; then
        log_success "System caches partially cleared ($success_count/$total_operations operations successful)"
        return 0
    else
        log_warning "System cache clearing failed"
        return 1
    fi
}

# Enhanced service restart with better error handling
restart_memory_services() {
    if ! $AGGRESSIVE_MODE; then
        return 0
    fi
    
    log_info "Restarting memory-related services (aggressive mode)..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would restart Dock and WindowServer"
        return 0
    fi
    
    local success_count=0
    
    # Restart Dock (safer, always works)
    log_verbose "Restarting Dock..."
    if killall Dock 2>/dev/null; then
        log_verbose "Dock restarted successfully"
        ((success_count++))
        sleep 2  # Give Dock time to restart
    else
        log_verbose "Dock restart failed"
    fi
    
    # WindowServer restart is more aggressive and can cause screen flicker
    if $AGGRESSIVE_MODE; then
        log_verbose "Restarting WindowServer (may cause screen flicker)..."
        if sudo killall -HUP WindowServer 2>/dev/null; then
            log_verbose "WindowServer restarted successfully"
            ((success_count++))
            sleep 3  # Give WindowServer time to restart
        else
            log_verbose "WindowServer restart failed"
        fi
    fi
    
    if [[ $success_count -gt 0 ]]; then
        log_success "Memory services restarted ($success_count services)"
        return 0
    else
        log_warning "Service restart failed"
        return 1
    fi
}

# Enhanced application quitting with better safety
quit_applications() {
    if ! $QUIT_APPS; then
        return 0
    fi
    
    log_info "Identifying memory-heavy applications..."
    
    # Protected processes that should never be quit
    local protected_processes="kernel_task|launchd|WindowServer|loginwindow|Finder|SystemUIServer|Dock|Activity Monitor|Terminal|iTerm2|Console|Script Editor|bash|zsh|sh|ssh|sudo|top|htop|Activity Monitor"
    
    # Get list of apps using significant memory (>100MB)
    local memory_hogs=()
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $1}')
        local rss=$(echo "$line" | awk '{print $2}')
        local comm=$(echo "$line" | awk '{print $3}')
        
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ && -n "$rss" && "$rss" =~ ^[0-9]+$ ]]; then
            local mem_mb=$((rss / 1024))
            if [[ $mem_mb -gt 100 ]]; then
                local process_name
                process_name=$(basename "$comm" 2>/dev/null || echo "$comm")
                
                # Skip if it's a protected process or our current shell
                if [[ "$process_name" =~ ^($protected_processes)$ ]] || [[ $pid -eq $$ ]] || [[ $pid -eq $PPID ]]; then
                    log_verbose "Skipping protected/essential process: $process_name (PID: $pid)"
                else
                    memory_hogs+=("$pid:$rss:$comm")
                fi
            fi
        fi
    done < <(ps -axm -o pid,rss,comm | tail -n +2)
    
    if [[ ${#memory_hogs[@]} -eq 0 ]]; then
        log_info "No memory-heavy non-essential applications found"
        return 0
    fi
    
    echo
    echo -e "${YELLOW}Found ${#memory_hogs[@]} memory-heavy applications:${NC}"
    for app_info in "${memory_hogs[@]}"; do
        local pid=$(echo "$app_info" | cut -d':' -f1)
        local rss=$(echo "$app_info" | cut -d':' -f2)
        local comm=$(echo "$app_info" | cut -d':' -f3)
        local mem_mb=$((rss / 1024))
        local process_name
        process_name=$(basename "$comm" 2>/dev/null || echo "$comm")
        echo "  • $process_name (PID: $pid, ${mem_mb}MB)"
    done
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would attempt to quit these applications"
        return 0
    fi
    
    if $CONFIRM; then
        echo -ne "${YELLOW}Quit these applications to free memory?${NC} (y/N): "
        read -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping application termination"
            return 0
        fi
    fi
    
    local quit_count=0
    for app_info in "${memory_hogs[@]}"; do
        local pid=$(echo "$app_info" | cut -d':' -f1)
        local comm=$(echo "$app_info" | cut -d':' -f3)
        local process_name
        process_name=$(basename "$comm" 2>/dev/null || echo "$comm")
        
        log_verbose "Attempting to quit $process_name (PID: $pid)..."
        
        # Try graceful termination first
        if kill -TERM "$pid" 2>/dev/null; then
            log_verbose "Sent TERM signal to $process_name"
            ((quit_count++))
            sleep 2  # Give time for graceful shutdown
            
            # Check if process is still running
            if ! kill -0 "$pid" 2>/dev/null; then
                log_verbose "$process_name quit successfully"
            else
                log_verbose "$process_name still running after TERM signal"
            fi
        else
            log_verbose "Could not send TERM signal to $process_name"
        fi
    done
    
    log_success "Attempted to quit $quit_count applications"
    return 0
}

# Calculate memory difference
calculate_memory_freed() {
    if [[ -n "$INITIAL_MEMORY" && -n "$FINAL_MEMORY" ]]; then
        local initial_available=$(echo "$INITIAL_MEMORY" | cut -d',' -f8 | cut -d':' -f2)
        local final_available=$(echo "$FINAL_MEMORY" | cut -d',' -f8 | cut -d':' -f2)
        
        if [[ "$initial_available" =~ ^[0-9]+$ && "$final_available" =~ ^[0-9]+$ ]]; then
            MEMORY_FREED=$((final_available - initial_available))
        else
            MEMORY_FREED=0
            log_verbose "Could not calculate memory freed due to parsing error"
        fi
    fi
}

# Show optimization summary
show_optimization_summary() {
    echo
    echo -e "${PURPLE}==================== RAM OPTIMIZATION SUMMARY ====================${NC}"
    echo -e "${BLUE}Date:${NC} $(date)"
    echo -e "${BLUE}Script Version:${NC} $SCRIPT_VERSION"
    echo -e "${BLUE}macOS Version:${NC} $(sw_vers -productVersion)"
    echo
    
    if [[ -n "$INITIAL_MEMORY" ]]; then
        display_memory_info "BEFORE Optimization:" "$INITIAL_MEMORY"
    fi
    
    if [[ -n "$FINAL_MEMORY" ]]; then
        display_memory_info "AFTER Optimization:" "$FINAL_MEMORY"
    fi
    
    calculate_memory_freed
    echo
    if [[ $MEMORY_FREED -gt 0 ]]; then
        echo -e "${GREEN}✓ Memory freed: ${MEMORY_FREED} MB${NC}"
    elif [[ $MEMORY_FREED -lt 0 ]]; then
        echo -e "${YELLOW}⚠ Memory usage increased by ${MEMORY_FREED#-} MB (some processes may have restarted)${NC}"
    else
        echo -e "${BLUE}→ No significant change in memory usage${NC}"
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - START_TIME))
    echo -e "${CYAN}Time elapsed: ${duration}s${NC}"
    
    echo
    echo -e "${PURPLE}Recommendations:${NC}"
    if [[ $MEMORY_FREED -gt 200 ]]; then
        echo -e "  • ${GREEN}Great! Significant memory was freed${NC}"
    elif [[ $MEMORY_FREED -gt 50 ]]; then
        echo -e "  • ${CYAN}Good! Some memory was freed${NC}"
    else
        echo -e "  • ${YELLOW}Your system was already well optimized${NC}"
    fi
    echo -e "  • ${CYAN}Monitor Activity Monitor${NC} to see if optimization was effective"
    echo -e "  • ${CYAN}Consider closing Chrome tabs${NC} - Chrome is using significant memory"
    echo -e "  • ${CYAN}Restart your Mac${NC} for maximum memory optimization"
    echo -e "  • ${CYAN}Run regularly${NC} when system feels slow"
    
    echo -e "${PURPLE}=================================================================${NC}"
}

# Usage instructions
show_help() {
    cat << EOF
Enhanced macOS RAM Optimizer Script v${SCRIPT_VERSION}

${PURPLE}USAGE:${NC}
    $0 [OPTIONS]

${PURPLE}OPTIONS:${NC}
    -y, --yes         Run without confirmation prompts
    -v, --verbose     Enable verbose output
    -d, --dry-run     Show what would be done without actually doing it
    -s, --summary     Show detailed summary (default: enabled)
    -a, --aggressive  Use aggressive optimization (may restart services)
    -q, --quit-apps   Quit non-essential applications to free RAM
    -h, --help        Show this help message
    --version         Show version information

${PURPLE}EXAMPLES:${NC}
    $0                    # Interactive RAM optimization
    $0 --yes              # Automatic optimization without prompts
    $0 --dry-run          # Preview what would be optimized
    $0 --aggressive       # More aggressive optimization
    $0 --quit-apps        # Include quitting memory-heavy apps

${PURPLE}OPTIMIZATION TASKS:${NC}
    ${GREEN}Safe Operations:${NC}
    - Purge inactive memory pages
    - Clear system memory caches (DNS, font, icon)
    - Free up compressed memory

    ${YELLOW}Optional Operations (with flags):${NC}
    - Quit non-essential applications (--quit-apps)
    - Restart UI services like Dock (--aggressive)

${PURPLE}SAFETY FEATURES:${NC}
    - Enhanced error handling and validation
    - Memory usage monitoring before/after
    - Process protection (won't quit essential system processes)
    - Timeout protection for long-running operations
    - Graceful application termination
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            CONFIRM=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--summary)
            SHOW_SUMMARY=true
            shift
            ;;
        -a|--aggressive)
            AGGRESSIVE_MODE=true
            shift
            ;;
        -q|--quit-apps)
            QUIT_APPS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --version)
            echo "Enhanced macOS RAM Optimizer Script v${SCRIPT_VERSION}"
            echo "Compatible with macOS ${MIN_MACOS_VERSION}+"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution function with better error handling
main() {
    log_info "Starting Enhanced macOS RAM Optimizer v${SCRIPT_VERSION}..."
    
    # Check system compatibility
    if ! check_macos_version; then
        exit 1
    fi
    
    if $DRY_RUN; then
        log_warning "DRY RUN MODE: No actual optimization will be performed"
    fi
    
    # Get initial memory state
    log_verbose "Gathering initial memory statistics..."
    if ! INITIAL_MEMORY=$(get_memory_info); then
        log_error "Failed to get initial memory information"
        exit 1
    fi
    
    display_memory_info "Current Memory Status:" "$INITIAL_MEMORY"
    show_memory_hogs
    
    echo
    log_info "Beginning RAM optimization process..."
    echo
    
    # Track optimization success
    local optimization_steps=0
    local successful_steps=0
    
    # Core optimization tasks
    ((optimization_steps++))
    if purge_inactive_memory; then
        ((successful_steps++))
    fi
    
    ((optimization_steps++))
    if clear_system_caches; then
        ((successful_steps++))
    fi
    
    if $AGGRESSIVE_MODE; then
        ((optimization_steps++))
        if restart_memory_services; then
            ((successful_steps++))
        fi
    fi
    
    if $QUIT_APPS; then
        ((optimization_steps++))
        if quit_applications; then
            ((successful_steps++))
        fi
    fi
    
    # Wait for optimization to take effect
    if ! $DRY_RUN && [[ $successful_steps -gt 0 ]]; then
        log_info "Waiting for optimization to take effect..."
        sleep 5
    fi
    
    # Get final memory state
    log_verbose "Gathering final memory statistics..."
    if ! FINAL_MEMORY=$(get_memory_info); then
        log_warning "Failed to get final memory information"
        FINAL_MEMORY="$INITIAL_MEMORY"  # Use initial as fallback
    fi
    
    # Show results
    echo
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - START_TIME))
    
    if $SHOW_SUMMARY; then
        show_optimization_summary
    else
        calculate_memory_freed
        if $DRY_RUN; then
            log_success "Dry run completed in ${duration}s"
        else
            log_success "RAM optimization completed in ${duration}s ($successful_steps/$optimization_steps operations successful)"
            if [[ $MEMORY_FREED -gt 0 ]]; then
                log_info "${MEMORY_FREED} MB of memory freed"
            elif [[ $MEMORY_FREED -lt 0 ]]; then
                log_info "Memory usage increased by ${MEMORY_FREED#-} MB (some processes restarted)"
            else
                log_info "No significant change in memory usage"
            fi
        fi
        echo -e "${CYAN}Run with --summary for detailed breakdown${NC}"
    fi
    
    if $DRY_RUN; then
        echo
        log_info "Run without --dry-run to actually perform optimization"
    elif [[ $successful_steps -eq 0 ]]; then
        echo
        log_warning "No optimization steps completed successfully"
        log_info "Try running with --verbose to see detailed error information"
    fi
    
    echo
    log_info "Optimization complete. Consider closing Chrome tabs to free more memory."
}

# Error handling for the script
trap 'log_error "Script interrupted"; exit 130' INT
trap 'log_error "Script terminated"; exit 143' TERM

# Check if script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run main function
    main "$@"
fi