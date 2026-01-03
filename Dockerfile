# Stage 1: Use a Java base image (Minecraft servers require Java)
FROM openjdk:17-jdk-slim

# Set the working directory inside the container
WORKDIR /server

# Copy all files from your GitHub repository root into the container's /server directory
# This includes your run.sh, server JAR, eula.txt, server.properties, etc.
COPY . .

# Grant execution permissions to your startup script
RUN chmod +x ./run.sh

# The Eaglercraft server requires exposing two ports:
# 25565: Standard Minecraft port (often used by the server JAR itself)
# 8081: Common port for the Eaglercraft WebSocket connection
EXPOSE 25565
EXPOSE 8081
EXPOSE 8080 # Some setups use 8080 for web-serving the client

# Ensure EULA is accepted to prevent the server from failing to start
# This step assumes your server.properties and eula.txt are in the root directory
# If eula.txt doesn't exist, this creates it.
RUN echo "eula=true" > eula.txt

# Command to run the server. This uses your existing run.sh script.
# The 'exec' command ensures signals (like SIGTERM from Render) are properly handled.
CMD ["/bin/bash", "./run.sh"]