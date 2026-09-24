cat << 'EOF' > setup_replication.sh
#!/bin/bash
set -e

echo "=== Step 1: Configuring Master (Port 3306) ==="
MASTER_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
if [ ! -f "$MASTER_CNF" ]; then
    MASTER_CNF="/etc/my.cnf"
fi

# Add replication settings to master if not already present
if ! grep -q "server-id = 1" "$MASTER_CNF"; then
    sudo sed -i '/\[mysqld\]/a server-id = 1\nlog-bin = mysql-bin' "$MASTER_CNF"
    sudo systemctl restart mysql
fi

echo "=== Step 2: Creating Replication User on Master ==="
sudo mysql -u root -e "
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'ReplPassword123';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
"

# Get Master binary file and position
MASTER_STATUS=$(sudo mysql -u root -e "SHOW MASTER STATUS\G")
LOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
LOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')

echo "Master Log File: $LOG_FILE"
echo "Master Log Position: $LOG_POS"

echo "=== Step 3: Setting up Second Instance (Port 3307) ==="
sudo mkdir -p /data/mysql2
sudo chown -R mysql:mysql /data/mysql2
sudo chmod 750 /data/mysql2

cat << 'CONFIG_EOF' | sudo tee /etc/mysql/mysqld2.cnf
[mysqld]
user = mysql
datadir = /data/mysql2
socket = /run/mysqld/mysqld2.sock
port = 3307
pid-file = /run/mysqld/mysqld2.pid
log-error = /var/log/mysql/mysqld2-error.log
server-id = 2
CONFIG_EOF

echo "=== Step 4: Initializing & Starting Slave Service ==="
sudo mariadb-install-db --defaults-file=/etc/mysql/mysqld2.cnf --user=mysql

cat << 'SERVICE_EOF' | sudo tee /etc/systemd/system/mysql2.service
[Unit]
Description=MySQL Server Instance 2
After=network.target

[Service]
Type=notify
User=mysql
Group=mysql
ExecStart=/usr/sbin/mysqld --defaults-file=/etc/mysql/mysqld2.cnf
LimitNOFILE=10000
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mysql2

echo "=== Step 5: Connecting Slave to Master ==="
sudo mysql --protocol=tcp --host=127.0.0.1 --port=3307 -u root -e "
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='127.0.0.1',
  MASTER_PORT=3306,
  MASTER_USER='repl',
  MASTER_PASSWORD='ReplPassword123',
  MASTER_LOG_FILE='$LOG_FILE',
  MASTER_LOG_POS=$LOG_POS;
START SLAVE;
"

echo "=== Setup Complete! Checking Replication Status ==="
sudo mysql --protocol=tcp --host=127.0.0.1 --port=3307 -u root -e "SHOW SLAVE STATUS\G"
EOF
