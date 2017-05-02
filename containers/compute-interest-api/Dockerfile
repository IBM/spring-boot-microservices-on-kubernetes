FROM maven:3.3.9-jdk-8-alpine
COPY . /app
WORKDIR /app
RUN apk update && apk add mysql mysql-client
ENTRYPOINT ["/app/custom-entrypoint.sh"]
CMD java -jar target/*.jar
