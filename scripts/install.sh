#!/bin/sh

function install_bluemix_cli() {
#statements
echo "Installing Bluemix cli"
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.1_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
sudo ./Bluemix_CLI/install_bluemix_cli
}

function bluemix_auth() {
echo "Authenticating with Bluemix"
echo "1" | bx login -a https://api.ng.bluemix.net -u $BLUEMIX_USER -p $BLUEMIX_PASS
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
bx plugin install container-service -r Bluemix
echo "Installing kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
}

function cluster_setup() {
bx cs workers cluster-travis
$(bx cs cluster-config cluster-travis | grep export)
kubectl delete --ignore-not-found=true -f account-database.yaml
kubectl delete --ignore-not-found=true -f account-summary.yaml
kubectl delete --ignore-not-found=true -f compute-interest-api.yaml
kubectl delete --ignore-not-found=true -f transaction-generator.yaml
kuber=$(kubectl get pods -l app=office-space)
while [ ${#kuber} -ne 0 ]
do
    sleep 5s
    kubectl get pods -l app=gameon
    kuber=$(kubectl get pods -l app=offce-space)
done
}

function initial_setup() {
echo "Creating MySQL Database..."
kubectl create -f kubectl create -f account-database.yaml
echo "Creating Spring Boot App..."
kubectl create -f kubectl create -f compute-interest-api.yaml
sleep 5s
echo "Creating Node.js Frontend..."
kubectl create -f kubectl create -f account-summary.yaml
echo "Creating Transaction Generator..."
kubectl create -f kubectl create -f transaction-generator.yaml
sleep 5s
}

function getting_ip_port() {
echo "Getting IP and Port"
IP=$(kubectl get nodes | grep Ready | awk '{print $1}')
kubectl get nodes
NODEPORT=$(kubectl get svc | grep account-summary | awk '{print $4}' | sed -e s#80:## | sed -e s#/TCP##)
kubectl get svc | grep account-summary
if [ -z IP ] || [ -z NODEPORT]
then
    echo "IP or NODEPORT not found"
    exit 1
fi
echo "You can now view your account balance at http://$IP:$NODEPORT"
}



install_bluemix_cli
bluemix_auth
cluster_setup
initial_setup
