#!/bin/bash

SERVICE_NAME=frontend.service
LOG_LEVEL=INFO
PORT=5000
AD_LEDGER_MONOLITH="172.23.23.121:8080"
AD_DB="172.23.155.148"
AD_FE="172.23.155.196"
AD_USERSERVICE="172.23.155.197:5000"
AD_CONTACTS="172.23.155.195:5000"

yum install epel-release -y
yum install -y python3 python3-devel gcc gcc-c++ nginx

cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"
python3 -m pip install -r requirements.txt


# This is a workaround to use an unreleased version of grpcio, so that the cloud trace exporter and the OpenTelemetry RequestsInstrumentor do not create an infinite request loop.
#python3 -m pip install --pre --upgrade --force-reinstall --extra-index-url \
#    https://packages.grpc.io/archive/2020/06/635ded1749f990ffe6be0ca403e4b255cf62742f-983cbea2-bebc-4777-911c-14e4cb494b92/python \
#    grpcio

mkdir /app/
cp *.py /app/
cp logging.conf /app/
cp -r static /app/
cp -r templates /app/
cp ../../extras/publickey /app/
cp ../../extras/privatekey /app/
cp ../../extras/dhparam2048.pem /app/
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
cp nginx.conf /etc/nginx/nginx.conf


openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /app/nginx-selfsigned.key \
  -out /app/nginx-selfsigned.crt \
  -subj "/C=US/ST=New Sweden/L=Stockholm/O=./OU=./CN=$(hostname -I)/emailAddress=bank@anthos.com"

systemctl restart nginx

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
SCHEME=http
DEFAULT_USERNAME=anthos
DEFAULT_PASSWORD=anthos
BANK_NAME="vBank of Anthos"
CYMBAL_LOGO=false
TRANSACTIONS_API_ADDR=$AD_LEDGER_MONOLITH
BALANCES_API_ADDR=$AD_LEDGER_MONOLITH
HISTORY_API_ADDR=$AD_LEDGER_MONOLITH
CONTACTS_API_ADDR=$AD_CONTACTS
USERSERVICE_API_ADDR=$AD_USERSERVICE
VMWARE_ENV=true
EOF

cat <<EOF >/etc/systemd/system/${SERVICE_NAME}
[Service]
Type=simple
RemainAfterExit=yes
WorkingDirectory=/app
EnvironmentFile=/app/.env
ExecStart=/usr/local/bin/gunicorn -b 0.0.0.0:$PORT --threads 4 --log-config /app/logging.conf --log-level=$LOG_LEVEL "frontend:create_app()"

[Install]
WantedBy=multi-user.target
EOF

firewall-cmd --zone=public --permanent --add-port 80/tcp
firewall-cmd --zone=public --permanent --add-port 443/tcp
firewall-cmd --reload
echo "enable service"
systemctl enable ${SERVICE_NAME}
echo "starting service"
systemctl start ${SERVICE_NAME}
