#!/bin/bash
# Logging utility for Docker Hub multi-architecture builds

# Default log file
LOG_DIR="$(dirname "$0")/logs"
LOG_FILE="${LOG_DIR}/dockerhub-build-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Default log level
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Set log level from environment variable if provided
if [[ -n "${DOCKERHUB_LOG_LEVEL}" ]]; then
    case "${DOCKERHUB_LOG_LEVEL}" in
        "DEBUG") CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG} ;;
        "INFO") CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO} ;;
        "WARN") CURRENT_LOG_LEVEL=${LOG_LEVEL_WARN} ;;
        "ERROR") CURRENT_LOG_LEVEL=${LOG_LEVEL_ERROR} ;;
        "FATAL") CURRENT_LOG_LEVEL=${LOG_LEVEL_FATAL} ;;
        *) echo "Invalid log level: ${DOCKERHUB_LOG_LEVEL}. Using INFO." ;;
    esac
fi

# Log a message with timestamp and level
# Usage: log_message <level> <message>
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_name=""
    
    case $level in
        ${LOG_LEVEL_DEBUG}) level_name="DEBUG" ;;
        ${LOG_LEVEL_INFO}) level_name="INFO" ;;
        ${LOG_LEVEL_WARN}) level_name="WARN" ;;
        ${LOG_LEVEL_ERROR}) level_name="ERROR" ;;
        ${LOG_LEVEL_FATAL}) level_name="FATAL" ;;
        *) level_name="UNKNOWN" ;;
    esac
    
    # Only log if the current level is less than or equal to the message level
    if [[ $level -ge $CURRENT_LOG_LEVEL ]]; then
        # Format the log message
        local formatted_message="[${timestamp}] [${level_name}] ${message}"
        
        # Write to log file
        echo "${formatted_message}" >> "${LOG_FILE}"
        
        # Also print to console with color
        if [[ $level -eq ${LOG_LEVEL_DEBUG} ]]; then
            echo -e "\033[36m${formatted_message}\033[0m"  # Cyan for DEBUG
        elif [[ $level -eq ${LOG_LEVEL_INFO} ]]; then
            echo -e "\033[32m${formatted_message}\033[0m"  # Green for INFO
        elif [[ $level -eq ${LOG_LEVEL_WARN} ]]; then
            echo -e "\033[33m${formatted_message}\033[0m"  # Yellow for WARN
        elif [[ $level -eq ${LOG_LEVEL_ERROR} ]]; then
            echo -e "\033[31m${formatted_message}\033[0m"  # Red for ERROR
        elif [[ $level -eq ${LOG_LEVEL_FATAL} ]]; then
            echo -e "\033[1;31m${formatted_message}\033[0m"  # Bold Red for FATAL
        else
            echo "${formatted_message}"
        fi
    fi
}

# Convenience functions for different log levels
log_debug() {
    log_message ${LOG_LEVEL_DEBUG} "$1"
}

log_info() {
    log_message ${LOG_LEVEL_INFO} "$1"
}

log_warn() {
    log_message ${LOG_LEVEL_WARN} "$1"
}

log_error() {
    log_message ${LOG_LEVEL_ERROR} "$1"
}

log_fatal() {
    log_message ${LOG_LEVEL_FATAL} "$1"
}

# Log command execution with output capture
# Usage: log_exec <command>
log_exec() {
    local command="$1"
    local output
    local exit_code
    
    log_debug "Executing: ${command}"
    
    # Execute the command and capture both output and exit code
    output=$(eval "${command}" 2>&1)
    exit_code=$?
    
    # Log the output
    if [[ -n "${output}" ]]; then
        log_debug "Command output:\n${output}"
    fi
    
    # Log success or failure
    if [[ ${exit_code} -eq 0 ]]; then
        log_info "Command succeeded: ${command}"
    else
        log_error "Command failed (exit code ${exit_code}): ${command}"
        log_error "Output: ${output}"
    fi
    
    # Return the original exit code
    return ${exit_code}
}

# Function to log system information
log_system_info() {
    log_info "=== System Information ==="
    log_info "Hostname: $(hostname)"
    log_info "Kernel: $(uname -r)"
    log_info "Architecture: $(uname -m)"
    log_info "CPU: $(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')"
    log_info "Memory: $(free -h | grep Mem | awk '{print $2}')"
    log_info "Disk space: $(df -h / | tail -n1 | awk '{print $4}') available"
    
    # Docker information
    if command -v docker &> /dev/null; then
        log_info "Docker version: $(docker --version)"
        log_info "Docker Buildx version: $(docker buildx version 2>/dev/null || echo 'Not installed')"
    else
        log_warn "Docker not found"
    fi
    
    # Log environment variables
    log_debug "=== Environment Variables ==="
    log_debug "$(env | sort)"
}

# Function to log build start with banner
log_build_start() {
    local version="$1"
    local platforms="$2"
    
    log_info "=============================================="
    log_info "   CLAUDE DESKTOP DOCKER HUB BUILD STARTED   "
    log_info "=============================================="
    log_info "Version: ${version}"
    log_info "Platforms: ${platforms}"
    log_info "Build started at: $(date)"
    log_info "Log file: ${LOG_FILE}"
    log_info "=============================================="
    
    log_system_info
}

# Function to log build completion with summary
log_build_completion() {
    local status="$1"  # "success" or "failure"
    local duration="$2"
    local error_message="$3"  # Optional, only for failures
    
    log_info "=============================================="
    log_info "   CLAUDE DESKTOP DOCKER HUB BUILD FINISHED  "
    log_info "=============================================="
    log_info "Status: ${status}"
    log_info "Duration: ${duration}"
    
    if [[ "${status}" == "failure" && -n "${error_message}" ]]; then
        log_error "Error: ${error_message}"
    fi
    
    log_info "Build completed at: $(date)"
    log_info "Log file: ${LOG_FILE}"
    log_info "=============================================="
}

# Export functions
export -f log_message
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_exec
export -f log_system_info
export -f log_build_start
export -f log_build_completion
export LOG_FILE
