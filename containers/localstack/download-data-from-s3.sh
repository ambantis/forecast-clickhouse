#!/bin/bash

# This script downloads data from S3 to local disk. This data is then bind mounted into the localstack docker container.
# It automatically handles directory renaming, date detection, and downloads 7 days of sample data.

set -e  # Exit on error

cd "$(dirname "$0")"

# Configuration
REQUIRED_AWS_PROFILE="main-rainmaker-admin"
S3_BUCKET="ads-forecast-production"
DATA_DIR="data"
SAMPLES_PATH="samples/data-v0-tree-v1"

echo "🚀 Starting S3 data download process..."

# Check AWS profile configuration
if [[ -z "$AWS_PROFILE" ]]; then
    echo "📋 No AWS_PROFILE set, using required profile: $REQUIRED_AWS_PROFILE"
    export AWS_PROFILE="$REQUIRED_AWS_PROFILE"
elif [[ "$AWS_PROFILE" != "$REQUIRED_AWS_PROFILE" ]]; then
    echo "⚠️  Warning: Current AWS_PROFILE is '$AWS_PROFILE'"
    echo "⚠️  This script requires AWS profile: $REQUIRED_AWS_PROFILE"
    echo "⚠️  Overriding for this script execution only..."
    export AWS_PROFILE="$REQUIRED_AWS_PROFILE"
else
    echo "✅ Using correct AWS profile: $AWS_PROFILE"
fi

# Verify AWS profile exists
if ! aws configure list-profiles | grep -q "^$AWS_PROFILE$"; then
    echo "❌ Error: AWS profile '$AWS_PROFILE' not found"
    echo "💡 Available profiles:"
    aws configure list-profiles | sed 's/^/   /'
    echo ""
    echo "💡 To configure the required profile, run:"
    echo "   aws configure --profile $AWS_PROFILE"
    exit 1
fi

echo "🔑 AWS profile '$AWS_PROFILE' verified"

# Function to extract date from index.csv
extract_date_from_index() {
    local index_file="$1"
    if [[ -f "$index_file" ]]; then
        # Extract date in YYYY-MM-DD format from timestamp like "2025-06-13T23:00:00Z"
        grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}T" "$index_file" | head -1 | cut -d'T' -f1
    else
        echo ""
    fi
}

# Function to generate date sequence (current date and 6 previous days)
generate_date_sequence() {
    local start_date="$1"
    local dates=()

    # Convert to seconds since epoch for date arithmetic
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date command
        local current_epoch=$(date -j -f "%Y-%m-%d" "$start_date" "+%s")
    else
        # Linux date command
        local current_epoch=$(date -d "$start_date" "+%s")
    fi

    # Generate 7 dates (current + 6 previous days)
    for i in {0..6}; do
        local target_epoch=$((current_epoch - i * 86400))  # 86400 = seconds in a day

        if [[ "$OSTYPE" == "darwin"* ]]; then
            local target_date=$(date -j -f "%s" "$target_epoch" "+%Y-%m-%d")
        else
            local target_date=$(date -d "@$target_epoch" "+%Y-%m-%d")
        fi

        dates+=("$target_date")
    done

    echo "${dates[@]}"
}

# Step 1: Handle existing data directory
if [[ -d "$DATA_DIR" ]]; then
    echo "📁 Found existing $DATA_DIR directory"
    echo "🗑️  Removing existing directory..."
    rm -rf "$DATA_DIR"
fi

# Step 2: Create fresh data directory and download forecast data
echo "📂 Creating fresh $DATA_DIR directory"
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

echo "⬇️  Downloading forecast data..."
aws s3 cp --recursive "s3://$S3_BUCKET/forecast" forecast

# Step 3: Download tree.csv
echo "⬇️  Downloading tree.csv..."
aws s3 cp "s3://$S3_BUCKET/tree.csv" tree.csv

# Step 4: Create samples directory structure and download index.csv
echo "📁 Creating samples directory structure..."
mkdir -p "$SAMPLES_PATH"
cd "$SAMPLES_PATH"

echo "⬇️  Downloading index.csv..."
aws s3 cp "s3://$S3_BUCKET/samples/data-v0-tree-v0/index.csv" index.csv

# Step 5: Extract date from index.csv
echo "📅 Reading date from index.csv..."
current_date=$(extract_date_from_index "index.csv")

if [[ -z "$current_date" ]]; then
    echo "❌ Error: Could not extract date from index.csv"
    echo "📄 Contents of index.csv:"
    cat index.csv
    exit 1
fi

echo "📅 Found date in index.csv: $current_date"

# Step 6: Generate date sequence and download sample data
echo "📋 Generating 7-day date sequence starting from $current_date..."
date_sequence=($(generate_date_sequence "$current_date"))

echo "📅 Will download data for dates: ${date_sequence[*]}"

# Download each date's data
for date in "${date_sequence[@]}"; do
    echo "⬇️  Downloading sample data for $date..."
    aws s3 cp --recursive \
        "s3://$S3_BUCKET/samples/data-v0-tree-v1/$date" \
        "$date" \
        || echo "⚠️  Warning: No data found for $date (this may be expected)"
done

echo "✅ Download complete!"
echo "📊 Data structure:"
cd "../../.."  # Back to forecast/localstack directory
find "$DATA_DIR" -type f -name "*.parquet" -o -name "*.csv" | head -20
echo "..."
echo "🎯 Ready for localstack bind mounting!"
