FROM jenkins-agent-linux:latest

USER root
RUN apt install -y util-linux-extra
RUN usermod -aG docker jenkins
RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    iproute2 \
    kmod \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/docker && \
    echo '{"insecure-registries": ["registry.bgfamily.ca"]}' > /etc/docker/daemon.json
COPY dind-entrypoint.sh /usr/local/bin/dind-entrypoint.sh
RUN chmod +x /usr/local/bin/dind-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/dind-entrypoint.sh"]
CMD ["sh", "-c", "curl -O ${JENKINS_URL}/jnlpJars/agent.jar && java -jar agent.jar -url ${JENKINS_URL} -secret ${AGENT_SECRET} -name \"${AGENT_NAME}\" -webSocket -workDir \"${AGENT_WORKDIR}\""]
