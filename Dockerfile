
# --- Stage 1: The Builder (uses the project's own setup script) ---
# We use a 'devel' image which contains all the necessary build tools.
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS builder

# The urvc.sh script uses 'sudo', so we need to install it.
RUN apt-get update && apt-get install -y sudo curl

# Set the working directory for the build.
WORKDIR /app

# Copy the entire project into the builder stage.
COPY . .

# Make the installation script executable.
RUN chmod +x ./urvc

# ... (adapt the script)
RUN sed -i '/install_cuda_128/d' ./urvc
RUN sed -i '/install_distro_specifics/d' ./urvc

# ... (run the installer)
RUN ./urvc install

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
