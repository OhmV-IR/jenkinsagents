FROM jenkins-agent-linux:latest

COPY --chmod=0755 jenkins-agent-entrypoint.sh /home/jenkins/jenkins-agent-entrypoint.sh
ENTRYPOINT ["/home/jenkins/jenkins-agent-entrypoint.sh"]
