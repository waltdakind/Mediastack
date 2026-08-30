#!/usr/bin/env bash
# ==============================================================================
# replicate-node.sh - Linux & Raspberry Pi MediaStack Node Replication Engine
# Replicates the complete MediaStack architecture onto Linux / ARM / x64 nodes.
# ==============================================================================

set -eo pipefail

TARGET_NODE_NAME="${1:-$(hostname)}"
TARGET_ARCH="${2:-x64}"
PRIMARY_NODE_IP="${3:-192.168.4.30}"
PUBLIC_DOMAIN="${4:-waltdakind.xubi.org}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================================"
echo "   M E D I A S T A C K   L I N U X   N O D E   R E P L I C A T I O N"
echo "   Node: ${TARGET_NODE_NAME} | Arch: ${TARGET_ARCH} | Primary IP: ${PRIMARY_NODE_IP}"
echo "================================================================================"

# 1. Determine Valkey Container Name
if [[ "${TARGET_NODE_NAME}" =~ (VoltaireDeux|Laptop|deux|2) ]]; then
    VALKEY_NAME="musicbrainz-docker-valkey-2"
else
    VALKEY_NAME="musicbrainz-docker-valkey-1"
fi

# 2. Write .env File
echo "[1/5] Generating .env configuration..."
cat <<EOF > "${SCRIPT_DIR}/.env"
PUID=$(id -u)
PGID=$(id -g)
TZ=America/New_York
PUBLIC_DOMAIN=${PUBLIC_DOMAIN}
LAN_DOMAIN=ordinateur.local
CONFIG_DIR=${SCRIPT_DIR}/config
MEDIA_DIR=/media/library
MUSIC_ROOT=/media/library/Music
VIDEO_ROOT=/media/library/Video
TV_ROOT=/media/library/TV
LIVESTREAM_ROOT=/media/library/LiveStream
MAIN_SERVER_HOST=${PRIMARY_NODE_IP}
X64_DEVICE_NAME=${TARGET_NODE_NAME}
VALKEY_CONTAINER_NAME=${VALKEY_NAME}
NODE_ARCHITECTURE=${TARGET_ARCH}
EOF

# 3. Create Required Directory Volumes
echo "[2/5] Creating volume directory structures..."
mkdir -p "${SCRIPT_DIR}/config/"{caddy_data,caddy_config,jellyfin/data/data,jellyseerr/db,sonarr,radarr,prowlarr,bazarr/db,tvheadend,db-backup}
mkdir -p "${SCRIPT_DIR}"/{certs,dashboard,handoffs,transmission/config,musicbrainz-docker/local/secrets}

# 4. Generate Multi-Domain SSL/TLS Certificates
echo "[3/5] Checking SSL/TLS Certificates..."
if [ ! -f "${SCRIPT_DIR}/certs/cert.pem" ]; then
    echo "Generating certificates with OpenSSL..."
    cat <<EOF > "${SCRIPT_DIR}/certs/openssl.cnf"
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = New York
L = New York
O = MediaStack Systems
CN = ${PUBLIC_DOMAIN}

[v3_ca]
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_server]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${PUBLIC_DOMAIN}
DNS.2 = *.${PUBLIC_DOMAIN}
DNS.3 = *.ordinateur.local
DNS.4 = *.voltairedeux.local
DNS.5 = *.voltaireun.local
DNS.6 = localhost
IP.1  = 127.0.0.1
IP.2  = 192.168.4.30
IP.3  = 192.168.4.21
IP.4  = 192.168.4.1
EOF
    openssl req -x509 -new -nodes -newkey rsa:4096 -keyout "${SCRIPT_DIR}/certs/ca.key" -out "${SCRIPT_DIR}/certs/ca.crt" -days 3650 -config "${SCRIPT_DIR}/certs/openssl.cnf" -extensions v3_ca
    openssl genrsa -out "${SCRIPT_DIR}/certs/key.pem" 4096
    openssl req -new -key "${SCRIPT_DIR}/certs/key.pem" -out "${SCRIPT_DIR}/certs/server.csr" -config "${SCRIPT_DIR}/certs/openssl.cnf"
    openssl x509 -req -in "${SCRIPT_DIR}/certs/server.csr" -CA "${SCRIPT_DIR}/certs/ca.crt" -CAkey "${SCRIPT_DIR}/certs/ca.key" -CAcreateserial -out "${SCRIPT_DIR}/certs/cert.pem" -days 3650 -extfile "${SCRIPT_DIR}/certs/openssl.cnf" -extensions v3_server
    openssl pkcs12 -export -out "${SCRIPT_DIR}/certs/server.pfx" -inkey "${SCRIPT_DIR}/certs/key.pem" -in "${SCRIPT_DIR}/certs/cert.pem" -certfile "${SCRIPT_DIR}/certs/ca.crt" -password pass:mediastack
    rm -f "${SCRIPT_DIR}/certs/server.csr" "${SCRIPT_DIR}/certs/ca.srl"
    echo "[OK] Generated 4096-bit SSL certificates."
fi

# 5. Launch Docker Stack
echo "[4/5] Starting Docker Compose stack..."
cd "${SCRIPT_DIR}"
docker compose up -d

# 6. Verify HTTPS Ingress
echo "[5/5] Testing HTTPS (port 443) Ingress..."
sleep 4
curl -k -s -o /dev/null -w "HTTPS Ingress Status: %{http_code}\n" --resolve "${PUBLIC_DOMAIN}:443:127.0.0.1" "https://${PUBLIC_DOMAIN}/System/Info/Public" || true

echo "================================================================================"
echo "   M E D I A S T A C K   N O D E   R E P L I C A T I O N   C O M P L E T E"
echo "================================================================================"
