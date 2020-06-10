#!/bin/bash
# Author: Milos Buncic
# Date: 2020/06/10
# Description: Generate and sync WireGuard configuration and publish QRCode via webhook service

export WGCG_CONFIG_FILE="${HOME}/wireguard/wgcg/wgcg.conf"
source ${WGCG_CONFIG_FILE}

WGCG_QR_ENDPOINT="https://wgcg.example.com/hooks/wgcg?servername=${WGCG_SERVER_NAME}"
WEBHOOK_CONFIG_PATH="/etc/webhook"


help() {
  echo "Usage: $(basename ${0}) add|remove|list [client_name] [private_ip]"
}


genpass() {
  local LENGTH=${1:-16}
  local RE='^[0-9]*$'

  if [[ ${LENGTH} =~ ${RE} ]]; then
    # LC_CTYPE=C required if running on MacOS
    LC_CTYPE=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c ${LENGTH} | xargs
  else
    return 1
  fi
}


gen_webhook_config() {
  local client_name=${1}
  local auth_file=${2}
  local client_token=$(genpass 40)

  cat > ${auth_file} <<EOF
{
  "and": [
    {
      "match": {
        "type": "value",
        "value": "${client_name}",
        "parameter": {
          "source": "url",
          "name": "username"
        }
      }
    },
    {
      "match": {
        "type": "value",
        "value": "${client_token}",
        "parameter": {
          "source": "url",
          "name": "token"
        }
      }
    }
  ]
}
EOF
  echo -e "\n${WGCG_QR_ENDPOINT}&username=${client_name}&token=${client_token}\n"
}


case ${1} in
  'add')
    shift
    wgcg.sh --add-client-config ${1} ${2} || exit 1
    gen_webhook_config ${1} "${WEBHOOK_CONFIG_PATH}/auth-${1}.json"
    wh.py
    chmod 600 "${WEBHOOK_CONFIG_PATH}/hooks.json" "${WEBHOOK_CONFIG_PATH}/auth-${1}.json"
    wgcg.sh --sync
  ;;
  'remove')
    shift
    wgcg.sh --rm-client-config ${1} || exit 1
    rm -f "${WEBHOOK_CONFIG_PATH}/auth-${1}.json"
    wh.py
    chmod 600 "${WEBHOOK_CONFIG_PATH}/hooks.json"
    wgcg.sh --sync
  ;;
  'list')
    wgcg.sh --list-used-ips
  ;;
  *)
    help
esac