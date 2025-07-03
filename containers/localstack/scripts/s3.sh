#!/usr/bin/env bash

# this script runs in the localstack docker container and copies data from local disk (bind mounted) to the s3 instance

until awslocal s3 ls; do
  >&2 echo "S3 is unavailable - sleeping"
  sleep 1
done

echo "S3 is up - executing command"

awslocal s3 mb s3://ads-forecast-production
awslocal s3 cp --recursive /data s3://ads-forecast-production

echo "S3 is ready"
