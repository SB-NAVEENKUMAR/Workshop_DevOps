cat << 'EOF' > fix_slave_auth.sh
#!/bin/bash
set -e

echo "=== Fixing root authentication for MySQL port 3307 ==="

# Stop the second mysql instance temporarily to override authentication via safe-mode/skip-grant or direct socket
sudo systemctl stop mysql2

# Alternatively, let's fix it directly by resetting root password authentication type via a temporary grant query
sudo mysqld --defaults-file=/etc/mysql/mysqld2.cnf --skip-grant-tables &
PID=$!

sleep 3

sudo mysql --protocol=tcp --host=127.0.0.1 --port=3307 -u root -e "
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('master');
FLUSH PRIVILEGES;
"

# Kill the temporary safe instance
sudo kill $PID
sleep 2

# Start the slave service normally
sudo systemctl start mysql2

echo "=== Done! Now you can log in using password 'master' ==="
EOF

chmod +x fix_slave_auth.sh
sudo ./fix_slave_auth.sh
