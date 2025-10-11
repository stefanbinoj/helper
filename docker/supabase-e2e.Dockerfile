# Pre-built Supabase container with seeded test data
FROM supabase/postgres:15.1.0.147

# Copy your migrations and seed data
COPY db/migrations/ /docker-entrypoint-initdb.d/migrations/
COPY db/seeds/ /docker-entrypoint-initdb.d/seeds/

# Environment variables for test setup
ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# Pre-run migrations and seeding
RUN /docker-entrypoint.sh postgres &\
    sleep 10 && \
    # Run your migrations here
    echo "Database pre-seeded for E2E testing"