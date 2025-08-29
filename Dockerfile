<<<<<<< HEAD
# Use NVIDIA CUDA base image for GPU support
FROM nvidia/cuda:12.5.1-runtime-ubuntu24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    unzip \
    python3-pip \
    python3-venv \
    git \
    ffmpeg \
    sox \
    libsox-dev \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app


# Set up UV environment variables
ENV UV_PATH=./uv
ENV VENV_PATH=$UV_PATH/.venv

ENV UV_UNMANAGED_INSTALL=$UV_PATH
ENV UV_PYTHON_INSTALL_DIR="$UV_PATH/python"
ENV UV_PYTHON_BIN_DIR="$UV_PATH/python/bin"
ENV VIRTUAL_ENV=$VENV_PATH
ENV UV_PROJECT_ENVIRONMENT=$VENV_PATH
ENV UV_TOOL_DIR="$UV_PATH/tools"
ENV UV_TOOL_BIN_DIR="$UV_PATH/tools/bin"
ENV GRADIO_NODE_PATH="$VENV_PATH/lib/python3.12/site-packages/nodejs_wheel/bin/node"
ENV PATH="$UV_PATH:$PATH"

RUN curl -LsSf https://astral.sh/uv/0.6.3/install.sh | UV_ROOT=$UV_PATH sh 

# Copy project files
COPY . /app/

# Install dependencies using uv with full path
RUN uv run ./src/ultimate_rvc/core/main.py

# Expose port for web interface
EXPOSE 7865

# Set default command to run the web interface
CMD ["uv","run", "./src/ultimate_rvc/web/main.py"]
=======
# --- Stage 1: The Builder (uses the project's own setup script) ---
# We use a 'devel' image which contains all the necessary build tools.
FROM nnvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS builder

# The urvc.sh script uses 'sudo', so we need to install it.
RUN apt-get update && apt-get install -y sudo curl

# Set the working directory for the build.
WORKDIR /app

# Copy the entire project into the builder stage.
COPY . .

# Make the installation script executable.
RUN chmod +x ./urvc.sh

# --- A critical step: We adapt the script for a container environment ---
# The nvidia base image already provides CUDA. The script's attempt to install it
# will fail. We use 'sed' to safely remove the lines that call the CUDA
# and distro-specific installation functions.
RUN sed -i '/install_cuda_128/d' ./urvc.sh
RUN sed -i '/install_distro_specifics/d' ./urvc.sh

# Run the install command from the script.
# This will create the './uv' directory with the python virtual environment
# and download the core application models.
RUN ./urvc.sh install

# At the end of this stage, the builder has a complete, working installation
# located in /app, including the venv and the core models.

# --- Stage 2: The Final, Lean Runtime Image ---
# We switch to a smaller 'runtime' image which doesn't have build tools.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Set environment variables needed for the app to run.
ENV VENV_PATH=/app/uv/.venv
ENV PATH="/app/uv/bin:${VENV_PATH}/bin:${PATH}"
ENV GRADIO_SERVER_NAME="0.0.0.0"

# Create a dedicated, non-root user for running the application for security.
RUN useradd -ms /bin/bash appuser
WORKDIR /app

# --- Copy finished artifacts from the builder stage ---
# We meticulously copy ONLY what is needed to run the application.

# Copy the entire 'uv' directory, which contains the uv binary and the Python venv.
COPY --from=builder /app/uv /app/uv
# Copy the downloaded core models (separators, predictors, etc.).
COPY --from=builder /app/models /app/models
# Copy the application source code, which is needed to execute the web UI.
COPY --from=builder /app/src /app/src

# Set the ownership of all application files to our non-root user.
RUN chown -R appuser:appuser /app
USER appuser

# Expose the port the Gradio web UI will listen on.
EXPOSE 7860

# The command to run when the container starts.
# This executes the web UI using the python from our copied virtual environment.
CMD ["python", "-m", "src.ultimate_rvc.web.main"]
>>>>>>> a362291 (Added docker-file , Testing is pending)
