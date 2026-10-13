#!/bin/bash
# Entrypoint of the jenkins-agent-linux and jenkins-agent-linux-ndind images.
#   START_DOCKERD=1  start the inner dockerd first (docker-in-docker, jenkins-agent-linux)
#   START_DOCKERD=0  use the docker daemon whose socket is mounted in (jenkins-agent-linux-ndind)
set -euo pipefail

if [ "${START_DOCKERD:-1}" = "1" ]; then
	sudo start-docker.sh

	for _ in $(seq 1 30); do
		docker info >/dev/null 2>&1 && break
		sleep 1
	done
	docker info >/dev/null 2>&1 || { echo "inner dockerd failed to start" >&2; exit 1; }
fi

agent_jar="${HOME}/agent.jar"
curl -fsS --retry 10 --retry-delay 5 --retry-all-errors -o "${agent_jar}" "${JENKINS_URL}/jnlpJars/agent.jar"

exec "${AGENT_JAVA:-java}" -jar "${agent_jar}" \
	-url "${JENKINS_URL}" \
	-secret "${AGENT_SECRET}" \
	-name "${AGENT_NAME}" \
	-webSocket \
	-workDir "${AGENT_WORKDIR}"
