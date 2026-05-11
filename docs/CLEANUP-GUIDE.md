# Claude Desktop Docker - Cleanup Guide

This guide explains how to clean up the project structure by removing redundant scripts and organizing the consolidated scripts.

## Why Clean Up?

The project currently contains both the original scripts and the new consolidated scripts, which creates unnecessary clutter. The cleanup process will:

1. **Remove redundant scripts** while preserving their functionality
2. **Organize the consolidated scripts** in the main scripts directory
3. **Update the entry point** (claude.sh) to point to the new script locations
4. **Preserve original files** by archiving them instead of deleting them

## Cleanup Steps

1. Make the cleanup script executable:
   ```bash
   chmod +x cleanup.sh
   ```

2. Run the cleanup script:
   ```bash
   ./cleanup.sh
   ```

3. After confirming that everything works correctly, you can delete the cleanup script:
   ```bash
   rm cleanup.sh
   ```

## What Gets Changed

The cleanup script will:

- Move all scripts from `scripts/consolidated/` to `scripts/`
- Archive redundant scripts in a new `archive/` directory
- Update `claude.sh` to point to the main script in the new location
- Replace the current README.md with README-CONSOLIDATED.md

## If Something Goes Wrong

If you encounter any issues after cleanup, you can:

1. Restore the original scripts from the `archive/` directory
2. Continue using the consolidated scripts from the `scripts/` directory

## After Cleanup

After cleanup, you'll continue using the same commands:

```bash
./claude.sh setup
./claude.sh build
./claude.sh start
...etc.
```

The functionality remains the same, but the project structure is cleaner and more organized.
