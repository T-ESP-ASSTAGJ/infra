# === STAGE 1: The Builder ===
FROM ghcr.io/cloudnative-pg/postgresql:18 AS builder
USER root

# 1. Update, UPGRADE, and install build deps
#    This is the correct process. It will patch what it can.
#    The remaining CVEs have no fix on Debian 11 yet.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-server-dev-18 \
    git \
    && rm -rf /var/lib/apt/lists/*

# 2. Compile pg_stat_monitor from source
RUN git clone https://github.com/Percona/pg_stat_monitor.git /tmp/pg_stat_monitor && \
    cd /tmp/pg_stat_monitor && \
    make USE_PGXS=1 && \
    make USE_PGXS=1 install


# === STAGE 2: The Final Image ===
FROM ghcr.io/cloudnative-pg/postgresql:18
USER root

# 1. Update, UPGRADE, install runtime deps, and clean up
#    This is the correct process for the final image.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    postgresql-18-hypopg \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the compiled files from the 'builder' stage
COPY --from=builder /usr/lib/postgresql/18/lib/pg_stat_monitor.so /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/pg_stat_monitor.control /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/pg_stat_monitor--*.sql /usr/share/postgresql/18/extension/

USER postgres