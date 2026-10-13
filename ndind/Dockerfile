FROM jenkins-agent-linux:latest

# Same entrypoint as jenkins-agent-linux, but without starting the inner dockerd: this image talks to
# the host's docker daemon through the mounted /var/run/docker.sock.
ENV START_DOCKERD="0"
