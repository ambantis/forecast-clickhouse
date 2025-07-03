-- Create forecast database/namespace if not exists
CREATE DATABASE IF NOT EXISTS ${forecastDbName} ON CLUSTER '{cluster}' ENGINE = Atomic;
