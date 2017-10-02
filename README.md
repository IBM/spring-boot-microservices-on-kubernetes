[![Build Status](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes.svg?branch=master)](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes)
![Bluemix Deployments](https://metrics-tracker.mybluemix.net/stats/13404bda8d87a6eca2c5297511ae9a5e/badge.svg)

# Build and deploy Java Spring Boot microservices on Kubernetes

Spring Boot is one of the popular Java microservices framework. Spring Cloud has a rich set of well integrated Java libraries to address runtime concerns as part of the Java application stack, and Kubernetes provides a rich featureset to run polyglot microservices. Together these technologies complement each other and make a great platform for Spring Boot applications.

In this code we demonstrate how a simple Spring Boot application can be deployed on top of Kubernetes. This application, Office Space, mimicks the fictitious app idea from Michael Bolton in the movie [Office Space](http://www.imdb.com/title/tt0151804/). The app takes advantage of a financial program that computes interest for transactions by diverting fractions of a cent that are usually rounded off into a seperate bank account.

The application uses a Java 8/Spring Boot microservice that computes the interest then takes the fraction of the pennies to a database. Another Spring Boot microservice is the notification service. It sends email when the account balance reach more than $50,000. It is triggered by the Spring Boot webserver that computes the interest. The frontend uses a Node.js app that shows the current account balance accumulated by the Spring Boot app. The backend uses a MySQL database to store the account balance.

![spring-boot-kube](images/spring-boot-kube.png)

## Prerequisite

Create a Kubernetes cluster with either [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube) for local testing, or with [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template) to deploy in cloud. The code here is regularly tested against [Kubernetes Cluster from Bluemix Container Service](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) using Travis.

## Deploy to Bluemix
If you want to deploy the Office Space app directly to Bluemix, click on 'Deploy to Bluemix' button below to create a Bluemix DevOps service toolchain and pipeline for deploying the sample, else jump to [Steps](#steps)

> You will need to create your Kubernetes cluster first and make sure it is fully deployed in your Bluemix account.

[![Create Toolchain](https://metrics-tracker.mybluemix.net/stats/13404bda8d87a6eca2c5297511ae9a5e/button.svg)](https://console.ng.bluemix.net/devops/setup/deploy/)

Please follow the [Toolchain instructions](https://github.com/IBM/container-journey-template/blob/master/Toolchain_Instructions.md) to complete your toolchain and pipeline.

## Steps
1. [Create the Database service](#1-create-the-database-service)  
1.1 [Use MySQL in container](#11-use-mysql-in-container) or  
1.2 [Use Bluemix MySQL](#12-use-bluemix-mysql)  
2. [Create the Spring Boot Microservices](#2-create-the-spring-boot-microservices)  
2.1 [Build Projects using Maven](#21-build-your-projects-using-maven)  
2.2 [Build and Push Docker Images](#22-build-your-docker-images-for-spring-boot-services)  
2.3 [Modify yaml files for Spring Boot services](#23-modify-compute-interest-apiyaml-and-send-notificationyaml-to-use-your-image)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.3.1 [Use default email service in Notification service](#231-use-default-email-service-gmail-with-notification-service) or  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.3.2 [Use OpenWhisk Actions in Notification service](#232-use-openwhisk-action-with-notification-service)  
2.4 [Deploy the Spring Boot microservices](#24-deploy-the-spring-boot-microservices)  
3. [Create the Frontend service](#3-create-the-frontend-service)  
4. [Create the Transaction Generator service](#4-create-the-transaction-generator-service)  
5. [Access Your Application](#5-access-your-application)

#### [Troubleshooting](#troubleshooting-1)

# 1. Create the Database service

The backend consists of a MySQL database and the Spring Boot app. Each
microservice has a Deployment and a Service. The deployment manages
the pods started for each microservice. The Service creates a stable
DNS entry for each microservice so they can reference their
dependencies by name.

* There are two ways to create the MySQL database backend:
  **[Use MySQL in container](#11-use-mysql-in-container)** *OR*
  **[Use Bluemix MySQL](#12-use-bluemix-mysql)**

## 1.1 Use MySQL in container
```bash
$ kubectl create -f account-database.yaml
service "account-database" created
deployment "account-database" created
```
Default credentials are already encoded in base64 in secrets.yaml.
> Encoding in base64 does not encrypt or hide your secrets. Do not put this in your Github.

```
$ kubectl apply -f secrets.yaml
secret "demo-credentials" created
```

Continue on in [Step 2](#2-create-the-spring-boot-microservices).

## 1.2 Use Bluemix MySQL
Provision Compose for MySQL in Bluemix via https://console.ng.bluemix.net/catalog/services/compose-for-mysql
Go to Service credentials and view your credentials. Your MySQL hostname, port, user, and password are under your credential uri and it should look like this
![images](images/mysqlservice.png)
You will need to apply these credentials as a Secret in your Kubernetes cluster. It should be `base64` encoded.
Use the script `./scripts/create-secrets.sh`. You will be prompted to enter your credentials. This will encode the credentials you input and apply them in your cluster as Secrets.
```bash
$ ./scripts/create-secrets.sh
Enter MySQL username:
admin
Enter MySQL password:
password
Enter MySQL host:
hostname
Enter MySQL port:
23966
secret "demo-credentials" created
```

_You can also use the `secrets.yaml` file and edit the data values in it to your own base64 encoded credentials. Then do `kubectl apply -f secrets.yaml`._

Continue on in [Step 2](#2-create-the-spring-boot-microservices).

# 2. Create the Spring Boot Microservices
You will need to have [Maven installed in your environment](https://maven.apache.org/index.html).
If you want to modify the Spring Boot apps, you will need to do it before building the Java project and the docker image.

The Spring Boot Microservices are the **Compute-Interest-API** and the **Send-Notification**.

**Compute-Interest-API** is a Spring Boot app configured to use a MySQL database. The configuration is located in application.properties in `spring.datasource.*`

*compute-interest-api/src/main/resources/application.properties*
```
spring.datasource.url = jdbc:mysql://${MYSQL_DB_HOST}:${MYSQL_DB_PORT}/dockercon2017

# Username and password
spring.datasource.username = ${MYSQL_DB_USER}
spring.datasource.password = ${MYSQL_DB_PASSWORD}
```

The `application.properties` is configured to use MYSQL_DB_* environment variables. These are defined in the `compute-interest-api.yaml` file.
*compute-interest-api.yaml*
```yaml
spec:
  containers:
  - image: anthonyamanse/compute-interest-api:secrets
    imagePullPolicy: Always
    name: compute-interest-api
    env:
      - name: MYSQL_DB_USER
        valueFrom:
          secretKeyRef:
            name: demo-credentials
            key: username
      - name: MYSQL_DB_PASSWORD
        valueFrom:
          secretKeyRef:
            name: demo-credentials
            key: password
      - name: MYSQL_DB_HOST
        valueFrom:
          secretKeyRef:
            name: demo-credentials
            key: host
      - name: MYSQL_DB_PORT
        valueFrom:
          secretKeyRef:
            name: demo-credentials
            key: port
    ports:
    - containerPort: 8080
```

The YAML file is already configured to get the values from the Kubernetes Secrets that was created earlier. This will be used by the Spring Boot application in `application.properties.`

The **Send-Notification** can be configured to send notification through gmail and/or Slack. The notification only pushes once when the account balance on the MySQL database goes over $50,000. Default is the gmail option. You can also use event driven technology, in this case [OpenWhisk](http://openwhisk.org/) to send emails and slack messages. To use OpenWhisk with your notification microservice, please follow the steps [here](#232-use-openwhisk-action-with-notification-service) before building and deploying the microservice images. Otherwise, you can proceed if you choose to only have an email notification setup.

## 2.1. Build your projects using Maven

After Maven has successfully built the Java project, you will need to build the Docker image using the provided **Dockerfile** in their respective folders.
> Note: The compute-interest-api multiplies the fraction of the pennies to x100,000 for simulation purposes. You can edit/remove the line `remainingInterest *= 100000` in `src/main/java/officespace/controller/MainController.java`. It also sends a notification when the balance goes over $50,000. You can edit the number in the line `if (updatedBalance > 50000 && emailSent == false )`. After saving your changes, you can now then build the projects.

```bash
Go to containers/compute-interest-api
$ mvn package

Go to containers/send-notification
$ mvn package

```
*We will be using Bluemix container registry to push images (hence the image naming), but the images [can be pushed in Docker hub](https://docs.docker.com/datacenter/dtr/2.2/guides/user/manage-images/pull-and-push-images) as well.*
## 2.2 Build your Docker images for Spring Boot services
> Note: This is being pushed in the Bluemix Container Registry.

If you plan to use Bluemix Container Registry, you will need to setup your account first. Follow the tutorial [here](https://developer.ibm.com/recipes/tutorials/getting-started-with-private-registry-hosted-by-ibm-bluemix/).

You can also push it in [Docker Hub](https://hub.docker.com).

```bash
$ docker build -t registry.ng.bluemix.net/<namespace>/compute-interest-api .
$ docker build -t registry.ng.bluemix.net/<namespace>/send-notification .
$ docker push registry.ng.bluemix.net/<namespace>/compute-interest-api
$ docker push registry.ng.bluemix.net/<namespace>/send-notification
```
## 2.3 Modify *compute-interest-api.yaml* and *send-notification.yaml* to use your image

Once you have successfully pushed your images, you will need to modify the yaml files to use your images.
```yaml
// compute-interest-api.yaml
  spec:
    containers:
    - image: registry.ng.bluemix.net/<namespace>/compute-interest-api # replace with your image name
```

```yaml
// send-notification.yaml
  spec:
    containers:
    - image: registry.ng.bluemix.net/<namespace>/send-notification # replace with your image name
```

There are two types of notifications possible, either
[2.3.1 Use default email service](#231-use-default-email-service-gmail-with-notification-service)
**OR**
[2.3.2 Use OpenWhisk Actions](#232-use-openwhisk-action-with-notification-service).

### 2.3.1 Use default email service (gmail) with Notification service


You will need to modify the **environment variables** in the `send-notification.yaml`:
```yaml
    env:
    - name: GMAIL_SENDER_USER
       value: 'username@gmail.com' # change this to the gmail that will send the email
    - name: GMAIL_SENDER_PASSWORD
       value: 'password' # change this to the the password of the gmail above
    - name: EMAIL_RECEIVER
       value: 'sendTo@gmail.com' # change this to the email of the receiver
```

You may now proceed to [Step 2.4](#24-deploy-the-spring-boot-microservices).

### 2.3.2 Use OpenWhisk Action with Notification service
Requirements for this sections:
* [Slack Incoming Webhook](https://api.slack.com/incoming-webhooks) in your Slack team.
* **Bluemix Account** to use [OpenWhisk CLI](https://console.ng.bluemix.net/openwhisk/).


#### 2.3.2.1 Create Actions
The root directory of this repository contains the required code for you to create OpenWhisk Actions.
If you haven't installed the OpenWhisk CLI yet, go [here](https://console.ng.bluemix.net/openwhisk/).
You can create OpenWhisk Actions using the `wsk` command. Creating action uses the syntax: `wsk action create < action_name > < source code for action> [add --param for optional Default parameters]`
* Create action for sending **Slack Notification**
```bash
$ wsk action create sendSlackNotification sendSlack.js --param url https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
Replace the url with your Slack team's incoming webhook url.
```
* Create action for sending **Gmail Notification**
```bash
$ wsk action create sendEmailNotification sendEmail.js
```

#### 2.3.2.2 Test Actions
You can test your OpenWhisk Actions using `wsk action invoke [action name] [add --param to pass  parameters]`
* Invoke Slack Notification
```bash
$ wsk action invoke sendSlackNotification --param text "Hello from OpenWhisk"
```
* Invoke Email Notification
```bash
$ wsk action invoke sendEmailNotification --param sender [sender's email] --param password [sender's password]--param receiver [receiver's email] --param subject [Email subject] --param text [Email Body]
```
You should receive a slack message and receive an email respectively.

#### 2.3.2.3 Create REST API for Actions
You can map REST API endpoints for your created actions using `wsk api create`. The syntax for it is `wsk api create [base-path] [api-path] [verb (GET PUT POST etc)] [action name]`
* Create endpoint for **Slack Notification**
```bash
$ wsk api create /v1 /slack POST sendSlackNotification
ok: created API /v1/email POST for action /_/sendEmailNotification
https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```
* Create endpoint for **Gmail Notification**
```bash
$ wsk api create /v1 /email POST sendEmailNotification
ok: created API /v1/email POST for action /_/sendEmailNotification
https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
```

You can view a list of your APIs with this command:
```bash
$ wsk api list
ok: APIs
Action                                      Verb  API Name  URL
/Anthony.Amanse_dev/sendEmailNotificatio    post       /v1  https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
/Anthony.Amanse_dev/testDefault             post       /v1  https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```

Take note of your API URLs. You are going to use them later.

#### 2.3.2.4 Test REST API Url

* Test endpoint for **Slack Notification**. Replace the URL with your own API URL.
```bash
$ curl -X POST -d '{ "text": "Hello from OpenWhisk" }' https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```
![Slack Notification](images/slackNotif.png)
* Test endpoint for **Gmail Notification**. Replace the URL with your own API URL. Replace the value of the parameters **sender, password, receiver, subject** with your own.
```bash
$ curl -X POST -d '{ "text": "Hello from OpenWhisk", "subject": "Email Notification", "sender": "testemail@gmail.com", "password": "passwordOfSender", "receiver": "receiversEmail" }' https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
```
![Email Notification](images/emailNotif.png)

#### 2.3.2.5 Add REST API Url to yaml files
Once you have confirmed that your APIs are working, put the URLs in your `send-notification.yaml` file
```yaml
env:
- name: GMAIL_SENDER_USER
  value: 'username@gmail.com' # the sender's email
- name: GMAIL_SENDER_PASSWORD
  value: 'password' # the sender's password
- name: EMAIL_RECEIVER
  value: 'sendTo@gmail.com' # the receiver's email
- name: OPENWHISK_API_URL_SLACK
  value: 'https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack' # your API endpoint for slack notifications
- name: SLACK_MESSAGE
  value: 'Your balance is over $50,000.00' # your custom message
- name: OPENWHISK_API_URL_EMAIL
  value: 'https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email' # your API endpoint for email notifications
```




## 2.4 Deploy the Spring Boot Microservices
```bash
$ kubectl create -f compute-interest-api.yaml
service "compute-interest-api" created
deployment "compute-interest-api" created
```
```bash
$ kubectl create -f send-notification.yaml
service "send-notification" created
deployment "send-notification" created
```

# 3. Create the Frontend service
The UI is a Node.js app that shows the total account balance.
**If you are using a MySQL database in Bluemix, don't forget to fill in the values of the environment variables in `account-summary.yaml` file, otherwise leave them blank. This was done in [Step 1](#1-create-the-database-service).**


* Create the **Node.js** frontend:
```bash
$ kubectl create -f account-summary.yaml
service "account-summary" created
deployment "account-summary" created
```

# 4. Create the Transaction Generator service
The transaction generator is a Python app that generates random transactions with accumulated interest.
* Create the transaction generator **Python** app:
```bash
$ kubectl create -f transaction-generator.yaml
service "transaction-generator" created
deployment "transaction-generator" created
```

# 5. Access Your Application
You can access your app publicly through your Cluster IP and the NodePort. The NodePort should be **30080**.

* To find your IP:
```bash
$ bx cs workers <cluster-name>
ID                                                 Public IP        Private IP      Machine Type   State    Status   
kube-dal10-paac005a5fa6c44786b5dfb3ed8728548f-w1   169.47.241.213   10.177.155.13   free           normal   Ready  
```

* To find the NodePort of the account-summary service:
```bash
$ kubectl get svc
NAME                    CLUSTER-IP     EXTERNAL-IP   PORT(S)                                                                      AGE
...
account-summary         10.10.10.74    <nodes>       80:30080/TCP                                                                 2d
...
```
* On your browser, go to `http://<your-cluster-IP>:30080`
![Account-balance](images/balance.png)

## Troubleshooting
* To start over, delete everything: `kubectl delete svc,deploy -l app=office-space`


## References
* [John Zaccone](https://github.com/jzaccone) - The original author of the [office space app deployed via Docker](https://github.com/jzaccone/office-space-dockercon2017).
* The Office Space app is based on the 1999 film that used that concept.

## License
[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)

# Privacy Notice

Sample Kubernetes Yaml file that includes this package may be configured to track deployments to [IBM Bluemix](https://www.bluemix.net/) and other Kubernetes platforms. The following information is sent to a [Deployment Tracker](https://github.com/IBM/metrics-collector-service) service on each deployment:

* Kubernetes Cluster Provider(`Bluemix,Minikube,etc`)
* Kubernetes Machine ID (`MachineID`)
* Environment variables in this Kubernetes Job.

This data is collected from the Kubernetes Job in the sample application's yaml file. This data is used by IBM to track metrics around deployments of sample applications to IBM Bluemix to measure the usefulness of our examples so that we can continuously improve the content we offer to you. Only deployments of sample applications that include code to ping the Deployment Tracker service will be tracked.

## Disabling Deployment Tracking

Please common out/remove the Kubernetes Job portion at the end of the `account-summary.yaml` file.
