CALL ducklake_expire_snapshots('ducklake', older_than => now() - INTERVAL '1 minute');
CALL ducklake_cleanup_old_files('ducklake', cleanup_all => true);