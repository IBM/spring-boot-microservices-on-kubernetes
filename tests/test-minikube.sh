#!/bin/bash -e

test_failed(){
    echo -e >&2 "\033[0;31mKubernetes test failed!\033[0m"
    exit 1
}

test_passed(){
    echo -e "\033[0;32mKubernetes test passed!\033[0m"
    exit 0
}

setup_minikube() {
    export CHANGE_MINIKUBE_NONE_USER=true
    curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.25.2/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
    sudo -E minikube start --vm-driver=none --kubernetes-version=v1.9.0
    minikube update-context
    JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl get nodes -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1; done
}

build_images() {
    set -x
    docker build -q -t account-summary-"$TRAVIS_BUILD_ID" containers/account-summary
    docker build -q -t compute-interest-api-"$TRAVIS_BUILD_ID" containers/compute-interest-api
    docker build -q -t transaction-generator-"$TRAVIS_BUILD_ID" containers/transaction-generator
    docker images
    set +x

    echo "Removing imaePullPolicy in yamls file... Pod would use the local images built"
    sed -i "/imagePullPolicy/d" compute-interest-api.yaml
    sed -i "/imagePullPolicy/d" account-summary.yaml
}

kubectl_deploy() {
    echo "Applying MySQL credentials..."
    kubectl apply -f secrets.yaml

    echo "Creating MySQL Database..."
    kubectl apply -f account-database.yaml

    echo "Creating Spring Boot App..."
    kubectl apply -f compute-interest-api.yaml
    kubectl set image deployment compute-interest-api compute-interest-api="compute-interest-api-$TRAVIS_BUILD_ID"

    echo "Creating Node.js Frontend..."
    kubectl apply -f account-summary.yaml
    kubectl set image deployment account-summary account-summary="account-summary-$TRAVIS_BUILD_ID"

    echo "Creating Transaction Generator..."
    kubectl apply -f transaction-generator.yaml
    kubectl set image deployment transaction-generator transaction-generator="transaction-generator-$TRAVIS_BUILD_ID"

    echo "Waiting for pods to be running"
    i=0
    while [[ $(kubectl get pods | grep -c Running) -ne 4 ]]; do
        if [[ ! "$i" -lt 24 ]]; then
            echo "Timeout waiting on pods to be ready. Test FAILED"

            kubectl get pods -a
            kubectl describe pods
            exit 1
        fi
        sleep 10
        echo "...$i * 10 seconds elapsed..."
        ((i++))
    done

    echo "All pods are running"
}

verify_deploy(){
    IP=$(minikube ip)
    while true
    do
    code=$(curl -sw '%{http_code}' http://"$IP":30080 -o /dev/null)
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
    if ! setup_minikube; then
        test_failed
    elif ! build_images; then
        test_failed
    elif ! kubectl_deploy; then
        test_failed
    elif ! verify_deploy; then
        test_failed
    else
        test_passed
    fi
}

main
