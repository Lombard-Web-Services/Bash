#!/bin/bash
# By Thibaut LOMBARD (LombardWeb)
# Spring Boot TTS JAR app with PostgreSQL integration
# dummy example

# Variables
PROJECT_DIR="tts-app"
PACKAGE_DIR="src/main/java/com/example"
RESOURCES_DIR="src/main/resources"
PG_USER="postgres"
PG_DB="ttsdb"
PG_PASSWORD="your_password_here" # Replace with your actual PostgreSQL password
JAR_NAME="tts-app-0.0.1-SNAPSHOT.jar"
FREETTS_VERSION="1.2.2"
FREETTS_URL="https://sourceforge.net/projects/freetts/files/FreeTTS/FreeTTS%20${FREETTS_VERSION}/freetts-${FREETTS_VERSION}-bin.zip/download"
FREETTS_ZIP="freetts-${FREETTS_VERSION}-bin.zip"
FREETTS_JAR="freetts-${FREETTS_VERSION}/freetts-1.2/lib/freetts.jar"
JDK17_HOME="/usr/lib/jvm/java-17-openjdk-amd64" # Confirmed JDK 17 path from your system

# Enforce JDK 17
echo "Checking JDK 17 at $JDK17_HOME..."
if [ ! -f "$JDK17_HOME/bin/java" ] || [ ! -f "$JDK17_HOME/bin/javac" ]; then
 echo "JDK 17 not found or incomplete at $JDK17_HOME. Installing OpenJDK 17..."
 sudo apt update && sudo apt install -y openjdk-17-jdk
 if [ ! -f "$JDK17_HOME/bin/java" ] || [ ! -f "$JDK17_HOME/bin/javac" ]; then
  echo "Failed to install JDK 17. Please install manually: sudo apt install openjdk-17-jdk"
  exit 1
 fi
fi

JAVA_VERSION=$("$JDK17_HOME/bin/java" -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
JAVAC_VERSION=$("$JDK17_HOME/bin/javac" -version 2>&1 | awk '{print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" != "17" ] || [ "$JAVAC_VERSION" != "17" ]; then
 echo "JDK 17 required. Found java $JAVA_VERSION, javac $JAVAC_VERSION. Reinstalling..."
 sudo apt remove -y openjdk-17-jdk && sudo apt install -y openjdk-17-jdk
 JAVA_VERSION=$("$JDK17_HOME/bin/java" -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
 JAVAC_VERSION=$("$JDK17_HOME/bin/javac" -version 2>&1 | awk '{print $2}' | cut -d'.' -f1)
 if [ "$JAVA_VERSION" != "17" ] || [ "$JAVAC_VERSION" != "17" ]; then
  echo "Still incorrect versions (java $JAVA_VERSION, javac $JAVAC_VERSION). Please fix manually."
  exit 1
 fi
fi
echo "JDK 17 confirmed: java $JAVA_VERSION, javac $JAVAC_VERSION"

# Tool check function with case switch
check_tool() {
 local tool=$1
 local install_cmd=$2
 local var_name=$3

 case "$tool" in
  "mvn")
   PATH_VAR=$(which mvn)
   if [ -z "$PATH_VAR" ]; then
    echo "Maven not found. Installing..."
    sudo apt update && sudo apt install -y maven
    PATH_VAR=$(which mvn)
    if [ -z "$PATH_VAR" ]; then
     echo "Failed to install Maven. Please install it: $install_cmd"
     exit 1
    fi
   fi
   echo "Maven version (should use JDK 17):"
   export JAVA_HOME="$JDK17_HOME"
   export PATH="$JAVA_HOME/bin:$PATH"
   "$PATH_VAR" --version
   ;;
  "psql")
   PATH_VAR=$(which psql)
   if [ -z "$PATH_VAR" ]; then
    echo "PostgreSQL not found. Installing..."
    sudo apt update && sudo apt install -y postgresql
    PATH_VAR=$(which psql)
    if [ -z "$PATH_VAR" ]; then
     echo "Failed to install PostgreSQL. Please install it: $install_cmd"
     exit 1
    fi
   fi
   ;;
  "unzip")
   PATH_VAR=$(which unzip)
   if [ -z "$PATH_VAR" ]; then
    echo "unzip not found. Installing..."
    sudo apt update && sudo apt install -y unzip
    PATH_VAR=$(which unzip)
    if [ -z "$PATH_VAR" ]; then
     echo "Failed to install unzip. Please install it: $install_cmd"
     exit 1
    fi
   fi
   ;;
  *)
   echo "Unknown tool: $tool"
   exit 1
   ;;
 esac
 echo "$tool found at $PATH_VAR"
 eval "$var_name=$PATH_VAR"
}

# Check tools
check_tool "mvn" "sudo apt install maven" "MVN_PATH"
check_tool "psql" "sudo apt install postgresql" "PSQL_PATH"
check_tool "unzip" "sudo apt install unzip" "UNZIP_PATH"

