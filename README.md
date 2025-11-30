# Useful Mac Scripts

This repository contains simple shell scripts for common macOS tasks.

---

## clean_timemachine.sh

Removes old Time Machine local snapshots and/or network backups to free up disk space on macOS.

### Usage

```sh
sudo ./clean_timemachine.sh [options]
```

You may need to grant execute permission first:

```sh
chmod +x clean_timemachine.sh
```

### Options

- `--dryrun`           : Show what would be deleted, but do not actually delete anything.
- `--cutoff YYYY-MM-DD`: Only delete backups/snapshots older than this date (default: 2025-11-01).
- `--lastlocal`        : Use the date of the last local snapshot as the cutoff.
- `--firstlocal`       : Use the date of the first local snapshot as the cutoff.
- `--deletelocalsnapshots`: Also delete local Time Machine snapshots (not just network backups).

It is recommended to use `--deletelocalsnapshots`if you use `--lastlocal` or `--cutoff` that is more recent than the first local snapshot.

### Example

Delete all backups and local snapshots before 2025-10-01, showing what would be deleted but not actually deleting:

```sh
sudo ./clean_timemachine.sh --dryrun --cutoff 2025-10-01 --deletelocalsnapshots
```

### How it works
- Lists all Time Machine backups and/or local snapshots.
- Compares their dates to the cutoff.
- Prompts for confirmation before deleting.
- Requires admin privileges for deletion.

---

## toggle_metal_hud.sh

Toggles the Metal HUD (Heads-Up Display) for graphics debugging on macOS.
