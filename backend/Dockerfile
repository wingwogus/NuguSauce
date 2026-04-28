FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

ARG JAR_FILE=api/build/libs/*-SNAPSHOT.jar

COPY ${JAR_FILE} app.jar

EXPOSE 8080 9090

ENTRYPOINT ["java", "-jar", "app.jar"]
