#!/bin/bash
set -e

echo "=== [1/4] Starting PostgreSQL Clusters ==="
sudo pg_ctlcluster 17 main start || true
sudo pg_ctlcluster 17 slave start || true
pg_lsclusters

echo "=== [2/4] Verifying Master Streaming Status ==="
sudo -u postgres psql -p 5432 -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

echo "=== [3/4] Verifying Slave Standby Mode ==="
sudo -u postgres psql -p 5433 -c "SELECT pg_is_in_recovery() AS is_slave_in_recovery;"

echo "=== [4/4] Testing Data Synchronization ==="
# Create a test table and insert data on Master (5432)
sudo -u postgres psql -p 5432 -c "CREATE TABLE IF NOT EXISTS replication_test (id serial PRIMARY KEY, message text);"
sudo -u postgres psql -p 5432 -c "INSERT INTO replication_test (message) VALUES ('Hello from Master at $(date)');"

# Wait 1 second for replication
sleep 1

echo "Fetching data from Slave (5433):"
sudo -u postgres psql -p 5433 -c "SELECT * FROM replication_test;"

echo "=== Verification Complete! ==="
