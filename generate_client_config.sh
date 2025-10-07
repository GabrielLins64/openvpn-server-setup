#!/bin/bash

# Usage: ./generate_client_config.sh <client-name>

set -euo pipefail

BASE_DIR="EasyRSA-3.2.4"

if [ "$#" -lt 1 ]; then
	echo "Uso: $0 <client-name>"
	echo
	echo "Gera um arquivo .ovpn juntando 'base.conf' com os certificados e chave do cliente." 
	echo "Exemplo: $0 joao.silva"
	exit 1
fi

CLIENT_NAME="$1"

# Paths
OUT_FILE="${CLIENT_NAME}.ovpn"
CA_CERT="$BASE_DIR/pki/ca.crt"
CLIENT_CERT="$BASE_DIR/pki/issued/${CLIENT_NAME}.crt"
CLIENT_KEY="$BASE_DIR/pki/private/${CLIENT_NAME}.key"

# Basic existence checks
if [ ! -f "base.conf" ]; then
	echo "Erro: arquivo 'base.conf' não encontrado no diretório atual." >&2
	exit 1
fi
if [ ! -f "$CA_CERT" ]; then
	echo "Erro: certificado CA não encontrado em: $CA_CERT" >&2
	exit 1
fi
if [ ! -f "$CLIENT_CERT" ]; then
	echo "Erro: certificado do cliente não encontrado em: $CLIENT_CERT" >&2
	exit 1
fi
if [ ! -f "$CLIENT_KEY" ]; then
	echo "Erro: chave privada do cliente não encontrada em: $CLIENT_KEY" >&2
	exit 1
fi

# Inicia o arquivo final com a configuração base
cat base.conf > "$OUT_FILE"

# Adiciona o certificado da CA
{
	echo "<ca>"
	cat "$CA_CERT"
	echo "</ca>"
} >> "$OUT_FILE"

# Adiciona o certificado do cliente
{
	echo "<cert>"
	cat "$CLIENT_CERT"
	echo "</cert>"
} >> "$OUT_FILE"

# Adiciona a chave privada do cliente
{
	echo "<key>"
	cat "$CLIENT_KEY"
	echo "</key>"
} >> "$OUT_FILE"

echo "Arquivo gerado: $OUT_FILE"
