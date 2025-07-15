-- Tree Forecasts
CREATE TABLE IF NOT EXISTS ${forecastDbName}.tree_forecast_next_local
(
    ts DateTime('UTC'),
    dimension_id UInt16,
    value Float64,
    upper_bound Float64,
    lower_bound Float64
)
ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{shard}/${forecastDbName}/tree_forecast_local_next', '{replica}')
PARTITION BY tuple()
ORDER BY (ts, dimension_id)
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS ${forecastDbName}.tree_forecast_next
AS ${forecastDbName}.tree_forecast_next_local
ENGINE = Distributed('{cluster}', '${forecastDbName}', 'tree_forecast_next_local', rand());
