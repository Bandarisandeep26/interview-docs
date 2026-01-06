#!/bin/bash

echo "Generate your Custom Dockerfile!"

read -p "Enter the Dockerfile name (e.g., MyDockerfile): " dockerfile_name

# Create the file in the current directory
touch "$dockerfile_name"
read -p "Enter base image (e.g., ubuntu, python:3.9-slim): " BASE_IMAGE
echo FROM $BASE_IMAGE > "$dockerfile_name"

# Metadata
read -p "Enter maintainer email: " maintainer
read -p "Enter version: " version
read -p "Enter description: " description

echo "LABEL maintainer=\"$maintainer\"" >> "$dockerfile_name"
echo "LABEL version=\"$version\"" >> "$dockerfile_name"
echo "LABEL description=\"$description\"" >> "$dockerfile_name"

# Environment variables
read -p "Do you want to add environment variables? (y/n): " add_env
if [ "$add_env" == "y" ]; then
    while true; do
        read -p "Enter ENV variable (key=value) or type 'done' to finish: " env_var
        if [ "$env_var" == "done" ]; then
            break
        fi
        echo "ENV $env_var" >> "$dockerfile_name"
    done
fi

# Non-root user
read -p "Do you want to create a non-root user? (y/n): " non_root
if [ "$non_root" == "y" ]; then
    read -p "Enter the non-root user name: " non_root_user
    echo "RUN adduser -D $non_root_user" >> "$dockerfile_name"
    echo "USER $non_root_user" >> "$dockerfile_name"
fi



# Working directory
read -p "Enter the working directory inside the container: " workdir
echo "WORKDIR $workdir" >> "$dockerfile_name"

# Copy files from build context command
echo "COPY . .$workdir " >> "$dockerfile_name"

# Add Files to Dockerfile
read -p "Do you want to copy files from a specific paths to the container? (y/n): " copy_files
if [ "$copy_files" == "y" ]; then
    while true; do
        read -p "Enter source path (local file path) (or type 'done' to finish): " src
        if [ "$src" == "done" ]; then
            break
        fi
        read -p "Enter destination path inside the container: " dest
        echo "COPY $src $dest" >> "$dockerfile_name"
    done
fi


#install packages

detect_package_manager() {
    local image="$1"
    if [[ "$image" == *"ubuntu"* || "$image" == *"debian"* ]]; then
        echo "apt"
    elif [[ "$image" == *"centos"* || "$image" == *"rhel"* || "$image" == *"redhat"* ]]; then
        echo "yum"
    elif [[ "$image" == *"fedora"* ]]; then
        echo "dnf"
    elif [[ "$image" == *"alpine"* ]]; then
        echo "apk"
    else
        echo "apt"  # fallback to apt for general use
    fi
}

PKG_MANAGER=$(detect_package_manager "$BASE_IMAGE")

case $PKG_MANAGER in
    apt)
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
        ;;
    yum)
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
        ;;
    dnf)
        PKG_UPDATE="dnf -y update"
        PKG_INSTALL="dnf install -y"
        ;;
    apk)
        PKG_UPDATE="apk update"
        PKG_INSTALL="apk add --no-cache"
        ;;
    *)
        echo "Unknown package manager. Exiting."
        exit 1
        ;;
esac

echo "Detected package manager: $PKG_MANAGER"
echo "Update command: $PKG_UPDATE"
echo "Install command: $PKG_INSTALL"


read -p "Do you want to install any packages? (y/n): " packages
if [ "$packages" == "y" ]; then
   read -p "Enter packages to install (space-separated): " PACKAGES
    echo "RUN $PKG_UPDATE && $PKG_INSTALL $PACKAGES" >> "$dockerfile_name"
fi


# Expose a port
read -p "Do you want to expose a port? (y/n): " expose
if [ "$expose" == "y" ]; then
    read -p "Enter the port number to expose: " port
    echo "EXPOSE $port" >> "$dockerfile_name"
fi

# Health check
read -p "Do you want to add a health check? (y/n): " healthcheck
if [ "$healthcheck" == "y" ]; then
    read -p "Enter the command for the health check: " hc_cmd
    echo "HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\" >> "$dockerfile_name"
    echo "  CMD $hc_cmd || exit 1" >> "$dockerfile_name"
fi

# CMD
read -p "Do you want to run command on startup? (y/n): " command
if [ "$command" == "y" ]; then
   read -p "Enter the CMD instruction: " cmd
   echo "CMD [\"${cmd// /\", \"}\"]" >> "$dockerfile_name"
fi


read -p "Do you want to add an existing entrypoint.sh script? (y/n): " ADD_ENTRYPOINT
if [[ "$ADD_ENTRYPOINT" == "y" ]]; then
    read -p "Enter the path to your existing entrypoint.sh file: " ENTRYPOINT_PATH

    ENTRYPOINT_FILE=$(basename "$ENTRYPOINT_PATH")

    # Add COPY and ENTRYPOINT to Dockerfile
    echo "COPY $ENTRYPOINT_PATH /usr/local/bin/$ENTRYPOINT_FILE" >> "$dockerfile_name"
    echo "RUN chmod +x /usr/local/bin/$ENTRYPOINT_FILE" >> "$dockerfile_name"
    echo "ENTRYPOINT [\"/usr/local/bin/$ENTRYPOINT_FILE\"]" >> "$dockerfile_name"

    echo "Added entrypoint from $ENTRYPOINT_PATH to $dockerfile_name"
fi


echo "Your Dockerfile '$dockerfile_name' has been created with your custom configuration."
