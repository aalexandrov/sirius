-- 1. PostgreSQL credentials for the DuckLake metadata catalog
CREATE OR REPLACE SECRET hybench_postgres (
  TYPE postgres,
  HOST getenv('PGHOST'),
  PORT getenv('PGPORT'),
  DATABASE hybench,
  USER getenv('PGUSER'),
  PASSWORD getenv('PGPASSWORD')
);

-- 3. Attach the DuckLake catalog
ATTACH '' AS hybench (
  TYPE postgres,
  SECRET 'hybench_postgres',
  READ_ONLY
);
