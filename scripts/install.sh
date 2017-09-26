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
echo "1" | bx login -a https://api.ng.bluemix.net --apikey $BLUEMIX_AUTH
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
bx plugin install container-service -r Bluemix
echo "Installing kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
}

function cluster_setup() {
bx cs workers $CLUSTER_NAME
$(bx cs cluster-config $CLUSTER_NAME | grep export)
}

function clean_setup() {
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
}

function kube_adm_setup() {
    wget https://cdn.rawgit.com/Mirantis/kubeadm-dind-cluster/master/fixed/dind-cluster-v1.7.sh
    chmod 0755 dind-cluster-v1.7.sh
    ./dind-cluster-v1.7.sh up
    export PATH="$HOME/.kubeadm-dind-cluster:$PATH"

}

function initial_setup() {
kubectl apply -f secrets.yaml
echo "Creating MySQL Database..."
kubectl create -f account-database.yaml
echo "Creating Spring Boot App..."
kubectl create -f compute-interest-api.yaml
sleep 5s
echo "Creating Node.js Frontend..."
kubectl create -f account-summary.yaml
while [ $? -ne 0 ]
do
    sleep 1s
    echo "Creating Node.js Frontend failed. Trying to recreate..."
    COUNT=$(cat account-summary.yaml | grep 30080 | sed -e s#nodePort:## | xargs)
    COUNTUP=$((COUNT+1))
    sed -i s#$COUNT#$COUNTUP# account-summary.yaml
    kubectl apply -f account-summary.yaml
    echo $?
done

echo "Creating Transaction Generator..."
kubectl create -f transaction-generator.yaml
echo "Waiting for pods to be running"
i=0
while [[ $(kubectl get pods | grep -c Running) -ne 4 ]]; do
    if [[ ! "$i" -lt 24 ]]; then
        echo "Timeout waiting on pods to be ready. Test FAILED"
        exit 1
    fi
    sleep 10
    echo "...$i * 10 seconds elapsed..."
    ((i++))
done
echo "All pods are running"

}

function getting_ip_port() {
echo "Getting IP and Port"
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
    IP=127.0.0.1
    NODEPORT=8080/api/v1/namespaces/default/services/account-summary/proxy/
    echo "This is a pull request. Not using a bluemix cluster"
else
    IP=$(bx cs workers $CLUSTER_NAME | grep normal | awk '{print $2}' | head -1)
    bx cs workers $CLUSTER_NAME
    NODEPORT=$(kubectl get svc | grep account-summary | awk '{print $4}' | sed -e s#80:## | sed -e s#/TCP##)
fi
kubectl get svc | grep account-summary
if [ -z "$IP" ] || [ -z "$NODEPORT" ]
then
    echo "IP or NODEPORT not found"
    exit 1
fi
TRIES=0
while true
do
code=$(curl -sw '%{http_code}' http://$IP:$NODEPORT -o /dev/null)
    if [ "$code" = "200" ]; then
        echo "Account Summary is up."
        break
    fi
    if [ $TRIES -eq 10 ]
    then
        echo "Failed finding Account Summary. Error code is $code"
        exit 1
    fi
    TRIES=$((TRIES+1))
    sleep 5s
done

kubectl get pods,svc -l app=office-space
echo "Spring boot app found at http://$IP:$NODEPORT"
echo "Travis has finished its build."
}


if [[ "$TRAVIS_PULL_REQUEST" != "false" ]];
then
    kube_adm_setup
else
    install_bluemix_cli
    bluemix_auth
    cluster_setup
    clean_setup
fi
initial_setup
getting_ip_port
