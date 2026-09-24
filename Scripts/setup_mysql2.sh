#!/bin/bash
echo "=== Step 1: Creating directories ==="
mkdir -p /data/mysql2
chown -R mysql:mysql /data/mysql2
chmod 750 /data/mysql2

echo "=== Step 2: Creating config file ==="
cat << 'EOF' > /etc/mysql/mysqld2.cnf
[mysqld]
user = mysql
datadir = /data/mysql2
socket = /run/mysqld/mysqld2.sock
port = 3307
pid-file = /run/mysqld/mysqld2.pid
log-error = /var/log/mysql/mysqld2-error.log
server-id = 2
EOF

echo "=== Step 3: Initializing database ==="
mysqld --defaults-file=/etc/mysql/mysqld2.cnf --initialize --user=mysql

echo "=== Step 4: Creating systemd service ==="
cat << 'EOF' > /etc/systemd/system/mysql2.service
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
EOF

echo "=== Step 5: Starting service ==="
systemctl daemon-reload
systemctl enable --now mysql2
echo "=== Done! ==="
