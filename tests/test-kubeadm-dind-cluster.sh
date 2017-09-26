#!/bin/bash -e

test_failed(){
    echo -e >&2 "\033[0;31mKubernetes test failed!\033[0m"
    exit 1
}

test_passed(){
    echo -e "\033[0;32mKubernetes test passed!\033[0m"
    exit 0
}

setup_dind-cluster() {
    wget https://cdn.rawgit.com/Mirantis/kubeadm-dind-cluster/master/fixed/dind-cluster-v1.7.sh
    chmod 0755 dind-cluster-v1.7.sh
    ./dind-cluster-v1.7.sh up
    export PATH="$HOME/.kubeadm-dind-cluster:$PATH"
}

kubectl_deploy() {
    kubeclt_clean

    echo "Applying MySQL credentials..."
    kubectl apply -f secrets.yaml

    echo "Creating MySQL Database..."
    kubectl create -f account-database.yaml

    echo "Creating Spring Boot App..."
    kubectl create -f compute-interest-api.yaml

    echo "Creating Node.js Frontend..."
    kubectl create -f account-summary.yaml

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

verify_deploy(){
    while true
    do
    code=$(curl -sw '%{http_code}' http://127.0.0.1:8080/api/v1/namespaces/default/services/account-summary/proxy/ -o /dev/null)
        if [ "$code" = "200" ]; then
            echo "Account Summary is up."
            break
        fi
        if [[ $TRIES -eq 10 ]]
        then
            echo "Failed finding Account Summary. Error code is $code"
            exit 1
        fi
        TRIES=$((TRIES+1))
        sleep 5s
    done
}

main(){

    if [[ -z "$BLUEMIX_AUTH" ]]
    then
        if ! setup_dind-cluster; then
            test_failed
        elif ! kubectl_deploy; then
            test_failed
        elif ! verify_deploy; then
            test_failed
        else
            test_passed
        fi
    else
      echo -e "\033[0;33mBluemix Auth detected; not running kubeadm-dind-cluster test.\033[0m"
      exit 0
    fi
}

main
