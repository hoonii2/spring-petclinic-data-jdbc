FROM openjdk:17-alpine

ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

ENV CURRENT_DATE=$(date +\%Y\%m\%d)

CMD ["/bin/bash", "-c", "java -jar /app.jar >> /logs/${CURRENT_DATE}_${HOSTNAME}"]
