FROM bandi13/docker-obs

# Set environment variables for VNC password
ENV VNC_PASSWD=123456
ENV SHARED_DIR=/shared

# Create a shared directory inside the container
RUN mkdir -p ${SHARED_DIR} && chmod -R 777 ${SHARED_DIR}

# Keep the container alive with a dummy loop
CMD ["bash", "-c", "while :; do sleep 30; done"]
