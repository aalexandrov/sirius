.echo off

-- Utility macros for DuckLake catalog inspection.
-- Import into the current session with `.read scripts/ducklake/duckdb_utils.sql`.

-- dl_files(schema_name, table_name)
--
-- Lists active data files for schema_name.table_name from the DuckLake catalog.
-- Uses ducklake_list_files() to retrieve the set of parquet files that make
-- up a table in S3. Simpler wrapper than memory.table_parquet_metadata().
CREATE OR REPLACE MACRO memory.dl_files(schema_name, table_name) AS TABLE
FROM
    ducklake_list_files('ducklake', table_name, schema => schema_name);

-- dl_parquet_metadata(schema_name, table_name)
--
-- Retrieves parquet_metadata() for all active data files of schema_name, table_name.
-- Yields one row per row group per column. Filters to files from
-- memory.dl_files() to exclude expired or detached data files.
CREATE OR REPLACE MACRO memory.dl_parquet_metadata(schema_name, table_name) AS TABLE
FROM
    parquet_metadata('file:/opt/dlami/nvme/alexander/ducklake/' || schema_name || '/' || table_name || '/*.parquet')
WHERE
    file_name IN (SELECT data_file FROM memory.dl_files(schema_name, table_name));

-- dl_row_groups(schema_name, table_name)
--
-- Deduplicates parquet_metadata() to one row per row group (across all columns),
-- extracting row_group_id, row_group_num_rows, row_group_bytes, and
-- row_group_compressed_bytes. Ordered by file_name and row_group_id.
CREATE OR REPLACE MACRO memory.dl_row_groups(schema_name, table_name) AS TABLE
SELECT DISTINCT
    file_name,
    row_group_id,
    row_group_num_rows as num_rows,
    row_group_bytes as bytes,
    row_group_compressed_bytes as compressed_bytes,
FROM
    memory.dl_parquet_metadata(schema_name, table_name)
ORDER BY
    file_name, row_group_id;

-- dl_row_group_stats(schema_name, table_name)
--
-- Per-file row group statistics: count of row groups, plus average and
-- quantiles (1st, 25th, 50th, 75th, 99th percentiles) of row_group_num_rows,
-- row_group_bytes, and row_group_compressed_bytes. Also computes the overall
-- compression ratio (sum of compressed / sum of uncompressed bytes) per file.
-- Ordered by file_name.
CREATE OR REPLACE MACRO memory.dl_row_group_stats(schema_name, table_name) AS TABLE
SELECT
    file_name,
    data_file_size_bytes as file_size_bytes,
    count(*) as num_groups,
    avg(num_rows) as avg_num_rows,
    avg(bytes) as avg_bytes,
    avg(compressed_bytes) as avg_cmp_bytes,
    sum(compressed_bytes) / sum(bytes) as cmp_ratio,
    approx_quantile(num_rows, [0.01, 0.25, 0.50, 0.75, 0.99]) as qnt_num_rows,
    approx_quantile(bytes, [0.01, 0.25, 0.50, 0.75, 0.99]) as qnt_bytes,
    approx_quantile(compressed_bytes, [0.01, 0.25, 0.50, 0.75, 0.99]) as qnt_compressed_bytes,
FROM
    memory.dl_row_groups(schema_name, table_name) g
    JOIN memory.dl_files(schema_name, table_name) f ON (g.file_name = f.data_file)
GROUP BY
    ALL
ORDER BY
    file_name;
