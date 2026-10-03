#!/bin/bash
set -euo pipefail

start-docker.sh

for _ in $(seq 1 30); do
	docker info >/dev/null 2>&1 && break
	sleep 1
done
docker info >/dev/null 2>&1 || { echo "inner dockerd failed to start" >&2; exit 1 }

curl -fsSO "${JENKINS_URL}/jnlpJars/agent.jar"

exec java -jar agent.jar \
	-url "${JENKINS_URL}" \
	-secret "${AGENT_SECRET}" \
	-name "${AGENT_NAME}" \
	-webSocket \
	-workDir "${AGENT_WORKDIR}"
