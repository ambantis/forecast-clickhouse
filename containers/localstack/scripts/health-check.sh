#!/bin/bash

# Health check script for LocalStack S3 data loading
# This script ensures S3 is available and all data files have been uploaded

set -e

# Check if S3 service is running
if ! curl -sf http://localhost:4566/_localstack/health | grep -q 's3.*running'; then
    echo "S3 service not running"
    exit 1
fi

# Count expected files
expected_files=$(($(find /data -type f | wc -l)))

# Count actual files in S3 bucket
actual_files=$(awslocal s3 ls --recursive s3://ads-forecast-production | wc -l)

echo "Expected files: $expected_files, Actual files: $actual_files"

# Check if counts match
if [ "$actual_files" -eq "$expected_files" ]; then
    echo "✅ All $actual_files files successfully uploaded to S3"
    exit 0
else
    echo "❌ File count mismatch - data upload incomplete"
    exit 1
fi
