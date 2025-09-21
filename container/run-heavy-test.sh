#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME="quay.io/masales/mqttloader:0.8.6"
BROKER_IP="192.168.122.49"
USERNAME="amq-broker"
PASSWORD="amq-broker"
TOPIC="heavy-load-test"

SUBSCRIBERS=("sub-01" "sub-02" "sub-03")
PUBLISHERS=("pub-01" "pub-02" "pub-03")

clean_directories() {
    echo "🧹 Cleaning existing directories to prevent contamination..."
    
    if [ -d "./heavy-test-results" ] || [ -d "./heavy-test-logs" ]; then
        echo "  Removing existing test data..."
        rm -rf "./heavy-test-results" "./heavy-test-logs"
        echo "  ✓ Previous test data cleaned"
    else
        echo "  ✓ No previous test data found"
    fi
}

create_directories() {
    echo "📁 Creating fresh volume directories..."
    
    for sub in "${SUBSCRIBERS[@]}"; do
        mkdir -p "./heavy-test-results/$sub"
        mkdir -p "./heavy-test-logs/$sub"
        echo "  ✓ Created directories for $sub"
    done
    
    for pub in "${PUBLISHERS[@]}"; do
        mkdir -p "./heavy-test-results/$pub"
        mkdir -p "./heavy-test-logs/$pub"
        echo "  ✓ Created directories for $pub"
    done
}

start_subscriber() {
    local sub_id="$1"
    local container_name="mqttloader-$sub_id"
    
    echo "Starting subscriber: $container_name"
    
    podman run --rm -d \
        --name "$container_name" \
        --cpus="4.0" \
        --memory="4g" \
        -v "./heavy-test-results/$sub_id:/app/output:Z" \
        -v "./heavy-test-logs/$sub_id:/app/logs:Z" \
        --security-opt seccomp=unconfined \
        --security-opt apparmor=unconfined \
        -e JAVA_OPTS="-Xmx3g" \
        -e MQTT_BROKER="$BROKER_IP" \
        -e MQTT_USER_NAME="$USERNAME" \
        -e MQTT_PASSWORD="$PASSWORD" \
        -e MQTT_NUM_PUBLISHERS=0 \
        -e MQTT_NUM_SUBSCRIBERS=100 \
        -e MQTT_QOS_SUBSCRIBER=1 \
        -e MQTT_SUBSCRIBER_TIMEOUT=120 \
        -e MQTT_EXEC_TIME=350 \
        -e MQTT_TOPIC="$TOPIC" \
        -e MQTT_OUTPUT=/app/output \
        "$IMAGE_NAME"
    
    echo "  ✓ $container_name started"
}

start_publisher() {
    local pub_id="$1"
    local container_name="mqttloader-$pub_id"
    
    echo "Starting publisher: $container_name"
    
    podman run --rm -d \
        --name "$container_name" \
        --cpus="6.0" \
        --memory="4g" \
        -v "./heavy-test-results/$pub_id:/app/output:Z" \
        -v "./heavy-test-logs/$pub_id:/app/logs:Z" \
        --security-opt seccomp=unconfined \
        --security-opt apparmor=unconfined \
        -e JAVA_OPTS="-Xmx3g" \
        -e MQTT_BROKER="$BROKER_IP" \
        -e MQTT_USER_NAME="$USERNAME" \
        -e MQTT_PASSWORD="$PASSWORD" \
        -e MQTT_NUM_PUBLISHERS=100 \
        -e MQTT_NUM_SUBSCRIBERS=0 \
        -e MQTT_NUM_MESSAGES=100000 \
        -e MQTT_PAYLOAD=1024 \
        -e MQTT_INTERVAL=1000 \
        -e MQTT_QOS_PUBLISHER=1 \
        -e MQTT_EXEC_TIME=300 \
        -e MQTT_TOPIC="$TOPIC" \
        -e MQTT_OUTPUT=/app/output \
        "$IMAGE_NAME"
    
    echo "  ✓ $container_name started"
}

start_all() {
    echo "🚀 Starting heavy load test with 6 containers (3 subs + 3 pubs)"
    echo "=================================================="
    
    clean_directories
    create_directories
    
    echo
    echo "📥 Starting subscribers first..."
    for sub in "${SUBSCRIBERS[@]}"; do
        start_subscriber "$sub"
        sleep 2
    done
    
    echo
    echo "⏳ Waiting 30 seconds for subscribers to be ready..."
    sleep 30
    
    echo
    echo "📤 Starting publishers..."
    for pub in "${PUBLISHERS[@]}"; do
        start_publisher "$pub"
        sleep 2
    done
    
    echo
    echo "✅ All containers started!"
    echo "   Subscribers: ${SUBSCRIBERS[*]}"
    echo "   Publishers:  ${PUBLISHERS[*]}"
    echo
    echo "📊 Use 'monitor' command to watch progress"
    echo "🛑 Use 'stop' command to stop all containers"
}

