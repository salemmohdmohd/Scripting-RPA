#!/bin/bash

# Enhanced MacBook Cleanup Script
# Safely deletes temp files, clears caches, empties Trash, and more
# Compatible with macOS 10.15+ (Catalina and later)
# Version: 2.1

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="2.1"
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
SHOW_SUMMARY=false
TOTAL_FREED=0
START_TIME=$(date +%s)
FILES_REMOVED=0
CLEANUP_LOG=()

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

# Add entry to cleanup log
add_to_cleanup_log() {
    local action="$1"
    local size="$2"
    local status="$3"
    
    CLEANUP_LOG+=("$status | $action | $size")
    
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $action ${YELLOW}($size freed)${NC}"
            ;;
        "SKIPPED")
            echo -e "${YELLOW}⊝${NC} $action ${CYAN}(not found)${NC}"
            ;;
        "FAILED")
            echo -e "${RED}✗${NC} $action ${RED}(failed)${NC}"
            ;;
        "DRY_RUN")
            echo -e "${BLUE}[DRY]${NC} $action ${YELLOW}($size would be freed)${NC}"
            ;;
    esac
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

# Calculate directory size (in bytes)
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        local kb_size
        kb_size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        if [[ -n "$kb_size" && "$kb_size" =~ ^[0-9]+$ ]]; then
            echo $((kb_size * 1024))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -eq 0 ]]; then
        echo "0 B"
    elif [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( bytes / 1024 )) KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( bytes / 1048576 )) MB"
    else
        echo "$(( bytes / 1073741824 )) GB"
    fi
}

# Expand tilde in paths
expand_path() {
    local path="$1"
    if [[ "$path" =~ ^~(.*)$ ]]; then
        path="$HOME${BASH_REMATCH[1]}"
    fi
    echo "$path"
}

# Progress spinner
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:$i:1}"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\b "
}

# Show current operation
show_progress() {
    local operation="$1"
    local path="$2"
    echo -e "${CYAN}[PROGRESS]${NC} $operation: $path"
}

