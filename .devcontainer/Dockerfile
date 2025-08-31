FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install Flutter dependencies.
# The base image has a non-root user 'vscode' with passwordless sudo.
RUN sudo apt-get update && sudo apt-get install -y \
    git \
    curl \
    unzip \
    xz-utils \
    libglu1-mesa

# Clone the Flutter repository.
# The 'vscode' user has write permissions to /usr/local in the base image.
RUN git clone https://github.com/flutter/flutter.git /home/vscode/flutter 

# Add Flutter to the PATH for all subsequent commands and terminals.
ENV PATH="/home/vscode/flutter/bin:${PATH}"

# Grant write access to the flutter directory
RUN sudo chown -R vscode:vscode /home/vscode/flutter