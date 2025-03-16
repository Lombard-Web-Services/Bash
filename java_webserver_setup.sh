#!/bin/bash
# By thibaut LOMBARD (Lombard Web)
# Script to Create a java webserver listening on port 8080 from scratch
set -e

# Function to check and install dependencies
install_dependencies() {
    echo "Checking dependencies..."
    if ! command -v java &> /dev/null; then
        echo "Java not found. Installing Java (JDK 17)..."
        sudo apt update
        sudo apt install -y openjdk-17-jdk
    else
        echo "Java is already installed."
    fi
    if ! command -v mvn &> /dev/null; then
        echo "Maven not found. Installing Maven..."
        sudo apt install -y maven
    else
        echo "Maven is already installed."
    fi
    if ! command -v curl &> /dev/null; then
        echo "curl not found. Installing curl..."
        sudo apt install -y curl
    else
        echo "curl is already installed."
    fi
}

# Function to check and fix network connectivity
check_network() {
    echo "Checking DNS resolution with local resolver..."
    if ! nslookup repo.maven.apache.org &> /dev/null; then
        echo "Local DNS resolution failed. Checking with Google DNS..."
        if ! nslookup repo.maven.apache.org 8.8.8.8 &> /dev/null; then
            echo "Error: Even Google DNS (8.8.8.8) cannot resolve repo.maven.apache.org. Check your internet connection."
            exit 1
        fi
        echo "Google DNS works. Disabling systemd-resolved and forcing Google DNS..."
        sudo systemctl disable --now systemd-resolved || true
        sudo rm -f /etc/resolv.conf
        echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
        echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
        sudo chattr +i /etc/resolv.conf || true
        sleep 2
        if ! nslookup repo.maven.apache.org &> /dev/null; then
            echo "Error: Still cannot resolve repo.maven.apache.org after DNS fix. Check your network."
            exit 1
        fi
    fi
    echo "DNS resolution works."

    echo "Testing Maven Central access with curl..."
    if ! curl -I https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-starter-parent/3.2.3/spring-boot-starter-parent-3.2.3.pom &> /dev/null; then
        echo "Error: Cannot reach Maven Central (https://repo.maven.apache.org). Check your firewall, proxy, or internet connection."
        exit 1
    fi
    echo "Maven Central is reachable."
}

# Create directory structure
echo "Creating project directory structure..."
mkdir -p src/main/java/com/example/controller
mkdir -p src/main/resources/static

# Generate pom.xml with explicit repository
echo "Generating pom.xml..."
cat << 'EOF' > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>my-web-server</artifactId>
    <version>1.0-SNAPSHOT</version>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.3</version>
    </parent>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
    </dependencies>
    <repositories>
        <repository>
            <id>central</id>
            <url>https://repo.maven.apache.org/maven2</url>
        </repository>
    </repositories>
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Generate MyWebServerApplication.java
echo "Generating MyWebServerApplication.java..."
cat << 'EOF' > src/main/java/com/example/MyWebServerApplication.java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MyWebServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyWebServerApplication.class, args);
    }
}
EOF

# Generate DataController.java
echo "Generating DataController.java..."
cat << 'EOF' > src/main/java/com/example/controller/DataController.java
package com.example.controller;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class DataController {
    @PostMapping("/data")
    public String saveData(@RequestBody String data) {
        return "Saved: " + data;
    }

    @GetMapping("/data")
    public String getData() {
        return "Sample data from server";
    }
}
EOF

# Generate index.html
echo "Generating index.html..."
cat << 'EOF' > src/main/resources/static/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Web Server</title>
</head>
<body>
    <h1>Welcome to My Web Server</h1>
    <input id="dataInput" type="text" placeholder="Enter data">
    <button onclick="sendData()">Send</button>
    <p id="response"></p>
    <script src="script.js"></script>
</body>
</html>
EOF

# Generate script.js
echo "Generating script.js..."
cat << 'EOF' > src/main/resources/static/script.js
function sendData() {
    const input = document.getElementById("dataInput").value;
    fetch('/api/data', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(input)
    })
    .then(response => response.text())
    .then(data => {
        document.getElementById("response").innerText = data;
    })
    .catch(error => console.error('Error:', error));
}
EOF

# Generate application.properties
echo "Generating application.properties..."
cat << 'EOF' > src/main/resources/application.properties
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.h2.console.enabled=true
EOF

# Install dependencies
install_dependencies

# Check network
check_network

# Build the project with retry logic
echo "Building the project with Maven..."
for i in {1..3}; do
    if mvn clean package; then
        break
    else
        echo "Build failed. Retrying ($i/3)..."
        sleep 2
    fi
    if [ $i -eq 3 ]; then
        echo "Error: Failed to build after 3 attempts. Check your network or Maven configuration."
        exit 1
    fi
done

# Run the server
echo "Starting the web server..."
java -jar target/my-web-server-1.0-SNAPSHOT.jar &

# Wait a moment for the server to start
sleep 5

echo "Server is running at http://localhost:8080"
echo "Open your browser to test it!"

# Clean up: Unlock resolv.conf (optional)
sudo chattr -i /etc/resolv.conf || true