# Safe delete function with size calculation and dry run support
safe_delete() {
    local path="$1"
    local description="$2"
    local size_before=0
    
    path=$(expand_path "$path")
    show_progress "Processing" "$description"
    
    # Handle wildcards by expanding them
    if [[ "$path" == *"*"* ]]; then
        # Use find for wildcard patterns
        local base_dir="${path%/*}"
        local pattern="${path##*/}"
        
        if [[ -d "$base_dir" ]]; then
            echo -e "${CYAN}→${NC} Scanning for files matching pattern..."
            local found_files=()
            while IFS= read -r -d '' file; do
                found_files+=("$file")
                # Show progress every 50 files found
                if [[ $((${#found_files[@]} % 50)) -eq 0 ]]; then
                    echo -e "${CYAN}→${NC} Found ${#found_files[@]} files so far..."
                fi
            done < <(find "$base_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
            
            if [[ ${#found_files[@]} -gt 0 ]]; then
                echo -e "${CYAN}→${NC} Calculating size of ${#found_files[@]} items..."
                local count=0
                for file in "${found_files[@]}"; do
                    if [[ -e "$file" ]]; then
                        local file_size
                        file_size=$(get_dir_size "$file")
                        if [[ "$file_size" =~ ^[0-9]+$ ]]; then
                            size_before=$((size_before + file_size))
                        fi
                        ((count++))
                        # Show progress every 10 items
                        if [[ $((count % 10)) -eq 0 ]]; then
                            echo -e "${CYAN}→${NC} Processed $count/${#found_files[@]} items ($(format_bytes $size_before) so far)..."
                        fi
                    fi
                done
                
                if $DRY_RUN; then
                    add_to_cleanup_log "$description" "$(format_bytes "$size_before")" "DRY_RUN"
                else
                    echo -e "${CYAN}→${NC} Deleting ${#found_files[@]} items..."
                    local removed=false
                    local del_count=0
                    for file in "${found_files[@]}"; do
                        if rm -rf "$file" 2>/dev/null; then
                            removed=true
                        fi
                        ((del_count++))
                        # Show progress every 25 deletions
                        if [[ $((del_count % 25)) -eq 0 ]]; then
                            echo -e "${CYAN}→${NC} Deleted $del_count/${#found_files[@]} items..."
                        fi
                    done
                    
                    if $removed; then
                        TOTAL_FREED=$((TOTAL_FREED + size_before))
                        FILES_REMOVED=$((FILES_REMOVED + ${#found_files[@]}))
                        add_to_cleanup_log "$description" "$(format_bytes "$size_before")" "SUCCESS"
                    else
                        add_to_cleanup_log "$description" "0 B" "FAILED"
                    fi
                fi
            else
                add_to_cleanup_log "$description" "0 B" "SKIPPED"
            fi
        else
            add_to_cleanup_log "$description" "0 B" "SKIPPED"
        fi
    else
        # Handle non-wildcard paths
        if [[ -e "$path" ]]; then
            echo -e "${CYAN}→${NC} Calculating size..."
            size_before=$(get_dir_size "$path")
            echo -e "${CYAN}→${NC} Size: $(format_bytes "$size_before")"
            
            if $DRY_RUN; then
                add_to_cleanup_log "$description" "$(format_bytes "$size_before")" "DRY_RUN"
            else
                echo -e "${CYAN}→${NC} Deleting..."
                if rm -rf "$path" 2>/dev/null; then
                    TOTAL_FREED=$((TOTAL_FREED + size_before))
                    FILES_REMOVED=$((FILES_REMOVED + 1))
                    add_to_cleanup_log "$description" "$(format_bytes "$size_before")" "SUCCESS"
                else
                    add_to_cleanup_log "$description" "0 B" "FAILED"
                fi
            fi
        else
            add_to_cleanup_log "$description" "0 B" "SKIPPED"
        fi
    fi
    echo # Add blank line for readability
}

# Usage instructions
show_help() {
    cat << EOF
Enhanced MacBook Cleanup Script v${SCRIPT_VERSION}

${PURPLE}USAGE:${NC}
    $0 [OPTIONS]

${PURPLE}OPTIONS:${NC}
    -y, --yes        Run without confirmation prompts
    -v, --verbose    Enable verbose output
    -d, --dry-run    Show what would be deleted without actually deleting
    -s, --summary    Show detailed summary at the end
    -h, --help       Show this help message
    --version        Show version information

${PURPLE}EXAMPLES:${NC}
    $0                    # Interactive cleanup with prompts
    $0 --yes              # Automatic cleanup without prompts
    $0 --dry-run          # Preview what would be cleaned
    $0 -yv                # Auto cleanup with verbose output
    $0 --yes --summary    # Auto cleanup with detailed summary

${PURPLE}CLEANUP TASKS:${NC}
    - System and user temporary files
    - Application caches (system and user)
    - Browser caches (Safari, Chrome, Firefox, Edge)
    - Trash and local snapshots
    - System logs
    - Development caches (Xcode, npm, pip)
    - Homebrew cache

${PURPLE}SAFETY FEATURES:${NC}
    - Dry run mode to preview changes
    - Size calculation and reporting
    - macOS version compatibility check
    - Safe error handling
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
        -h|--help)
            show_help
            exit 0
            ;;
        --version)
            echo "Enhanced MacBook Cleanup Script v${SCRIPT_VERSION}"
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

# Confirmation function
confirm_action() {
    if $CONFIRM; then
        echo -ne "${YELLOW}$1${NC} (y/N): "
        read -r
        [[ $REPLY =~ ^[Yy]$ ]]
    else
        return 0
    fi
}

# Cleanup functions
clean_temp() {
    log_info "Cleaning temporary files..."
    safe_delete "/tmp/*" "system temp files"
    safe_delete "/private/tmp/*" "private temp files"
    safe_delete "$HOME/Library/Caches/TemporaryItems/*" "temporary items cache"
}

clean_caches() {
    log_info "Cleaning application caches..."
    echo -e "${YELLOW}Note: This may take several minutes for large caches...${NC}"
    
    # Process user caches directory with more specific targeting
    if [[ -d "$HOME/Library/Caches" ]]; then
        echo -e "${CYAN}→${NC} Processing user cache directories..."
        local cache_count=0
        for cache_dir in "$HOME/Library/Caches"/*; do
            if [[ -d "$cache_dir" ]]; then
                local cache_name=$(basename "$cache_dir")
                echo -e "${CYAN}→${NC} Processing cache: $cache_name"
                safe_delete "$cache_dir/*" "$cache_name cache"
                ((cache_count++))
            fi
        done
        echo -e "${CYAN}→${NC} Processed $cache_count cache directories"
    fi
    
    # Browser caches (these are often the largest)
    echo -e "${CYAN}→${NC} Processing browser caches..."
    safe_delete "$HOME/Library/Caches/com.apple.Safari/*" "Safari cache"
    safe_delete "$HOME/Library/Caches/Google/Chrome/*" "Chrome cache"
    safe_delete "$HOME/Library/Caches/Firefox/*" "Firefox cache"
    safe_delete "$HOME/Library/Caches/com.microsoft.edgemac/*" "Edge cache"
}

clean_trash() {
    log_info "Emptying Trash..."
    safe_delete "$HOME/.Trash/*" "user Trash"
    
    # Remove local Time Machine snapshots
    if ! $DRY_RUN && command -v tmutil >/dev/null 2>&1; then
        local snapshot_count=0
        for snapshot in $(tmutil listlocalsnapshotdates / 2>/dev/null | tail -n +2); do
            if tmutil deletelocalsnapshots "$snapshot" >/dev/null 2>&1; then
                ((snapshot_count++))
            fi
        done
        if [[ $snapshot_count -gt 0 ]]; then
            log_verbose "Deleted $snapshot_count local snapshots"
        fi
    fi
}

clean_logs() {
    log_info "Cleaning logs..."
    safe_delete "$HOME/Library/Logs/*" "user application logs"
}

clean_development() {
    log_info "Cleaning development caches..."
    echo -e "${YELLOW}Note: Development caches can be very large...${NC}"
    
    safe_delete "$HOME/Library/Developer/Xcode/DerivedData/*" "Xcode derived data"
    safe_delete "$HOME/Library/Caches/pip/*" "Python pip cache"
    
    # npm cache
    if command -v npm >/dev/null 2>&1 && ! $DRY_RUN; then
        echo -e "${CYAN}→${NC} Cleaning npm cache..."
        npm cache clean --force >/dev/null 2>&1 || true
        log_verbose "Cleaned npm cache"
    fi
    
    # Homebrew
    if command -v brew >/dev/null 2>&1 && ! $DRY_RUN; then
        echo -e "${CYAN}→${NC} Cleaning Homebrew cache..."
        brew cleanup -s >/dev/null 2>&1 || true
        log_verbose "Cleaned Homebrew cache"
    fi
}

# Generate and display cleanup summary
show_cleanup_summary() {
    echo
    echo -e "${PURPLE}==================== CLEANUP SUMMARY ====================${NC}"
    echo -e "${BLUE}Date:${NC} $(date)"
    echo -e "${BLUE}Script Version:${NC} $SCRIPT_VERSION"
    echo
    
    local success_count=0
    local skipped_count=0
    local failed_count=0
    local dry_run_count=0
    
    if [[ ${#CLEANUP_LOG[@]} -gt 0 ]]; then
        echo -e "${BLUE}Cleanup Actions:${NC}"
        echo "Status  | Action                           | Space"
        echo "--------|----------------------------------|---------"
        
        for entry in "${CLEANUP_LOG[@]}"; do
            local status=$(echo "$entry" | cut -d'|' -f1 | xargs)
            local action=$(echo "$entry" | cut -d'|' -f2 | xargs)
            local size=$(echo "$entry" | cut -d'|' -f3 | xargs)
            
            case $status in
                "SUCCESS")
                    echo -e "${GREEN}SUCCESS${NC} | $(printf '%-32s' "$action") | $size"
                    ((success_count++))
                    ;;
                "SKIPPED")
                    echo -e "${YELLOW}SKIPPED${NC} | $(printf '%-32s' "$action") | $size"
                    ((skipped_count++))
                    ;;
                "FAILED")
                    echo -e "${RED}FAILED${NC}  | $(printf '%-32s' "$action") | $size"
                    ((failed_count++))
                    ;;
                "DRY_RUN")
                    echo -e "${BLUE}DRY_RUN${NC} | $(printf '%-32s' "$action") | $size"
                    ((dry_run_count++))
                    ;;
            esac
        done
    fi
    
    echo
    echo -e "${BLUE}Summary Statistics:${NC}"
    if $DRY_RUN; then
        echo -e "  ${BLUE}Items that would be cleaned:${NC} $dry_run_count"
        echo -e "  ${YELLOW}Items not found:${NC} $skipped_count"
        echo -e "  ${PURPLE}Total space that would be freed:${NC} $(format_bytes "$TOTAL_FREED")"
    else
        echo -e "  ${GREEN}Successfully cleaned:${NC} $success_count"
        echo -e "  ${YELLOW}Items not found:${NC} $skipped_count"
        echo -e "  ${RED}Failed to clean:${NC} $failed_count"
        echo -e "  ${PURPLE}Total space freed:${NC} $(format_bytes "$TOTAL_FREED")"
        echo -e "  ${CYAN}Files/directories removed:${NC} $FILES_REMOVED"
        
        if [[ $FILES_REMOVED -eq 0 ]]; then
            echo -e "  ${YELLOW}Result:${NC} No files were removed - system already clean!"
        fi
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - START_TIME))
    echo -e "  ${CYAN}Time elapsed:${NC} ${duration}s"
    echo -e "${PURPLE}=========================================================${NC}"
}

# Main execution function
main() {
    log_info "Starting Enhanced MacBook Cleanup v${SCRIPT_VERSION}..."
    check_macos_version
    
    if $DRY_RUN; then
        log_warning "DRY RUN MODE: No files will actually be deleted"
    fi
    
    echo
    log_info "Beginning cleanup operations..."
    echo
    
    # Run cleanup tasks
    if confirm_action "Clean temporary files?"; then
        clean_temp
    fi
    
    if confirm_action "Clean application caches?"; then
        clean_caches
    fi
    
    if confirm_action "Empty Trash and remove snapshots?"; then
        clean_trash
    fi
    
    if confirm_action "Clean logs?"; then
        clean_logs
    fi
    
    if confirm_action "Clean development caches?"; then
        clean_development
    fi
    
    # Show results
    echo
    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - START_TIME))
    
    if $SHOW_SUMMARY; then
        show_cleanup_summary
    else
        if $DRY_RUN; then
            log_success "Dry run completed - $(format_bytes "$TOTAL_FREED") would be freed"
        else
            log_success "Cleanup completed - $(format_bytes "$TOTAL_FREED") freed"
            if [[ $FILES_REMOVED -eq 0 ]]; then
                log_info "No files were removed - your system is already clean!"
            else
                log_info "$FILES_REMOVED items removed in ${duration}s"
            fi
        fi
        echo -e "${CYAN}Run with --summary for detailed breakdown${NC}"
    fi
    
    if $DRY_RUN; then
        echo
        log_info "Run without --dry-run to actually perform cleanup"
    fi
}

# Run main function
main "$@"