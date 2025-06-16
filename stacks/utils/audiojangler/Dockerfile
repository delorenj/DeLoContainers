# Start from a Python base image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Install ffmpeg and other system dependencies required by moviepy
# libsm6 and libxext6 are often needed for OpenCV, which moviepy can use indirectly
RUN apt-get update && \
  apt-get install -y ffmpeg libsm6 libxext6 && \
  rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application script into the container
COPY audiojangler.py .

# Define the entrypoint for the container
ENTRYPOINT ["python", "audiojangler.py"]

# Default command (can be overridden) - provides help message if no args given
CMD ["--help"]

