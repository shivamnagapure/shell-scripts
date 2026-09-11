#!/bin/bash

################################################################################
# VM Health Check Script
# 
# Description: Analyzes the health of a virtual machine based on CPU, memory,
#              and disk space utilization.
#
# Health Status:
#   - Healthy: All metrics (CPU, Memory, Disk) are below 60% utilization
#   - Not Healthy: Any metric exceeds 60% utilization
#
# Usage:
#   ./vm_health_check.sh                    # Basic health status
#   ./vm_health_check.sh explain            # Detailed explanation of health status
#
# Target: Ubuntu systems
#
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health thresholds
THRESHOLD=60

# Declare associative arrays to store metrics
declare -A metrics
declare -A status_array

################################################################################
# Function: get_cpu_usage
# Description: Calculates the CPU usage percentage
# Returns: CPU usage as a percentage (0-100)
################################################################################
get_cpu_usage() {
    # Get CPU usage using top command
    # This calculates average CPU usage over the last sampling period
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # If top fails, try alternative method using /proc/stat
    if [ -z "$cpu_usage" ]; then
        local cpu_idle=$(awk '/^cpu / {print $5}' /proc/stat)
        cpu_usage=$(echo "scale=2; 100 - $cpu_idle" | bc)
    fi
    
    echo "$cpu_usage"
}

################################################################################
# Function: get_memory_usage
# Description: Calculates the memory utilization percentage
# Returns: Memory usage as a percentage (0-100)
################################################################################
get_memory_usage() {
    # Parse /proc/meminfo to get memory usage
    local memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local memavailable=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    # Calculate memory used
    local memused=$((memtotal - memavailable))
    
    # Calculate percentage
    local memory_usage=$(echo "scale=2; ($memused / $memtotal) * 100" | bc)
    
    echo "$memory_usage"
}

################################################################################
# Function: get_disk_usage
# Description: Calculates the disk utilization percentage for root partition
# Returns: Disk usage as a percentage (0-100)
################################################################################
get_disk_usage() {
    # Get disk usage for root partition (/)
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    echo "$disk_usage"
}

################################################################################
# Function: get_disk_details
# Description: Provides detailed disk information for all partitions
# Returns: Detailed disk information
################################################################################
get_disk_details() {
    echo -e "${BLUE}Disk Space Details:${NC}"
    df -h | awk 'NR>1 {printf "  %-20s %10s %10s %10s %8s\n", $1, $2, $3, $4, $5}'
}

################################################################################
# Function: get_memory_details
# Description: Provides detailed memory information
# Returns: Detailed memory information
################################################################################
get_memory_details() {
    echo -e "${BLUE}Memory Details:${NC}"
    free -h | awk 'NR==2 {printf "  Total: %s | Used: %s | Available: %s\n", $2, $3, $7}'
}

################################################################################
# Function: get_cpu_details
# Description: Provides detailed CPU information
# Returns: Detailed CPU information
################################################################################
get_cpu_details() {
    echo -e "${BLUE}CPU Details:${NC}"
    local cpu_count=$(nproc)
    printf "  CPU Cores: %d\n" "$cpu_count"
    
    # Get load average
    local loadavg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    printf "  Load Average (1min, 5min, 15min): %s\n" "$loadavg"
}

################################################################################
# Function: determine_health_status
# Description: Determines overall VM health based on metrics
# Returns: Sets HEALTH_STATUS and populates status_array
################################################################################
determine_health_status() {
    local health_status="HEALTHY"
    local unhealthy_components=()
    
    # Check CPU
    if (( $(echo "${metrics[cpu]} > $THRESHOLD" | bc -l) )); then
        health_status="NOT HEALTHY"
        unhealthy_components+=("CPU")
        status_array[cpu]="⚠️  NOT HEALTHY"
    else
        status_array[cpu]="✓ HEALTHY"
    fi
    
    # Check Memory
    if (( $(echo "${metrics[memory]} > $THRESHOLD" | bc -l) )); then
        health_status="NOT HEALTHY"
        unhealthy_components+=("Memory")
        status_array[memory]="⚠️  NOT HEALTHY"
    else
        status_array[memory]="✓ HEALTHY"
    fi
    
    # Check Disk
    if (( $(echo "${metrics[disk]} > $THRESHOLD" | bc -l) )); then
        health_status="NOT HEALTHY"
        unhealthy_components+=("Disk Space")
        status_array[disk]="⚠️  NOT HEALTHY"
    else
        status_array[disk]="✓ HEALTHY"
    fi
    
    HEALTH_STATUS=$health_status
    UNHEALTHY_COMPONENTS=("${unhealthy_components[@]}")
}

