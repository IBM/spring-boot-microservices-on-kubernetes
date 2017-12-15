#!/bin/bash

kubeclt_clean() {
    echo "Cleaning cluster"
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
    echo "Cleaning done"
}

test_failed(){
    kubeclt_clean
    echo -e >&2 "\033[0;31mKubernetes test failed!\033[0m"
    exit 1
}

test_passed(){
    kubeclt_clean
    echo -e "\033[0;32mKubernetes test passed!\033[0m"
    exit 0
}

kubectl_config() {
    echo "Configuring kubectl"
    #shellcheck disable=SC2091
    $(bx cs cluster-config "$CLUSTER_NAME" | grep export)
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
    while [[ $(kubectl get pods -l app=office-space | grep -c Running) -ne 4 ]]; do
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
    IPS=$(bx cs workers "$CLUSTER_NAME" | awk '{ print $2 }' | grep '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    for IP in $IPS; do
        while true
        do
            code=$(curl -sw '%{http_code}' http://"$IP":30080 -o /dev/null)
            if [ "$code" = "200" ]; then
                echo "Account Summary is up."
                break
            fi
            if [ "$TRIES" -eq 10 ]
            then
                echo "Failed finding Account Summary. Error code is $code"
                exit 1
            fi
            TRIES=$((TRIES+1))
            sleep 5s
        done
    done
}

main(){
    if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
        echo -e "\033[0;33mPull Request detected. Not running Bluemix Container Service test.\033[0m"
        exit 0
    fi

    if ! kubectl_config; then
        echo "Config failed."
        test_failed
    elif ! kubectl_deploy; then
        echo "Deploy failed"
        test_failed
    elif ! verify_deploy; then
        test_failed
    else
        test_passed
    fi
}

main
