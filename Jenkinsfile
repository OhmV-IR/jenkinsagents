pipeline {
	agent none
	stages {
		stage("Build docker images"){
			parallel {
				stage("Build linux docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						script {
							if(!isUnix()){
								bat "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile ."
								bat "docker save jenkins-agent-linux:latest -o jenkins-agent-linux.tar"
								archiveArtifacts artifacts: 'jenkins-agent-linux.tar', fingerprint: true
								bat "del jenkins-agent-linux.tar"
							} else {
								sh "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile ."
								sh "docker save jenkins-agent-linux:latest -o jenkins-agent-linux.tar"
								archiveArtifacts artifacts: 'jenkins-agent-linux.tar', fingerprint: true
								sh "rm jenkins-agent-linux.tar"
							}
						}
					}
				}
				stage("Build windows docker image"){
					agent { label 'docker-windows' }
					steps {
						checkout scm
						script {
							if(!isUnix()){
								bat "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile ."
								bat "docker save jenkins-agent-windows:latest -o jenkins-agent-windows.tar"
								archiveArtifacts artifacts: 'jenkins-agent-windows.tar', fingerprint: true
								bat "del jenkins-agent-windows.tar"
							} else {
								sh "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile ."
								sh "docker save jenkins-agent-windows:latest -o jenkins-agent-windows.tar"
								archiveArtifacts artifacts: 'jenkins-agent-windows.tar', fingerprint: true
								sh "rm jenkins-agent-windows.tar"
							}
						}
					}
				}
			}
		}
	}
}
