FROM openjdk:17-alpine

ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

ENTRYPOINT java -jar /app.jar 1> /logs/$(date +%Y%m%d)_$HOSTNAME.log 2> /logs/$(date +%Y%m%d)_$HOSTNAME\_error.log
