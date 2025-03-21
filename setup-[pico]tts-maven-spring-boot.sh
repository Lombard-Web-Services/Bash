#!/bin/bash
# By Thibaut LOMBARD (Lombard Web)
# PicoTTS version of Spring Boot TTS web app with PostgreSQL and pico2wave

# Variables
PROJECT_DIR="tts-app"
PACKAGE_DIR="src/main/java/com/example"
RESOURCES_DIR="src/main/resources"
STATIC_DIR="src/main/resources/static"
PG_USER="postgres"
PG_DB="ttsdb"
PG_PASSWORD="your_password_here" # Replace with your actual PostgreSQL password
JAR_NAME="tts-app-0.0.1-SNAPSHOT.jar"
JDK17_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

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

# Tool check function
check_tool() {
 local tool=$1
 local install_cmd=$2
 local var_name=$3

 PATH_VAR=$(which "$tool")
 if [ -z "$PATH_VAR" ]; then
  echo "$tool not found. Installing..."
  sudo apt update && sudo apt install -y "$install_cmd"
  PATH_VAR=$(which "$tool")
  if [ -z "$PATH_VAR" ]; then
   echo "Failed to install $tool. Please install it: sudo apt install $install_cmd"
   exit 1
  fi
 fi
 echo "$tool found at $PATH_VAR"
 eval "$var_name=$PATH_VAR"
}

# Check tools
check_tool "mvn" "maven" "MVN_PATH"
check_tool "psql" "postgresql" "PSQL_PATH"

# Install pico2wave
echo "Installing pico2wave..."
sudo apt update && sudo apt install -y libttspico-utils
if ! command -v pico2wave &> /dev/null; then
 echo "Failed to install pico2wave. Please install manually: sudo apt install libttspico-utils"
 exit 1
fi
echo "pico2wave installed successfully."

# Clear Maven cache
echo "Clearing Maven cache for Spring and Hibernate dependencies..."
rm -rf ~/.m2/repository/org/springframework
rm -rf ~/.m2/repository/org/hibernate
rm -rf ~/.m2/repository/org/springframework/data
wait

# Create project directory structure
echo "Creating directory structure..."
mkdir -p "$PROJECT_DIR/$PACKAGE_DIR/entity" \
   "$PROJECT_DIR/$PACKAGE_DIR/repository" \
   "$PROJECT_DIR/$PACKAGE_DIR/controller" \
   "$PROJECT_DIR/$RESOURCES_DIR" \
   "$PROJECT_DIR/$STATIC_DIR" \
   "$PROJECT_DIR/tts-audio" # New directory for audio files
wait

cd "$PROJECT_DIR" || exit

# Create pom.xml
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
  <dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-web</artifactId>
  </dependency>
  <dependency>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-data-jpa</artifactId>
  </dependency>
  <dependency>
   <groupId>org.postgresql</groupId>
   <artifactId>postgresql</artifactId>
   <version>42.7.3</version>
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
server.port=8080
EOF
wait

# Create index.html with updated audio handling
echo "Creating index.html..."
cat > "$STATIC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
 <meta charset="UTF-8">
 <title>TTS App</title>
</head>
<body>
 <h1>Text-to-Speech en Français</h1>
 <input type="text" id="textInput" placeholder="Entrez du texte ici">
 <button onclick="speak()">Parler</button>
 <audio id="audioPlayer" controls></audio>

 <script>
  function speak() {
   const text = document.getElementById("textInput").value;
   fetch('/speak', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: text })
   })
   .then(response => response.text())
   .then(audioUrl => {
    console.log("Received audio URL:", audioUrl);
    const audioPlayer = document.getElementById("audioPlayer");
    audioPlayer.src = audioUrl; // Use the dynamic /audio/ endpoint
    audioPlayer.play();
   })
   .catch(error => console.error('Error:', error));
  }
 </script>
</body>
</html>
EOF
wait

# Create TtsApp.java
echo "Creating TtsApp.java..."
cat > "$PACKAGE_DIR/TtsApp.java" << 'EOF'
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TtsApp {

 public static void main(String[] args) {
  SpringApplication.run(TtsApp.class, args);
 }
}
EOF
wait

# Create TtsController.java with dynamic audio serving
echo "Creating TtsController.java..."
cat > "$PACKAGE_DIR/controller/TtsController.java" << 'EOF'
package com.example.controller;

import com.example.entity.SpeechLog;
import com.example.repository.SpeechLogRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@RestController
public class TtsController {

 private final SpeechLogRepository speechLogRepository;
 private static final String AUDIO_DIR = "tts-audio"; // New folder for storing audio

 @Autowired
 public TtsController(SpeechLogRepository speechLogRepository) {
  this.speechLogRepository = speechLogRepository;
  new File(AUDIO_DIR).mkdirs(); // Ensure the directory exists
 }

 @PostMapping("/speak")
 public String speak(@RequestBody SpeechRequest request) {
  String text = request.getText();
  String filename = UUID.randomUUID() + ".wav";
  String filepath = AUDIO_DIR + "/" + filename;

  // Run pico2wave
  ProcessBuilder processBuilder = new ProcessBuilder("pico2wave", "-w", filepath, text);
  try {
   Process process = processBuilder.start();
   process.waitFor();

   // Check if the file exists
   File audioFile = new File(filepath);
   if (!audioFile.exists() || audioFile.length() == 0) {
    return "Error: Failed to generate speech";
   }

   // Save log in database
   SpeechLog log = new SpeechLog(text);
   speechLogRepository.save(log);

   // Return the correct URL
   return "/audio/" + filename;
  } catch (IOException | InterruptedException e) {
   e.printStackTrace();
   return "Error: " + e.getMessage();
  }
 }

 // Serve the audio file dynamically
 @GetMapping("/audio/{filename}")
 public ResponseEntity<Resource> getAudio(@PathVariable String filename) {
  try {
   Path filePath = Paths.get(AUDIO_DIR).resolve(filename).normalize();
   Resource resource = new UrlResource(filePath.toUri());

   if (resource.exists()) {
    return ResponseEntity.ok()
      .contentType(MediaType.parseMediaType("audio/wav"))
      .body(resource);
   } else {
    return ResponseEntity.notFound().build();
   }
  } catch (MalformedURLException e) {
   return ResponseEntity.badRequest().build();
  }
 }
}

class SpeechRequest {
 private String text;

 public String getText() { return text; }
 public void setText(String text) { this.text = text; }
}
EOF
wait

# Create SpeechLog.java
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

# Build the project
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

# Run the JAR
echo "Running the JAR file with JDK 17..."
"$JDK17_HOME/bin/java" -jar "target/$JAR_NAME" &
JAVA_PID=$!
wait $JAVA_PID

echo "JAR file is built at target/$JAR_NAME."
echo "Access the app at http://localhost:8080"
echo "Using system-installed pico2wave for TTS."
echo "Audio files served from tts-audio/ directory."
echo "To run it later, use: $JDK17_HOME/bin/java -jar target/$JAR_NAME"
