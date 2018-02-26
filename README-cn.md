[![构建状态](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes.svg?branch=master)](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes)
![Bluemix 部署](https://metrics-tracker.mybluemix.net/stats/13404bda8d87a6eca2c5297511ae9a5e/badge.svg)

#  在 Kubernetes 上构建和部署 Java Spring Boot 微服务

*阅读本文的其他语言版本：[English](README.md)。*

Spring Boot 是常用 Java 微服务框架之一。Spring Cloud 拥有一组丰富的、良好集成的 Java 类库，用于应对 Java 应用程序堆栈中发生的运行时问题；而 Kubernetes 则提供了丰富的功能集来运行多语言微服务。这些技术彼此互补，为 Spring Boot 应用程序提供了强大的平台。

在此代码中，我们演示了如何在 Kubernetes 上部署一个简单的 Spring Boot 应用程序。此应用程序称为 Office Space，它模仿了电影[上班一条虫 (Office Space)](http://www.imdb.com/title/tt0151804/) 中 Michael Bolton 的虚构应用程序创意。该应用程序利用了这样一个金融方案：通常不满一分钱的分币会四舍五入，而此方案将这部分币值转移到一个独立的银行账户中来计算交易利息。

该应用程序使用 Java 8/Spring Boot 微服务计算利息，然后将分币存入数据库。另一个 Spring Boot 微服务是通知服务。当账户余额超过 50,000 美元时，它会发送电子邮件。它是由计算利息的 Spring Boot Web 服务器触发的。前端使用 Node.js 应用程序来显示 Spring Boot 应用程序累积的当前账户余额。后端使用 MySQL 数据库来存储账户余额。

![spring-boot-kube](images/spring-boot-kube.png)

## 前提条件

使用 [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube) 创建一个 Kubernetes 集群用于本地测试，使用 [IBM Cloud Private](https://github.com/IBM/Kubernetes-container-service-GitLab-sample/blob/master/docs/deploy-with-ICP.md) 或者 [IBM Cloud Container Service](https://github.com/IBM/container-journey-template) 创建一个 Kubernetes 集群以部署到云中。本文中的代码使用 Travis 定期使用[基于 IBM Cloud Container Service 的 Kubernetes 集群](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) 进行测试。


## 步骤
1.[创建数据库服务](#1-create-the-database-service)  
1.1 [在容器中使用 MySQL](#11-use-mysql-in-container) 或者  
1.2 [使用 IBM Cloud MySQL服务](#12-use-bluemix-mysql)  
2.[创建 Spring Boot 微服务](#2-create-the-spring-boot-microservices)  
2.1 [使用 Maven 构建项目](#21-build-your-projects-using-maven)  
2.2 [构建和推送 Docker 镜像](#22-build-your-docker-images-for-spring-boot-services)  
2.3 [为 Spring Boot 服务修改 yaml 文件](#23-modify-compute-interest-apiyaml-and-send-notificationyaml-to-use-your-image)  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.3.1 [在通知服务中使用默认电子邮件服务](#231-use-default-email-service-gmail-with-notification-service) 或者  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.3.2 [在通知服务中使用 OpenWhisk Actions](#232-use-openwhisk-action-with-notification-service)  
2.4 [部署 Spring Boot 微服务](#24-deploy-the-spring-boot-microservices)  
3.[创建前端服务](#3-create-the-frontend-service)  
4.[创建交易生成器服务](#4-create-the-transaction-generator-service)  
5.[访问应用程序](#5-access-your-application)

#### [故障排除](#troubleshooting-1)

# 1.创建数据库服务

后端包含 MySQL 数据库和 Spring Boot 应用程序。每一项
微服务都包含一个 Kubernetes Deployment 和一个 Kubernetes Service。Kubernetes Deployment 用于管理每一项微服务所启动的 pod。Kubernetes Service 用于
为每一项微服务创建一个稳定的 DNS 记录，以便它们可以
根据域名相互引用。

* 创建 MySQL 数据库后端的方法有两种：
  **[在容器中使用 MySQL](#11-use-mysql-in-container)** *或者*
  **[使用 IBM Cloud MySQL 服务](#12-use-bluemix-mysql)**

## 1.1 在容器中使用 MySQL
```bash
$ kubectl create -f account-database.yaml
service "account-database" created
deployment "account-database" created
```
默认认证信息已使用 base64 在 secrets.yaml 中进行了编码。
> base64 编码不会加密或隐藏您的密钥。请勿将其上传至您的 Github 仓库中。

```
$ kubectl apply -f secrets.yaml
secret "demo-credentials" created
```

下一步请参考[步骤 2](#2-create-the-spring-boot-microservices) 。

## 1.2 使用 IBM Cloud MySQL 服务
通过 https://console.ng.bluemix.net/catalog/services/compose-for-mysql 在 IBM Cloud 中为 MySQL 提供 Provision Compose
转至 Service credentials 并查看您的凭证。包括 MySQL 主机名、端口、用户名和密码等信息位于凭证 URI 下，如下所示：
![images](images/mysqlservice.png)
您将需要应用这些凭证作为 Kubernetes 集群中的密钥。这些信息应已被 `base64` 编码。
使用脚本 `./scripts/create-secrets.sh`。系统将提示您输入自己的凭证。这将对您输入的凭证进行编码，并创建 Kubenetes Secret 对象。
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

_您也可以编辑 `secrets.yaml` 文件，将其中的数据值编辑为自己的 base64 编码的凭证。然后执行 `kubectl apply -f secrets.yaml`。_

下一步请参考[步骤 2](#2-create-the-spring-boot-microservices) 。

# 2.创建 Spring Boot 微服务
您需要[安装 Maven](https://maven.apache.org/index.html) 工具。
如果要修改 Spring Boot 应用程序，请在构建 Java 项目和 Docker 镜像之前完成修改。

Spring Boot 微服务包括 **Compute-Interest-API** 和 **Send-Notification**。

**Compute-Interest-API** 是一个需要使用 MySQL 数据库的 Spring Boot 应用程序。相关配置位于 `spring.datasource*` 中的 application.properties 中。

*compute-interest-api/src/main/resources/application.properties*
```
spring.datasource.url = jdbc:mysql://${MYSQL_DB_HOST}:${MYSQL_DB_PORT}/dockercon2017

# Username and password
spring.datasource.username = ${MYSQL_DB_USER}
spring.datasource.password = ${MYSQL_DB_PASSWORD}
```

`application.properties` 配置为使用 MYSQL_DB_* 环境变量。这些变量在 `compute-interest-api.yaml` 文件中定义。
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

YAML 文件已配置为从先前创建的 Kubernetes Secret 中获取值。这些信息将最终写入`application.properties`并最终为 Spring Boot 应用程序所用。 

**Send-Notification** 可配置为通过 Gmail 和/或 Slack 发送通知。通知仅在 MySQL 数据库中的账户余额超过 50,000 美元时推送一次。默认设置为使用 Gmail 。通知。您还可以使用事件驱动技术（在本例中为 [OpenWhisk](http://openwhisk.org/)） 来发送电子邮件和 Slack 消息。要将 OpenWhisk 与您的通知微服务配合使用，请在构建和部署微服务映像之前遵循[此处](#232-use-openwhisk-action-with-notification-service) 的步骤进行操作。否则，只有在选择仅使用电子邮件通知后才能继续。

## 2.1.使用 Maven 构建项目

当 Maven 成功构建 Java 项目后，您需要使用在其相应文件夹中提供的 **Dockerfile** 构建 Docker 镜像。
> 备注：compute-interest-api 会将分币乘以 100,000，用于执行模拟。您可以编辑/移除 `src/main/java/officespace/controller/MainController.java` 中的 `remainingInterest *= 100000` 行。当余额超过 50,000 美元时，程序还会发送通知， 您可以编辑 `if (updatedBalance > 50000 && emailSent == false )` 行中的数字。保存更改后，就可以构建项目了。

```bash
Go to containers/compute-interest-api
$ mvn package

Go to containers/send-notification
$ mvn package

```
*我们将使用 IBM Cloud 容器镜像仓库来保存镜像（由此进行映像命名），也可以使用 [Docker Hub](https://docs.docker.com/datacenter/dtr/2.2/guides/user/manage-images/pull-and-push-images) 保存镜像。*
## 2.2 为 Spring Boot 服务构建 Docker 映像
> 备注：本文使用 IBM Cloud 容器镜像库中保存镜像。

如果您计划使用 IBM Cloud 容器镜像库，需要首先设置帐户。请遵循[此处](https://developer.ibm.com/recipes/tutorials/getting-started-with-private-registry-hosted-by-ibm-bluemix/) 的教程进行操作。

您也可以使用  [Docker Hub](https://hub.docker.com)  保存镜像。

```bash
$ docker build -t registry.ng.bluemix.net/<namespace>/compute-interest-api .
$ docker build -t registry.ng.bluemix.net/<namespace>/send-notification .
$ docker push registry.ng.bluemix.net/<namespace>/compute-interest-api
$ docker push registry.ng.bluemix.net/<namespace>/send-notification
```
## 2.3 为使用您所构建的镜像，需要修改 *compute-interest-api.yaml* 和 *send-notification.yaml* 文件

成功推送镜像后，您将需要修改 yaml 文件以使用自己的镜像。
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

存在两种可能的通知方式，请参见：
[2.3.1 使用默认电子邮件服务](#231-use-default-email-service-gmail-with-notification-service)
**或**
[2.3.2 使用 OpenWhisk Actions](#232-use-openwhisk-action-with-notification-service)。

### 2.3.1 使用默认电子邮件服务 (Gmail) 来处理通知服务


您将需要修改 `send-notification.yaml` 中的 **环境变量**：
```yaml
    env:
    - name: GMAIL_SENDER_USER
       value: 'username@gmail.com' # change this to the gmail that will send the email
    - name: GMAIL_SENDER_PASSWORD
       value: 'password' # change this to the the password of the gmail above
    - name: EMAIL_RECEIVER
       value: 'sendTo@gmail.com' # change this to the email of the receiver
```

现在，您可以继续执行[步骤 2.4](#24-deploy-the-spring-boot-microservices)。

### 2.3.2 使用 OpenWhisk Action 来处理通知服务
本部分的要求：
* 您的 Slack 团队中具有 [Slack Incoming Webhook](https://api.slack.com/incoming-webhooks)。
* **IBM Cloud帐户**，以便使用 [OpenWhisk CLI](https://console.ng.bluemix.net/openwhisk/)。


#### 2.3.2.1 创建 Actions
本代码库的根目录中包含您创建 OpenWhisk Actions 时所需的代码。
如果您尚未安装 OpenWhisk CLI，请转至[此处](https://console.ng.bluemix.net/openwhisk/)。
您可以使用 `wsk` 命令来创建 OpenWhisk Actions。创建操作使用以下语法：`wsk action create < action_name > < source code for action> [add --param for optional Default parameters]`
* 创建用于发送 **Slack 通知** 的 Action
```bash
$ wsk action create sendSlackNotification sendSlack.js --param url https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
Replace the url with your Slack team's incoming webhook url.
```
* 创建用于发送 **Gmail 通知** 的 Action
```bash
$ wsk action create sendEmailNotification sendEmail.js
```

#### 2.3.2.2 测试 Actions
您可以使用 `wsk action invoke [action name] [add --param to pass  parameters]` 测试 OpenWhisk Actions
* 调用 Slack 通知
```bash
$ wsk action invoke sendSlackNotification --param text "Hello from OpenWhisk"
```
* 调用电子邮件通知
```bash
$ wsk action invoke sendEmailNotification --param sender [sender's email] --param password [sender's password]--param receiver [receiver's email] --param subject [Email subject] --param text [Email Body]
```
至此，您应分别收到一条 Slack 消息和一封电子邮件。

#### 2.3.2.3 为 Actions 创建 REST API
您可以使用 `wsk api create` 为创建的 Action 映射 REST API 端点。其语法为 `wsk api create [base-path] [api-path] [verb (GET PUT POST etc)] [action name]`
* 创建用于 **Slack 通知** 的 REST API 端点
```bash
$ wsk api create /v1 /slack POST sendSlackNotification
ok: created API /v1/email POST for action /_/sendEmailNotification
https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```
* 创建用于 **Gmail 通知** 的 REST API 端点
```bash
$ wsk api create /v1 /email POST sendEmailNotification
ok: created API /v1/email POST for action /_/sendEmailNotification
https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
```

您可以使用以下命令查看 API 列表：
```bash
$ wsk api list
ok: APIs
Action                                      Verb  API Name  URL
/Anthony.Amanse_dev/sendEmailNotificatio    post       /v1  https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
/Anthony.Amanse_dev/testDefault             post       /v1  https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```

请记录 这些 API URL，稍后我们将使用它们 。

#### 2.3.2.4 测试 REST API URL

* 测试用于 **Slack 通知** 的 REST API 端点。这里请使用您自己的 API URL。
```bash
$ curl -X POST -d '{ "text": "Hello from OpenWhisk" }' https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/slack
```
![Slack 通知](images/slackNotif.png)
* 测试用于 **Gmail 通知** 的 REST API 端点。这里请使用您自己的 API URL。将参数 **sender、password、receiver 和 subject** 的值替换为您自己的值。
```bash
$ curl -X POST -d '{ "text": "Hello from OpenWhisk", "subject": "Email Notification", "sender": "testemail@gmail.com", "password": "passwordOfSender", "receiver": "receiversEmail" }' https://service.us.apiconnect.ibmcloud.com/gws/apigateway/api/.../v1/email
```
![电子邮件通知](images/emailNotif.png)

#### 2.3.2.5 将 REST API URL 添加到 yaml 文件中
一旦确认您的 API 运行正常，就可以将这些 URL 放入 `send-notification.yaml` 文件中了
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




## 2.4 部署 Spring Boot 微服务
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

# 3.创建前端服务
此用户界面是 Node.js 应用程序，可显示账户总余额。
**如果您在 IBM Cloud 中使用 MySQL 数据库，请记得填充 `account-summary.yaml` 文件中环境变量的值，否则请将其留空。这是在[步骤 1](#1-create-the-database-service) 中执行的操作。**


* 创建 **Node.js** 前端：
```bash
$ kubectl create -f account-summary.yaml
service "account-summary" created
deployment "account-summary" created
```

# 4.创建交易生成器服务
交易生成器是 Python 应用程序，可使用累积利息生成随机交易。
* 创建交易生成器 **Python** 应用程序：
```bash
$ kubectl create -f transaction-generator.yaml
service "transaction-generator" created
deployment "transaction-generator" created
```

# 5.访问应用程序
您可以通过 Kubernetes Cluster IP 和 NodePort 访问应用程序。NodePort 应为 **30080**。

* 要查找 Cluster IP，请执行以下命令：
```bash
$ bx cs workers <cluster-name>
ID                                                 Public IP        Private IP      Machine Type   State    Status   
kube-dal10-paac005a5fa6c44786b5dfb3ed8728548f-w1   169.47.241.213   10.177.155.13   free           normal   Ready  
```

* 要查找账户摘要 (account-summary) 服务的 NodePort，请执行以下命令：
```bash
$ kubectl get svc
NAME                    CLUSTER-IP     EXTERNAL-IP   PORT(S)                                                                      AGE
...
account-summary         10.10.10.74    <nodes>       80:30080/TCP                                                                 2d
...
```
* 在您的浏览器上，转至 `http://<your-cluster-IP>:30080`
![账户余额](images/balance.png)

## 故障排除
* 要从头开始，请删除所有内容：`kubectl delete svc,deploy -l app=office-space`


## 参考资料
* [John Zaccone](https://github.com/jzaccone) - [通过 Docker 部署的 Office Space 应用程序](https://github.com/jzaccone/office-space-dockercon2017) 的原始作者。
* Office Space 应用程序是以 1999 年运用此理念的同名电影为基础编写的。

## 许可
[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)

# 隐私声明

可以配置包含这个包的样本 Kubernetes Yaml 文件，以跟踪对 [IBM Cloud ](https://www.bluemix.net/) 和其他 Kubernetes 平台的部署。每次部署时，都会将以下信息发送到 [Deployment Tracker](https://github.com/IBM/metrics-collector-service) 服务：

* Kubernetes 集群提供者（`IBM Cloud、Minikube 等`）
* Kubernetes 机器 ID (`MachineID`)
* 这个 Kubernetes 作业中的环境变量。

此数据是从样本应用程序的 yaml 文件中的 Kubernetes Job 收集而来。IBM 使用此数据来跟踪将样本应用程序部署到 IBM Cloud 相关的指标，以度量我们的示例的实用性，从而让我们能够持续改进为您提供的内容。仅跟踪那些包含代码以对 Deployment Tracker 服务执行 ping 操作的样本应用程序的部署过程。

## 禁用部署跟踪

请注释掉/移除 `account-summary.yaml` 文件末尾的 Kubernetes Job 部分。
