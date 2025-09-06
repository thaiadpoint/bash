#!/bin/bash

# DigitalOcean Volume Snapshot Creation Script
# This script creates snapshots of specified volumes and maintains only one snapshot per volume

# Array of volume IDs
VOLUME_IDS=(
    "11c395f1-8a08-11ef-8b51-0a58ac14043a"    # volume-yourqr-dr
    "c9abb11f-8520-11ed-9676-0a58ac14a40f"    # volume-fr-pr1
    "58161f06-8347-11ed-ba7b-0a58ac14a3ee"    # volume-fd-pr1
    "a64b6513-c670-11e7-9a77-0242ac115003"    # volume-dv2
    "06ab4f6f-8d06-11e7-a0e3-0242ac113009"    # pr2-vol1
)

# Function to create snapshot and delete old ones for a volume
create_and_maintain_snapshot() {
    local volume_id=$1
    echo "Processing volume: $volume_id"

    # Get volume name
    volume_name=$(doctl compute volume get $volume_id --format Name --no-header)
    
    # Create new snapshot with timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    snapshot_name="${volume_name}-snapshot-${timestamp}"
    
    echo "Creating new snapshot: $snapshot_name"
    doctl compute volume snapshot $volume_id --snapshot-name $snapshot_name
    
    if [ $? -ne 0 ]; then
        echo "Error creating snapshot for volume $volume_id"
        return 1
    fi

    # Get list of existing snapshots for this volume
    old_snapshots=$(doctl compute snapshot list --resource volume --format ID,Name --no-header | grep $volume_name)
    
    # Count snapshots (excluding the one we just created)
    snapshot_count=$(echo "$old_snapshots" | grep -v "$snapshot_name" | wc -l)
    
    if [ $snapshot_count -gt 0 ]; then
        echo "Found existing snapshots for $volume_name. Cleaning up..."
        echo "$old_snapshots" | grep -v "$snapshot_name" | while read snapshot_info; do
            snapshot_id=$(echo $snapshot_info | awk '{print $1}')
            echo "Deleting old snapshot: $snapshot_id"
            doctl compute snapshot delete $snapshot_id -f
        done
    fi
    
    echo "Snapshot management completed for volume: $volume_id"
    echo "----------------------------------------"
}

# Main script execution
echo "Starting volume snapshot creation process..."
echo "----------------------------------------"

# Check if doctl is installed and authenticated
if ! command -v doctl &> /dev/null; then
    echo "Error: doctl is not installed. Please install it first."
    exit 1
fi

# Try a simple doctl command to check authentication
if ! doctl account get &> /dev/null; then
    echo "Error: doctl is not authenticated. Please run 'doctl auth init' first."
    exit 1
fi

# Process each volume
for volume_id in "${VOLUME_IDS[@]}"; do
    create_and_maintain_snapshot "$volume_id"
done

echo "Volume snapshot process completed!"
