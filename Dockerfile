FROM openjdk:17-alpine

ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

CMD ["/bin/bash", "-c", "java -jar /app.jar >> /logs/$(date +\%Y\%m%d)_$HOSTNAME"]
