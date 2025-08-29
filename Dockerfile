# --- Stage 1: The Builder ---
# Game Plan Step 1 & 2: Use a base image and install only the minimal dependencies needed for the install script.
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS builder

# We add `git`, `sudo`, `curl`, and `wget` as they are all required by the 'urvc' script.
RUN apt-get update && apt-get install -y git sudo curl wget

# Game Plan Step 3: Clone the repo into a /build directory.
WORKDIR /build

# We add ECHO statements to track progress.
RUN echo "--- Cloning Repository ---"
ARG GIT_REF=docker-support
RUN git clone https://github.com/RedsAnalysis/ultimate-rvc.git . && \
    git checkout ${GIT_REF}

# Game Plan Step 4: Run ./urvc install and wait for dirs to pop up.
RUN echo "--- Preparing Installation Script ---"
RUN chmod +x ./urvc


# We correct your command from `... | sh` to the direct execution.
RUN echo "--- Running the Installer, this will take some time... ---"
RUN ./urvc docker
RUN echo "--- Installation Complete. The following directories were created: ---"
RUN ls -ld */

# At the end of this stage, '/build' contains the source code AND the newly created 'uv' and 'models' directories.

# --- Stage 2: The Final, Lean Runtime Image ---
# Game Plan Step 5 & 6: Build the final image and copy over important files.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Set up the final application directory and user.
WORKDIR /app
RUN useradd -ms /bin/bash appuser

# Define environment variables for the application to find its Python environment.
ENV VENV_PATH=/app/uv/.venv
ENV PATH="/app/uv/bin:${VENV_PATH}/bin:${PATH}"
ENV GRADIO_SERVER_NAME="0.0.0.0"

# Game Plan Step 7: Copy over the important files and directories.
RUN echo "--- Copying Artifacts from Builder Stage ---"
# Copy the Python virtual environment created by the installer.
COPY --from=builder /build/uv /app/uv
# Copy the core AI models downloaded by the installer.
COPY --from=builder /build/models /app/models
# Copy the application source code itself.
COPY --from=builder /build/src /app/src
RUN echo "--- Artifacts Copied ---"

# Set correct ownership for the app files so our non-root user can use them.
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 7860

# The final command to start the web server. We use the absolute path to Python for maximum reliability.
CMD ["/app/uv/.venv/bin/python", "-m", "src.ultimate_rvc.web.main"]