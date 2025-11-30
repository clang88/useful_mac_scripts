#!/bin/zsh


# Default values
cutoff="2025-11-01"
dryrun=false
use_last_local_snapshot_cutoff=false
machinedirectory="$(tmutil machinedirectory)"


# Parse keyword params
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dryrun)
            dryrun=true
            echo "[DRY RUN] No backups will be deleted."
            ;;
        --cutoff)
            shift
            if [[ -n "$1" ]]; then
                cutoff="$1"
            else
                echo "Error: --cutoff requires a date argument (YYYY-MM-DD)" >&2
                exit 1
            fi
            ;;
        --lastlocal)
            use_last_local_snapshot_cutoff=true
            use_first_local_snapshot_cutoff=false
            ;;
        --firstlocal)
            use_first_local_snapshot_cutoff=true
            use_last_local_snapshot_cutoff=false
            ;;
        --deletelocalsnapshots)
            delete_local_snapshots=true
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Default for local snapshot deletion
delete_local_snapshots=${delete_local_snapshots:-false}

# If --lastlocal or --firstlocal is set, determine the appropriate local snapshot date
if [[ "$use_last_local_snapshot_cutoff" == true ]]; then
    snapshot=$(tmutil listlocalsnapshots / | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | sort | tail -n 1)
    label="last"
elif [[ "$use_first_local_snapshot_cutoff" == true ]]; then
    snapshot=$(tmutil listlocalsnapshots / | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | sort | head -n 1)
    label="first"
fi

if [[ -n "$snapshot" && ("$use_last_local_snapshot_cutoff" == true || "$use_first_local_snapshot_cutoff" == true) ]]; then
    cutoff_date=$(echo "$snapshot" | cut -d '-' -f 1-3)
    echo "Using $label local snapshot date as cutoff: $cutoff_date"
    cutoff="$cutoff_date"
elif [[ ("$use_last_local_snapshot_cutoff" == true || "$use_first_local_snapshot_cutoff" == true) ]]; then
    echo "No local snapshots found. Cannot set cutoff from local snapshot." >&2
    exit 1
fi


# Gather local snapshots to delete (if requested)
local_snapshots_to_delete=()
if $delete_local_snapshots; then
    while read -r snap; do
        snap_date=$(echo "$snap" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        if [[ -n "$snap_date" && "$snap_date" < "$cutoff" ]]; then
            local_snapshots_to_delete+=("$snap")
        fi
    done < <(tmutil listlocalsnapshots / | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}')
fi

# Gather backups to delete
backups_to_delete=()
while read -r backup; do
    timestamp=$(basename "$backup" | sed 's/.backup//')
    bdate=$(echo "$timestamp" | cut -d '-' -f 1-3)
    mountpoint=$(echo "$backup" | sed -E 's|(.*)/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\.backup.*|\1|')
    if [[ -n "$bdate" && "$bdate" < "$cutoff" ]]; then
        backups_to_delete+=("$timestamp|$machinedirectory|$mountpoint")
    fi
done < <(tmutil listbackups -d "$machinedirectory")

# Print summary and confirm
echo "Summary of deletions:"
if $delete_local_snapshots; then
    echo "Local snapshots to delete (before $cutoff):"
    for snap in "${local_snapshots_to_delete[@]}"; do
        echo "  $snap"
    done
    [[ ${#local_snapshots_to_delete[@]} -eq 0 ]] && echo "  (none)"
fi
echo "Backups to delete (before $cutoff):"
for b in "${backups_to_delete[@]}"; do
    IFS='|' read -r timestamp machinedirectory mountpoint <<< "$b"
    echo "  $timestamp (mountpoint: $mountpoint)"
done
[[ ${#backups_to_delete[@]} -eq 0 ]] && echo "  (none)"
echo
read '?Proceed with deletion? (press Enter to continue, Ctrl+C to abort) '

# Delete local snapshots first (if requested)
if $delete_local_snapshots; then
    for snap in "${local_snapshots_to_delete[@]}"; do
        timestamp=$(echo "$snap" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}')
        if $dryrun; then
            echo "[DRY RUN] Would delete local snapshot: $snap"
            echo "[DRY RUN] Would call: tmutil deletelocalsnapshots \"$timestamp\""
        else
            echo "Deleting local snapshot: $snap"
            echo "Calling tmutil deletelocalsnapshots \"$timestamp\""
            sudo tmutil deletelocalsnapshots "$timestamp"
        fi
    done
fi

# Delete backups
for b in "${backups_to_delete[@]}"; do
    IFS='|' read -r timestamp machinedirectory mountpoint <<< "$b"
    if $dryrun; then
        echo "[DRY RUN] Would delete backup: $timestamp (mountpoint: $mountpoint)"
        echo "[DRY RUN] Would call: tmutil delete -d \"$machinedirectory\" -t \"$timestamp\""
    else
        echo "Deleting backup: $timestamp (mountpoint: $mountpoint)"
        echo "Calling: tmutil delete -d \"$machinedirectory\" -t \"$timestamp\""
        sudo tmutil delete -d "$machinedirectory" -t "$timestamp"
    fi
done