monitor_containers() {
    echo "📊 Container Status:"
    echo "==================="
    
    echo
    echo "Subscribers:"
    for sub in "${SUBSCRIBERS[@]}"; do
        local name="mqttloader-$sub"
        local status=$(podman ps --format "{{.Status}}" --filter name="$name" 2>/dev/null || echo "Not running")
        echo "  $name: $status"
    done
    
    echo
    echo "Publishers:"
    for pub in "${PUBLISHERS[@]}"; do
        local name="mqttloader-$pub"
        local status=$(podman ps --format "{{.Status}}" --filter name="$name" 2>/dev/null || echo "Not running")
        echo "  $name: $status"
    done
    
    echo
    echo "📈 Resource Usage:"
    podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(for container in "${SUBSCRIBERS[@]}" "${PUBLISHERS[@]}"; do echo "mqttloader-$container"; done) 2>/dev/null || echo "  No containers running"
}

show_logs() {
    local container="$1"
    if [ -z "$container" ]; then
        echo "Available containers:"
        for sub in "${SUBSCRIBERS[@]}"; do echo "  mqttloader-$sub"; done
        for pub in "${PUBLISHERS[@]}"; do echo "  mqttloader-$pub"; done
        return 1
    fi
    
    echo "📋 Logs for $container:"
    echo "======================"
    podman logs "$container"
}

stop_all() {
    echo "🛑 Stopping all containers..."
    
    local stopped=0
    for container in "${SUBSCRIBERS[@]}" "${PUBLISHERS[@]}"; do
        local name="mqttloader-$container"
        if podman ps --filter name="$name" --format "{{.Names}}" | grep -q "$name"; then
            echo "  Stopping $name..."
            podman stop "$name" >/dev/null 2>&1 || true
            stopped=$((stopped + 1))
        fi
    done
    
    echo "✅ Stopped $stopped containers"
}

cleanup_volumes() {
    echo "🧹 Cleaning up volume directories..."
    
    read -p "This will delete all test results and logs. Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "./heavy-test-results" "./heavy-test-logs"
        echo "✅ Volume directories cleaned up"
    else
        echo "❌ Cleanup cancelled"
    fi
}

force_cleanup() {
    echo "🧹 Force cleaning all test data..."
    rm -rf "./heavy-test-results" "./heavy-test-logs"
    echo "✅ All test data forcefully removed"
}

analyze_csv_file() {
    local file="$1"
    local type="$2"  # "pub" or "sub"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return 1
    fi
    
    echo "Analyzing: $(basename $file)"
    
    # Count actual message records (S for sent, R for received)
    if [ "$type" = "sub" ]; then
        local total_records=$(grep ",R," "$file" | wc -l)
        echo "  Messages received: $total_records"
    else
        local total_records=$(grep ",S," "$file" | wc -l)
        echo "  Messages sent: $total_records"
    fi
    echo "  Records: $total_records"
    
    if [ "$type" = "sub" ]; then
        # For subscribers: analyze latency
        local avg_latency=$(tail -n +2 "$file" | awk -F, '$4 != "" {sum += $4; count++} END {if (count > 0) printf "%.2f", sum/count; else print "0"}')
        local min_latency=$(tail -n +2 "$file" | awk -F, '$4 != "" {if (min == "" || $4 < min) min = $4} END {print min+0}')
        local max_latency=$(tail -n +2 "$file" | awk -F, '$4 != "" {if (max == "" || $4 > max) max = $4} END {print max+0}')
        
        echo "  Avg Latency: ${avg_latency}μs ($(echo "scale=2; $avg_latency/1000" | bc -l 2>/dev/null || echo "N/A")ms)"
        echo "  Min Latency: ${min_latency}μs"
        echo "  Max Latency: ${max_latency}μs"
    fi
    
    # Time span analysis
    local start_time=$(head -2 "$file" | tail -1 | cut -d, -f1)
    local end_time=$(tail -1 "$file" | cut -d, -f1)
    local duration_us=$((end_time - start_time))
    local duration_s=$(echo "scale=2; $duration_us/1000000" | bc -l 2>/dev/null || echo "N/A")
    
    echo "  Duration: ${duration_s}s"
    
    if [ "$total_records" -gt 0 ] && [ "$duration_s" != "N/A" ] && [ "$duration_s" != "0" ]; then
        local rate=$(echo "scale=2; $total_records/$duration_s" | bc -l 2>/dev/null || echo "N/A")
        echo "  Rate: ${rate} messages/sec"
    fi
    
    echo
}

