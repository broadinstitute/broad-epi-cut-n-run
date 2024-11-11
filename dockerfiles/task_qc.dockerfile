# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install dependencies
RUN apt-get update && \
    apt-get install -y samtools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the plot script into the container at /usr/local/bin/
COPY src/python/plot_fragment_size_distribution.py /usr/local/bin/plot_fragment_size_distribution.py

# Install matplotlib
RUN pip install --no-cache-dir matplotlib

# Make the plot script executable
RUN chmod +x /usr/local/bin/plot_fragment_size_distribution.py
