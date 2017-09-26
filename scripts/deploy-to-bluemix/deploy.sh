#!/bin/bash

echo "Creating Office Space App"

IP_ADDR=$(bx cs workers "$CLUSTER_NAME" | grep normal | awk '{ print $2 }' | head -1)
if [ -z "$IP_ADDR" ]; then
  echo "$CLUSTER_NAME not created or workers not ready"
  exit 1
fi

echo -e "Configuring vars"
exp=$(bx cs cluster-config "$CLUSTER_NAME" | grep export)
if bx cs cluster-config "$CLUSTER_NAME" -ne 0;
then
  echo "Cluster $CLUSTER_NAME not created or not ready."
  exit 1
fi
eval "$exp"

kubectl delete --ignore-not-found=true -f secrets.yaml
kubectl delete --ignore-not-found=true -f account-database.yaml
kubectl delete --ignore-not-found=true -f account-summary.yaml
kubectl delete --ignore-not-found=true -f compute-interest-api.yaml
kubectl delete --ignore-not-found=true -f transaction-generator.yaml
kuber=$(kubectl get pods -l app=office-space)
while [ ${#kuber} -ne 0 ]
do
    sleep 5s
    kubectl get pods -l app=office-space
    kuber=$(kubectl get pods -l app=offce-space)
done

kubectl apply -f secrets.yaml
echo "Creating MySQL Database..."
kubectl create -f account-database.yaml
echo "Creating Spring Boot App..."
kubectl create -f compute-interest-api.yaml
sleep 5s

if [[ -z "$GMAIL_SENDER_USER" ]] && [[ -z "$GMAIL_SENDER_PASSWORD" ]] && [[ -z "$EMAIL_RECEIVER" ]]
then
    echo "Environment variables GMAIL_SENDER_USER, GMAIL_SENDER_PASSWORD, EMAIL_RECEIVER are not set. Notification service would not be deployed"
else
    echo "Environment variables are changed, launching Notification service..."
    sed -i s#username@gmail.com#"$GMAIL_SENDER_USER"# send-notification.yaml
    sed -i s#password@gmail.com#"$GMAIL_SENDER_PASSWORD"# send-notification.yaml
    sed -i s#sendTo@gmail.com#"$EMAIL_RECEIVER"# send-notification.yaml
    kubectl create -f send-notification.yaml
fi
sleep 5s

echo "Creating Node.js Frontend..."
kubectl create -f account-summary.yaml

echo "Creating Transaction Generator..."
kubectl create -f transaction-generator.yaml
sleep 5s

echo "Getting IP and Port"
bx cs workers "$CLUSTER_NAME"
NODEPORT=$(kubectl get svc | grep account-summary | awk '{print $4}' | sed -e s#80:## | sed -e s#/TCP##)
kubectl get svc | grep account-summary
if [ -z "$NODEPORT" ]
then
    echo "NODEPORT not found"
    exit 1
fi
kubectl get pods,svc -l app=office-space
echo "You can now view your account balance at http://$IP_ADDR:$NODEPORT"
