# DigitalOcean Volume Snapshot Creation Script
# This script creates snapshots of specified volumes and maintains only one snapshot per volume

# Array of volume IDs
$VOLUME_IDS = @(
    "11c395f1-8a08-11ef-8b51-0a58ac14043a",    # volume-yourqr-dr
    "c9abb11f-8520-11ed-9676-0a58ac14a40f",    # volume-fr-pr1
    "58161f06-8347-11ed-ba7b-0a58ac14a3ee",    # volume-fd-pr1
    "a64b6513-c670-11e7-9a77-0242ac115003",    # volume-dv2
    "06ab4f6f-8d06-11e7-a0e3-0242ac113009"     # pr2-vol1
)

# Function to create snapshot and delete old ones for a volume
function Create-AndMaintainSnapshot {
    param(
        [string]$volumeId
    )
    Write-Host "Processing volume: $volumeId" -ForegroundColor Cyan

    # Get volume name
    $volumeName = & "$env:USERPROFILE\doctl\doctl.exe" compute volume get $volumeId --format Name --no-header
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Could not get volume name for $volumeId" -ForegroundColor Red
        return
    }

    # Create new snapshot with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshotName = "${volumeName}-snapshot-${timestamp}"
    
    Write-Host "Creating new snapshot: $snapshotName" -ForegroundColor Yellow
    & "$env:USERPROFILE\doctl\doctl.exe" compute volume snapshot $volumeId --snapshot-name $snapshotName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error creating snapshot for volume $volumeId" -ForegroundColor Red
        return
    }

    # Get list of existing snapshots for this volume
    $oldSnapshots = & "$env:USERPROFILE\doctl\doctl.exe" compute snapshot list --resource volume --format ID,Name --no-header | Where-Object { $_ -match $volumeName }
    
    # Process old snapshots
    if ($oldSnapshots) {
        Write-Host "Found existing snapshots for $volumeName. Cleaning up..." -ForegroundColor Yellow
        $oldSnapshots | Where-Object { $_ -notmatch $snapshotName } | ForEach-Object {
            $snapshotId = ($_ -split '\s+')[0]
            Write-Host "Deleting old snapshot: $snapshotId" -ForegroundColor Yellow
            & "$env:USERPROFILE\doctl\doctl.exe" compute snapshot delete $snapshotId -f
        }
    }
    
    Write-Host "Snapshot management completed for volume: $volumeId" -ForegroundColor Green
    Write-Host "----------------------------------------"
}

# Main script execution
Write-Host "Starting volume snapshot creation process..." -ForegroundColor Green
Write-Host "----------------------------------------"

# Check if doctl is accessible
if (-not (Test-Path "$env:USERPROFILE\doctl\doctl.exe")) {
    Write-Host "Error: doctl is not found in the expected location." -ForegroundColor Red
    exit 1
}

# Try a simple doctl command to check authentication
$authCheck = & "$env:USERPROFILE\doctl\doctl.exe" account get 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: doctl is not authenticated. Please run 'doctl auth init' first." -ForegroundColor Red
    exit 1
}

# Process each volume
foreach ($volumeId in $VOLUME_IDS) {
    Create-AndMaintainSnapshot -volumeId $volumeId
}

Write-Host "Volume snapshot process completed!" -ForegroundColor Green
