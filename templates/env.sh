#!/usr/bin/env bash
# Configure docker-compose
declare -A ENV_MAP
ENV_MAP=([dev]=dev [staging]=staging [prod]=prod [production]=prod)
export ENV=${ENV_MAP[${ENV:-dev}]}

# Any environment variables here