# Clear Maven cache for Spring and Hibernate dependencies
echo "Clearing Maven cache for Spring and Hibernate dependencies..."
rm -rf ~/.m2/repository/org/springframework
rm -rf ~/.m2/repository/org/hibernate
rm -rf ~/.m2/repository/org/springframework/data
wait

# Create project directory structure
echo "Creating directory structure..."
mkdir -p "$PROJECT_DIR/$PACKAGE_DIR/entity" \
   "$PROJECT_DIR/$PACKAGE_DIR/repository" \
   "$PROJECT_DIR/$RESOURCES_DIR"
wait

cd "$PROJECT_DIR" || exit

# Check if FreeTTS is already in Maven repo, skip download if present
echo "Checking for FreeTTS in local Maven repository..."
FREETTS_MAVEN="$HOME/.m2/repository/com/sun/speech/freetts/${FREETTS_VERSION}/freetts-${FREETTS_VERSION}.jar"
if [ -f "$FREETTS_MAVEN" ]; then
 echo "FreeTTS ${FREETTS_VERSION} already installed in Maven repository."
else
 # Download FreeTTS JAR with retry logic
 echo "FreeTTS not found. Downloading ${FREETTS_VERSION}..."
 attempt=0
 max_attempts=3
 while [ $attempt -lt $max_attempts ]; do
  curl -L --output "$FREETTS_ZIP" "$FREETTS_URL" &
  CURL_PID=$!
  wait $CURL_PID
  if [ $? -eq 0 ] && [ -f "$FREETTS_ZIP" ] && [ -s "$FREETTS_ZIP" ]; then
   echo "Download completed."
   break
  fi
  echo "Download failed. Retrying ($((attempt + 1))/$max_attempts)..."
  attempt=$((attempt + 1))
  sleep 2
 done
 if [ $attempt -eq $max_attempts ]; then
  echo "Failed to download FreeTTS ZIP after $max_attempts attempts."
  exit 1
 fi

 # Unzip the downloaded file
 echo "Extracting FreeTTS..."
 "$UNZIP_PATH" "$FREETTS_ZIP" -d "freetts-${FREETTS_VERSION}" &
 UNZIP_PID=$!
 wait $UNZIP_PID
 if [ ! -f "$FREETTS_JAR" ]; then
  echo "Failed to extract FreeTTS JAR."
  ls -lR "freetts-${FREETTS_VERSION}"
  exit 1
 fi

 # Install FreeTTS JAR to local Maven repository
 echo "Installing FreeTTS JAR to local Maven repository..."
 export JAVA_HOME="$JDK17_HOME"
 export PATH="$JAVA_HOME/bin:$PATH"
 "$MVN_PATH" install:install-file -Dfile="$FREETTS_JAR" \
  -DgroupId=com.sun.speech -DartifactId=freetts -Dversion="${FREETTS_VERSION}" -Dpackaging=jar &
 MVN_INSTALL_PID=$!
 wait $MVN_INSTALL_PID
 if [ $? -ne 0 ]; then
  echo "Failed to install FreeTTS to local Maven repository."
  exit 1
 fi

 # Clean up downloaded files
 echo "Cleaning up..."
 rm -rf "freetts-${FREETTS_VERSION}" "$FREETTS_ZIP"
 wait
fi

# Create pom.xml with Java 17
echo "Creating pom.xml..."
cat > pom.xml << 'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion>
 <groupId>com.example</groupId>
 <artifactId>tts-app</artifactId>
 <version>0.0.1-SNAPSHOT</version>
 <packaging>jar</packaging>

 <parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>3.2.5</version>
  <relativePath/>
 </parent>

 <properties>
  <java.version>17</java.version>
 </properties>

 <dependencies>
  <!-- Spring Boot Starter (Core) -->
  <dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter</artifactId>
  </dependency>
  <!-- Spring Boot Data JPA -->
  <dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-data-jpa</artifactId>
  </dependency>
  <!-- PostgreSQL Driver -->
  <dependency>
   <groupId>org.postgresql</groupId>
   <artifactId>postgresql</artifactId>
   <version>42.7.3</version>
  </dependency>
  <!-- FreeTTS (Installed Locally) -->
  <dependency>
   <groupId>com.sun.speech</groupId>
   <artifactId>freetts</artifactId>
   <version>1.2.2</version>
  </dependency>
 </dependencies>

 <build>
  <plugins>
   <plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <configuration>
     <mainClass>com.example.TtsApp</mainClass>
    </configuration>
   </plugin>
  </plugins>
 </build>
</project>
EOF
wait

# Create application.properties
echo "Creating application.properties..."
cat > "$RESOURCES_DIR/application.properties" << EOF
spring.datasource.url=jdbc:postgresql://localhost:5432/$PG_DB
spring.datasource.username=$PG_USER
spring.datasource.password=$PG_PASSWORD
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
EOF
wait

