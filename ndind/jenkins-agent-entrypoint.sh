#!/bin/bash
set -euo pipefail

curl -fsSO "${JENKINS_URL}/jnlpJars/agent.jar"

exec java -jar agent.jar \
	-url "${JENKINS_URL}" \
	-secret "${AGENT_SECRET}" \
	-name "${AGENT_NAME}" \
	-webSocket \
	-workDir "${AGENT_WORKDIR}"
