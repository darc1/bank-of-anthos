#!/bin/bash

SERVICE_NAME=contacts.service
LOG_LEVEL=INFO
PORT=5000
DB_SERVER="172.23.155.148"

yum install -y python3 python3-devel gcc gcc-c++ 

cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"
python3 -m pip install -r requirements.txt
mkdir /app/
cp *.py /app/
cp logging.conf /app/
cp ../../extras/publickey /app/
cp ../../extras/privatekey /app/

cat <<EOF >/app/.env
VERSION="v0.5.0"
PORT=$PORT
PRIV_KEY_PATH=/app/privatekey
TOKEN_EXPIRY_SECONDS=9000
LOG_LEVEL=$LOG_LEVEL
LOCAL_ROUTING_NUM=883745000
PUB_KEY_PATH=/app/publickey
ACCOUNTS_DB_URI="postgresql://postgres:postgres@$DB_SERVER:5432/accounts"
ENABLE_TRACING=false
EOF

cat <<EOF >/etc/systemd/system/${SERVICE_NAME}
[Service]
Type=simple
RemainAfterExit=yes
WorkingDirectory=/app
EnvironmentFile=/app/.env
ExecStart=/usr/local/bin/gunicorn -b 0.0.0.0:$PORT --threads 4 --log-config /app/logging.conf --log-level=$LOG_LEVEL "contacts:create_app()"

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}
firewall-cmd --zone=public --permanent --add-port $PORT/tcp
firewall-cmd --reload