show_detailed_analysis() {
    echo "📊 Detailed Test Analysis:"
    echo "========================="
    
    # Detect if we're in project root or container directory
    local results_dir
    if [ -d "./heavy-test-results" ]; then
        results_dir="./heavy-test-results"
    elif [ -d "./container/heavy-test-results" ]; then
        results_dir="./container/heavy-test-results"
    else
        echo "❌ No test results found. Run 'start' command first."
        return 1
    fi
    
    echo
    echo "📥 SUBSCRIBERS ANALYSIS:"
    echo "------------------------"
    local total_received=0
    local total_avg_latency=0
    local sub_count=0
    
    for sub in "${SUBSCRIBERS[@]}"; do
        local csv_file=$(find "$results_dir/$sub" -name "*.csv" | head -1)
        if [ -n "$csv_file" ]; then
            analyze_csv_file "$csv_file" "sub"
            local records=$(grep ",R," "$csv_file" | wc -l)
            total_received=$((total_received + records))
            sub_count=$((sub_count + 1))
        else
            echo "❌ No CSV found for $sub"
        fi
    done
    
    echo
    echo "📤 PUBLISHERS ANALYSIS:"
    echo "----------------------"
    local total_sent=0
    local pub_count=0
    
    for pub in "${PUBLISHERS[@]}"; do
        local csv_file=$(find "$results_dir/$pub" -name "*.csv" | head -1)
        if [ -n "$csv_file" ]; then
            analyze_csv_file "$csv_file" "pub"
            local records=$(grep ",S," "$csv_file" | wc -l)
            total_sent=$((total_sent + records))
            pub_count=$((pub_count + 1))
        else
            echo "❌ No CSV found for $pub"
        fi
    done
    
    echo
    echo "🎯 CONSOLIDATED SUMMARY:"
    echo "========================"
    echo "Total Messages Sent: $total_sent"
    echo "Total Messages Received: $total_received"
    
    # Calculate expected vs actual
    local expected_sent=$((pub_count * 300 * 100000))  # 3 containers × 100 pubs × 100k msgs
    local expected_received=$((total_sent * sub_count * 100))  # sent × 3 containers × 100 subs
    
    echo
    echo "📈 ANALYSIS:"
    echo "Expected messages to send: $expected_sent"
    echo "Actually sent: $total_sent ($(echo "scale=2; $total_sent*100/$expected_sent" | bc -l 2>/dev/null || echo "N/A")%)"
    
    if [ "$total_sent" -gt 0 ]; then
        echo "Expected to receive: ~$(echo "$total_sent * 300" | bc) (each msg × 300 subscribers)"
        local delivery_ratio=$(echo "scale=2; $total_received/$total_sent" | bc -l 2>/dev/null || echo "N/A")
        echo "Actual delivery ratio: ${delivery_ratio}x (each sent msg received ${delivery_ratio} times)"
        
        if (( $(echo "$delivery_ratio > 350" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  WARNING: Very high delivery ratio suggests possible duplication or timing issues"
        fi
    fi
    
    echo
    echo "🔍 TEST STATUS:"
    if [ "$total_sent" -lt $((expected_sent / 10)) ]; then
        echo "⚠️  Publishers stopped prematurely (sent <10% of expected)"
    fi
    
    echo "Publisher containers: $pub_count"
    echo "Subscriber containers: $sub_count"
    
    # File sizes
    echo
    echo "📁 Data Sizes:"
    local total_size=$(du -sh "$results_dir" 2>/dev/null | cut -f1)
    echo "Total Results: $total_size"
    
    # Also detect logs directory
    local logs_dir
    if [ -d "./heavy-test-logs" ]; then
        logs_dir="./heavy-test-logs"
    elif [ -d "./container/heavy-test-logs" ]; then
        logs_dir="./container/heavy-test-logs"
    fi
    
    if [ -n "$logs_dir" ]; then
        local log_size=$(du -sh "$logs_dir" 2>/dev/null | cut -f1)
        echo "Total Logs: $log_size"
    else
        echo "Total Logs: Not found"
    fi
}

export_summary_report() {
    local report_file="heavy-test-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "📋 Generating consolidated report..."
    
    {
        echo "MQTTLoader Heavy Test Summary Report"
        echo "===================================="
        echo "Generated: $(date)"
        echo "Test Configuration: 3 Publishers + 3 Subscribers"
        echo ""
        
        show_detailed_analysis
        
        echo ""
        echo "📂 Individual File Details:"
        echo "============================"
        
        # Detect results directory
        local results_dir
        if [ -d "./heavy-test-results" ]; then
            results_dir="./heavy-test-results"
        elif [ -d "./container/heavy-test-results" ]; then
            results_dir="./container/heavy-test-results"
        fi
        
        if [ -n "$results_dir" ]; then
            find "$results_dir" -name "*.csv" | while read csv; do
                echo "File: $csv"
                echo "Size: $(du -h "$csv" | cut -f1)"
                echo "Records: $(wc -l < "$csv")"
                echo ""
            done
        else
            echo "No CSV files found"
        fi
        
    } > "$report_file"
    
    echo "✅ Report saved to: $report_file"
    echo "📖 View with: cat $report_file"
}

show_results() {
    echo "📊 Test Results Summary:"
    echo "======================="
    
    # Detect directories
    local results_dir logs_dir
    if [ -d "./heavy-test-results" ]; then
        results_dir="./heavy-test-results"
        logs_dir="./heavy-test-logs"
    elif [ -d "./container/heavy-test-results" ]; then
        results_dir="./container/heavy-test-results"
        logs_dir="./container/heavy-test-logs"
    fi
    
    echo
    echo "Results files:"
    if [ -n "$results_dir" ] && [ -d "$results_dir" ]; then
        find "$results_dir" -name "*.csv" 2>/dev/null | head -20 || echo "  No CSV files found"
    else
        echo "  No results directory found"
    fi
    
    echo
    echo "Log files:"
    if [ -n "$logs_dir" ] && [ -d "$logs_dir" ]; then
        find "$logs_dir" -name "*.log*" 2>/dev/null | head -20 || echo "  No log files found"
    else
        echo "  No logs directory found"
    fi
    
    echo
    echo "Directory sizes:"
    if [ -n "$results_dir" ] && [ -d "$results_dir" ]; then
        du -sh "$results_dir/"* 2>/dev/null || echo "  No results directories"
    fi
    if [ -n "$logs_dir" ] && [ -d "$logs_dir" ]; then
        du -sh "$logs_dir/"* 2>/dev/null || echo "  No log directories"
    fi
    
    echo
    echo "💡 For detailed analysis, use:"
    echo "   $0 analyze    - Show detailed metrics"
    echo "   $0 report     - Generate summary report file"
}

show_usage() {
    echo "MQTTLoader Heavy Load Test Manager"
    echo "================================="
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  start       - Clean directories and start all containers (3 subs + 3 pubs)"
    echo "  stop        - Stop all running containers"
    echo "  monitor     - Show container status and resource usage"
    echo "  logs <id>   - Show logs for specific container (e.g., logs mqttloader-sub-01)"
    echo "  results     - Show basic test results summary"
    echo "  analyze     - Show detailed analysis with metrics and latency"
    echo "  report      - Generate consolidated summary report file"
    echo "  cleanup     - Remove all volume directories (with confirmation)"
    echo "  force-clean - Force remove all test data (no confirmation)"
    echo
    echo "Configuration:"
    echo "  Broker: $BROKER_IP"
    echo "  Topic:  $TOPIC"
    echo "  Image:  $IMAGE_NAME"
    echo
    echo "Test parameters per container:"
    echo "  Subscribers: 100 clients × 3 containers = 300 total"
    echo "  Publishers:  100 clients × 3 containers = 300 total"
    echo "  Messages:    100k per publisher × 300 = 30M total messages"
    echo "  Payload:     1KB per message = ~30GB total data"
    echo "  Duration:    ~5 minutes"
}

case "${1:-}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    monitor)
        monitor_containers
        ;;
    logs)
        show_logs "$2"
        ;;
    results)
        show_results
        ;;
    analyze)
        show_detailed_analysis
        ;;
    report)
        export_summary_report
        ;;
    cleanup)
        cleanup_volumes
        ;;
    force-clean)
        force_cleanup
        ;;
    *)
        show_usage
        ;;
esac