# Create TtsApp.java
echo "Creating TtsApp.java..."
cat > "$PACKAGE_DIR/TtsApp.java" << 'EOF'
package com.example;

import com.example.entity.SpeechLog;
import com.example.repository.SpeechLogRepository;
import com.sun.speech.freetts.Voice;
import com.sun.speech.freetts.VoiceManager;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.util.Scanner;

@SpringBootApplication
public class TtsApp implements CommandLineRunner {

 private static final String VOICE_NAME = "kevin16";

 @Autowired
 private SpeechLogRepository speechLogRepository;

 public static void main(String[] args) {
  SpringApplication.run(TtsApp.class, args);
 }

 @Override
 public void run(String... args) {
  VoiceManager voiceManager = VoiceManager.getInstance();
  Voice voice = voiceManager.getVoice(VOICE_NAME);
  if (voice == null) {
   System.out.println("Error: Voice not found!");
   return;
  }
  voice.allocate();

  Scanner scanner = new Scanner(System.in);
  System.out.println("TTS App started. Enter text to speak (or 'exit' to quit):");

  while (true) {
   System.out.print("> ");
   String text = scanner.nextLine().trim();

   if (text.equalsIgnoreCase("exit")) {
    break;
   }

   if (text.isEmpty()) {
    System.out.println("Please enter some text!");
    continue;
   }

   // Speak the text
   voice.speak(text);

   // Save to PostgreSQL
   SpeechLog log = new SpeechLog(text);
   speechLogRepository.save(log);
   System.out.println("Text spoken and logged: " + text);
  }

  voice.deallocate();
  System.out.println("TTS App stopped.");
  scanner.close();
 }
}
EOF
wait

# Create SpeechLog.java (Entity) with jakarta.persistence
echo "Creating SpeechLog.java..."
cat > "$PACKAGE_DIR/entity/SpeechLog.java" << 'EOF'
package com.example.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class SpeechLog {

 @Id
 @GeneratedValue(strategy = GenerationType.IDENTITY)
 private Long id;
 private String text;
 private String timestamp;

 public SpeechLog() {
  this.timestamp = new java.util.Date().toString();
 }

 public SpeechLog(String text) {
  this.text = text;
  this.timestamp = new java.util.Date().toString();
 }

 // Getters and Setters
 public Long getId() { return id; }
 public void setId(Long id) { this.id = id; }
 public String getText() { return text; }
 public void setText(String text) { this.text = text; }
 public String getTimestamp() { return timestamp; }
 public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
}
EOF
wait

# Create SpeechLogRepository.java
echo "Creating SpeechLogRepository.java..."
cat > "$PACKAGE_DIR/repository/SpeechLogRepository.java" << 'EOF'
package com.example.repository;

import com.example.entity.SpeechLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SpeechLogRepository extends JpaRepository<SpeechLog, Long> {
}
EOF
wait

# Set up PostgreSQL database
echo "Setting up PostgreSQL database..."
export PGPASSWORD="$PG_PASSWORD"
while ! "$PSQL_PATH" -U "$PG_USER" -h localhost -lqt | cut -d\| -f 1 | grep -qw "$PG_DB"; do
 echo "Creating database '$PG_DB'..."
 "$PSQL_PATH" -U "$PG_USER" -h localhost -c "CREATE DATABASE $PG_DB;" 2>/dev/null &
 PSQL_PID=$!
 wait $PSQL_PID
 if [ $? -ne 0 ]; then
  echo "Failed to create database. Ensure PostgreSQL is running and configured for 'md5' authentication."
  echo "Steps to fix:"
  echo "1. Set a password: sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';\""
  echo "2. Edit pg_hba.conf (e.g., /etc/postgresql/14/main/pg_hba.conf):"
  echo "   Change 'local all postgres peer' to 'local all postgres md5'"
  echo "3. Restart PostgreSQL: sudo service postgresql restart"
  exit 1
 fi
 break
done
echo "Database '$PG_DB' ready."
unset PGPASSWORD
wait

# Build the project with Maven using JDK 17
echo "Building the JAR with Maven using JDK 17..."
export JAVA_HOME="$JDK17_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
"$MVN_PATH" clean package &
MVN_BUILD_PID=$!
wait $MVN_BUILD_PID
if [ $? -ne 0 ]; then
 echo "Maven build failed. Check your configuration."
 exit 1
fi

# Run the JAR with JDK 17
echo "Running the JAR file with JDK 17..."
"$JDK17_HOME/bin/java" -jar "target/$JAR_NAME" &
JAVA_PID=$!
wait $JAVA_PID

echo "JAR file is built at target/$JAR_NAME."
echo "To run it later, use: $JDK17_HOME/bin/java -jar target/$JAR_NAME"
