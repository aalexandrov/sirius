CALL ducklake.set_option('target_file_size', '256 MiB');
CALL ducklake.set_option('data_inlining_row_limit', '1000');
CALL ducklake.set_option('parquet_row_group_size_bytes', '64 MiB');
CALL ducklake.set_option('parquet_row_group_size', '1000000000');
SET preserve_insertion_order=true;