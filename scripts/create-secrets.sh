#!/bin/bash

echo "Enter MySQL username: "
read username
echo "Enter MySQL password: "
read password
echo "Enter MySQL host: "
read host
echo "Enter MySQL port: "
read port

ENC_username=$(echo $username | tr -d '\n' | base64)
ENC_password=$(echo $password | tr -d '\n' | base64)
ENC_host=$(echo $host | tr -d '\n' | base64)
ENC_port=$(echo $port | tr -d '\n' | base64)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: demo-credentials
type: Opaque
data:
  username: $ENC_username
  password: $ENC_password
  host: $ENC_host
  port: $ENC_port
EOF
