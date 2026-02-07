FROM node:20-bookworm

# Install dependencies needed for Homebrew
RUN apt-get update && apt-get install -y \
    build-essential \
    procps \
    curl \
    file \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for Homebrew (Homebrew refuses to run as root)
RUN useradd -m -s /bin/bash linuxbrew
RUN mkdir -p /home/linuxbrew/.linuxbrew && chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew

# Install Homebrew as linuxbrew user
USER linuxbrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Switch back to root to set up paths and app
USER root

# Add Homebrew to PATH for all users
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1

# Create app directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the app
COPY . .

EXPOSE 8080

CMD ["npm", "start"]
