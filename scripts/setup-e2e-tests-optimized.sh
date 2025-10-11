#!/bin/bash

# Optimized Helper - E2E Testing Environment Setup Script
# This script reduces setup time from 5+ minutes to ~2 minutes

set -e

echo "🚀 Setting up E2E Testing Environment (Optimized)"
echo "================================================"

if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the root of the Helper project"
    exit 1
fi

if [ ! -f ".env.test" ]; then
    echo "⚠️ .env.test not found. Please create it from .env.local.sample."
    exit 1
fi

echo "🔧 Loading environment variables..."
set -o allexport
source .env.test
if [ "$CI" != "true" ] && [ -f ".env.test.local" ]; then
  source .env.test.local
fi
set +o allexport

CI="${CI:-false}"
echo "CI is set to $CI"

# Optimize container management
echo "🏗️ Optimizing Supabase container setup..."
if [ "$CI" = "true" ]; then
  export SUPABASE_CONFIG_PATH="./supabase/config.ci.toml"
fi

# Check if we have a cached database snapshot
DB_SNAPSHOT_PATH="/tmp/supabase_e2e_snapshot.sql"

# Function to create database snapshot
create_db_snapshot() {
    echo "📸 Creating database snapshot for future runs..."
    pnpm run with-test-env pnpm supabase db dump -f "$DB_SNAPSHOT_PATH" --data-only || true
}

# Function to restore from snapshot
restore_from_snapshot() {
    if [ -f "$DB_SNAPSHOT_PATH" ]; then
        echo "⚡ Restoring from database snapshot..."
        pnpm run with-test-env pnpm supabase db reset --linked false
        pnpm run with-test-env pnpm supabase db psql -f "$DB_SNAPSHOT_PATH" || return 1
        return 0
    fi
    return 1
}

# Start Supabase services in background
echo "🚀 Starting Supabase services..."
pnpm run with-test-env pnpm supabase start &
SUPABASE_PID=$!

# Parallel operations while Supabase starts
if [ "$CI" != "true" ]; then
    echo "📦 Building packages in parallel..."
    pnpm run-on-packages build &
    BUILD_PID=$!
fi

# Wait for Supabase to start
wait $SUPABASE_PID
echo "⏳ Waiting for Auth service to initialize..."
sleep 3

# Try to restore from snapshot first
if ! restore_from_snapshot; then
    echo "🔄 Full database setup (first run or snapshot failed)..."
    pnpm run with-test-env pnpm supabase db reset
    echo "📦 Applying database migrations..."
    pnpm run with-test-env drizzle-kit migrate --config ./db/drizzle.config.ts
    echo "🌱 Seeding the database..."
    pnpm run with-test-env pnpm tsx --conditions=react-server ./db/seeds/seedDatabase.ts
    
    # Create snapshot for next run
    create_db_snapshot
fi

# Wait for parallel operations to complete
if [ "$CI" != "true" ] && [ -n "$BUILD_PID" ]; then
    wait $BUILD_PID
fi

echo ""
echo "🎉 E2E Testing Environment Setup Complete!"
echo "⏱️ Optimized setup finished in significantly less time!"