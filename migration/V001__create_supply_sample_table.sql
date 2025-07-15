-- Supply Samples
CREATE TABLE IF NOT EXISTS ${forecastDbName}.supply_sample_local
(
    -- ========== GROUP 1: Tree Traversal / WHERE Clause Columns ==========
    -- These columns are used by TreeLookup for dimension filtering and appear in WHERE clauses
    -- They follow the tree hierarchy levels and are part of the ORDER BY

    -- WHERE clause will always contain 'hour_of_week' (derived from request_ts)
    request_ts DateTime('UTC'),

    -- Tree hierarchy columns (Levels 1-7)
    dma UInt8,         -- Level 1: Geographic market
    is_registered Bool,                           -- Level 2: Registration state (from user_id presence)
    platform LowCardinality(String),              -- Level 3: Device platform
    device_deals Array(LowCardinality(String)),   -- Level 3: Device deals (paired with platform)
    country LowCardinality(String),               -- Level 4: Country code
    subdivision LowCardinality(Nullable(String)), -- Level 4: State/subdivision (paired with country)
    app_mode LowCardinality(String),              -- Level 5: Application mode
    is_pre_roll Bool,                             -- Level 6: Pre-roll placement indicator (1 if now_pos=0, 0 otherwise)'
    content_type LowCardinality(String),          -- Level 7: Content type

    -- ========== GROUP 2: Targeting / Matching Criteria Columns ==========
    -- These columns are used by SampleMatcher for targeting evaluation
    -- They appear in expressions like: expr1 AND expr2 AND expr3 AS is_match
    -- Will sometimes include second_of_hour

    app_id LowCardinality(String),
    timezone LowCardinality(Nullable(String)),
    content_iab_categories Array(LowCardinality(String)), -- tier1.tier2.tier3 as string
    content_id String,
    device_type LowCardinality(String),
    device_model LowCardinality(Nullable(String)),
    content_genres Array(LowCardinality(String)),
    postal_code Nullable(String),
    is_ip_v6 Bool,
    languages Array(LowCardinality(String)),
    tracking_modes Array(LowCardinality(String)),
    publisher_id LowCardinality(String),
    content_ratings Array(LowCardinality(String)),
    carrier LowCardinality(Nullable(String)),
    user_gender LowCardinality(String),
    user_age Nullable(UInt8),
    container_id Nullable(String),
    revenue_vertical LowCardinality(String),

    -- ========== GROUP 3: Metrics / Aggregation Columns ==========
    -- These columns are used for calculations and aggregations

    -- Frequency capping
    hashed_device_id Int64,  -- 64 bits for frequency calculations

    -- Metrics for aggregation
    ad_break_duration_sec Float32,
    ad_opportunity_count UInt32,
    filled_ao Float32,
    filled_duration_sec Float32,

    -- ========== Metadata ==========
    import_timestamp DateTime DEFAULT now() COMMENT 'When this record was imported',

    -- ========== Derived Columns (MATERIALIZED) ==========
    -- Computed columns for query optimization
    hour_of_week UInt8 MATERIALIZED ((toDayOfWeek(request_ts) - 1) * 24 + toHour(request_ts)) COMMENT 'Hour of week (0-167, where 0=Monday 00:00)',
    second_of_hour UInt16 MATERIALIZED (toMinute(request_ts) * 60 + toSecond(request_ts)) COMMENT 'Second within the hour (0-3599)'
)
ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{shard}/${forecastDbName}/supply_sample_local', '{replica}')
PARTITION BY tuple()  -- Single partition since entire table is replaced weekly
ORDER BY (hour_of_week, dma, platform, country, app_mode, content_type)
SETTINGS index_granularity = 8192;

-- Create distributed table for querying
CREATE TABLE IF NOT EXISTS ${forecastDbName}.supply_sample
AS ${forecastDbName}.supply_sample_local
ENGINE = Distributed('{cluster}', '${forecastDbName}', 'supply_sample_local', rand());

