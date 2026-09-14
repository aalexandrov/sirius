-- 1. PostgreSQL credentials for the DuckLake metadata catalog
CREATE OR REPLACE SECRET ducklake_metadata (
  TYPE postgres,
  HOST getenv('PGHOST'),
  PORT getenv('PGPORT'),
  DATABASE ducklake,
  USER getenv('PGUSER'),
  PASSWORD getenv('PGPASSWORD')
);

-- 2. Configure DuckLake with local filesystem storage
CREATE OR REPLACE SECRET ducklake (
  TYPE ducklake,
  METADATA_PATH '',
  DATA_PATH '/opt/dlami/nvme/alexander/ducklake/',
  METADATA_SCHEMA 'ducklake',
  METADATA_PARAMETERS MAP {
    'TYPE': 'postgres',
    'SECRET': 'ducklake_metadata'
  }
);

-- 3. Attach the DuckLake catalog
ATTACH 'ducklake:ducklake' AS ducklake (
  OVERRIDE_DATA_PATH true
);
