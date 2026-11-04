#!/bin/bash
# Cria o grupo, o ACR e o Oracle em ACI. A esteira passa a publicar so a API.
# Uso: ./criar-banco.sh
#      ./criar-banco.sh remover
set -euo pipefail

DEVOPS_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCATION="brazilsouth"
RG="rg-clyvovet-sprint4"
ACI_ORACLE="aci-clyvovet-oracle"
SUFIXO="$(date +%H%M%S)"

if [ "${1:-}" = "remover" ]; then
  echo "Removendo ${RG}..."
  az group delete --name "${RG}" --yes --no-wait
  echo "Exclusao iniciada."
  exit 0
fi

if [ -f "${DEVOPS_DIR}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${DEVOPS_DIR}/.env"
  set +a
fi

ORACLE_PASSWORD="${ORACLE_PASSWORD:-ClyvoVet${SUFIXO}Aa}"
APP_USER_PASSWORD="${APP_USER_PASSWORD:-ClyvoVet${SUFIXO}Aa}"
ORACLE_DNS="${AZ_ORACLE_DNS:-clyvovet-ora-${SUFIXO}}"
API_DNS="${AZ_API_DNS:-clyvovet-s4-${SUFIXO}}"

echo "==> Resource group ${RG}"
az group create --name "${RG}" --location "${LOCATION}" --tags owner=clyvovet environment=sprint4 discipline=devops

if [ -n "${AZ_ACR_NAME:-}" ]; then
  ACR_NAME="${AZ_ACR_NAME}"
else
  ACR_NAME="$(az acr list --resource-group "${RG}" --query "[0].name" -o tsv)"
  if [ -z "${ACR_NAME}" ]; then
    ACR_NAME="clyvovets4${SUFIXO}"
  fi
fi

echo "==> Azure Container Registry ${ACR_NAME}"
if az acr show --name "${ACR_NAME}" --resource-group "${RG}" >/dev/null 2>&1; then
  echo "Registro ja existe."
else
  az acr create --resource-group "${RG}" --name "${ACR_NAME}" --sku Basic --admin-enabled true --location "${LOCATION}"
fi
ACR_SERVER="$(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)"
ACR_USER="$(az acr credential show --name "${ACR_NAME}" --query username -o tsv)"
ACR_PASS="$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" -o tsv)"

echo "==> Imagem do Oracle"
az acr login --name "${ACR_NAME}"
docker build -t "${ACR_SERVER}/clyvovet-oracle:1.0" -f "${DEVOPS_DIR}/Dockerfile.oracle" "${DEVOPS_DIR}"
docker push "${ACR_SERVER}/clyvovet-oracle:1.0"

echo "==> ACI do Oracle"
az container create \
  --resource-group "${RG}" \
  --name "${ACI_ORACLE}" \
  --image "${ACR_SERVER}/clyvovet-oracle:1.0" \
  --registry-login-server "${ACR_SERVER}" \
  --registry-username "${ACR_USER}" \
  --registry-password "${ACR_PASS}" \
  --ports 1521 \
  --dns-name-label "${ORACLE_DNS}" \
  --cpu 1 \
  --memory 3.5 \
  --os-type Linux \
  --location "${LOCATION}" \
  --environment-variables APP_USER=clyvovet \
  --secure-environment-variables "ORACLE_PASSWORD=${ORACLE_PASSWORD}" "APP_USER_PASSWORD=${APP_USER_PASSWORD}"

echo "==> Aguardando o Oracle aplicar o script_bd.sql"
PRONTO=0
for i in $(seq 1 60); do
  LOGS="$(az container logs --resource-group "${RG}" --name "${ACI_ORACLE}" 2>/dev/null || true)"
  if printf '%s' "${LOGS}" | grep -Fq "DATABASE IS READY TO USE"; then
    echo "Oracle pronto."
    PRONTO=1
    break
  fi
  echo "Oracle ainda inicializando (${i}/60)..."
  sleep 20
done
if [ "${PRONTO}" -ne 1 ]; then
  echo "O Oracle nao ficou pronto a tempo. Veja: az container logs --resource-group ${RG} --name ${ACI_ORACLE}"
  exit 1
fi

FQDN="$(az container show --resource-group "${RG}" --name "${ACI_ORACLE}" --query ipAddress.fqdn -o tsv)"
CONN="User Id=clyvovet;Password=${APP_USER_PASSWORD};Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${FQDN})(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XEPDB1)))"

echo ""
echo "ACI do Oracle: ${ACI_ORACLE}"
echo "Host: ${FQDN}"
echo "Porta: 1521"
echo "Servico: XEPDB1"
echo "Usuario do schema: clyvovet"
echo ""
echo "Valores para o variable group clyvovet-sprint4:"
echo "ACR_LOGIN_SERVER=${ACR_SERVER}"
echo "ACR_USERNAME=${ACR_USER}"
echo "ACR_PASSWORD=${ACR_PASS}"
echo "ACI_DNS_LABEL=${API_DNS}"
echo "ORACLE_CONNECTION=${CONN}"