################################################################################
# Function: print_basic_status
# Description: Prints basic health status without explanations
################################################################################
print_basic_status() {
    if [ "$HEALTH_STATUS" = "HEALTHY" ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}VM Health Status: $HEALTH_STATUS${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}VM Health Status: $HEALTH_STATUS${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

################################################################################
# Function: print_detailed_status
# Description: Prints detailed health status with explanations
################################################################################
print_detailed_status() {
    # Print header
    if [ "$HEALTH_STATUS" = "HEALTHY" ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}VM Health Status: $HEALTH_STATUS${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}VM Health Status: $HEALTH_STATUS${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Resource Utilization Summary:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  CPU Usage:    %.2f%% %s (Threshold: %d%%)\n" "${metrics[cpu]}" "${status_array[cpu]}" "$THRESHOLD"
    printf "  Memory Usage: %.2f%% %s (Threshold: %d%%)\n" "${metrics[memory]}" "${status_array[memory]}" "$THRESHOLD"
    printf "  Disk Usage:   %.2f%% %s (Threshold: %d%%)\n" "${metrics[disk]}" "${status_array[disk]}" "$THRESHOLD"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    
    # Print detailed information
    get_cpu_details
    echo ""
    get_memory_details
    echo ""
    get_disk_details
    
    # Print explanation
    echo ""
    echo -e "${YELLOW}Analysis & Explanation:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$HEALTH_STATUS" = "HEALTHY" ]; then
        echo -e "${GREEN}✓ The VM is operating in optimal condition.${NC}"
        echo "  All system resources are within acceptable limits (<60% utilization)."
    else
        echo -e "${RED}✗ The VM requires attention.${NC}"
        echo "  The following components exceed the 60% utilization threshold:"
        echo ""
        
        for component in "${UNHEALTHY_COMPONENTS[@]}"; do
            case "$component" in
                "CPU")
                    printf "  ${RED}• CPU Usage: %.2f%%${NC} - The processor is under high load.\n" "${metrics[cpu]}"
                    echo "    Action: Check running processes, consider load balancing or scaling."
                    ;;
                "Memory")
                    printf "  ${RED}• Memory Usage: %.2f%%${NC} - RAM is heavily consumed.\n" "${metrics[memory]}"
                    echo "    Action: Review running applications, increase RAM, or optimize memory usage."
                    ;;
                "Disk Space")
                    printf "  ${RED}• Disk Usage: %.2f%%${NC} - Storage is running low.\n" "${metrics[disk]}"
                    echo "    Action: Clean up temporary files, archive old logs, or expand storage."
                    ;;
            esac
            echo ""
        done
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

################################################################################
# Function: print_usage
# Description: Prints script usage information
################################################################################
print_usage() {
    cat << EOF
${BLUE}VM Health Check Script${NC}

${YELLOW}Usage:${NC}
    $0 [OPTION]

${YELLOW}Options:${NC}
    (none)          Display basic VM health status
    explain         Display detailed health status with explanations
    help            Show this help message

${YELLOW}Examples:${NC}
    $0                  # Basic health check
    $0 explain          # Detailed health check
    $0 help             # Show this message

${YELLOW}Health Criteria:${NC}
    - HEALTHY:     All metrics < 60% utilization
    - NOT HEALTHY: Any metric >= 60% utilization

${YELLOW}Metrics Analyzed:${NC}
    1. CPU Usage
    2. Memory Utilization
    3. Disk Space Usage

${BLUE}Target OS: Ubuntu${NC}

EOF
}

################################################################################
# Main Script Logic
################################################################################
main() {
    # Parse command line arguments
    local explain_flag=false
    
    if [ $# -gt 0 ]; then
        case "$1" in
            explain)
                explain_flag=true
                ;;
            help|-h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    fi
    
    # Collect metrics
    echo "Analyzing VM health..." >&2
    metrics[cpu]=$(get_cpu_usage)
    metrics[memory]=$(get_memory_usage)
    metrics[disk]=$(get_disk_usage)
    
    # Determine health status
    determine_health_status
    
    # Print results
    if [ "$explain_flag" = true ]; then
        print_detailed_status
    else
        print_basic_status
    fi
    
    # Set exit code based on health status
    if [ "$HEALTH_STATUS" = "HEALTHY" ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
