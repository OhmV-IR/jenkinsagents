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
								bat "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile linux"
								bat "docker save jenkins-agent-linux:latest -o jenkins-agent-linux.tar"
								archiveArtifacts artifacts: 'jenkins-agent-linux.tar', fingerprint: true
								bat "del jenkins-agent-linux.tar"
								bat "docker tag jenkins-agent-linux:latest registry.bgfamily.ca/jenkins-agent-linux:latest"
								bat "docker push registry.bgfamily.ca/jenkins-agent-linux:latest"
							} else {
								sh "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile linux"
								sh "docker save jenkins-agent-linux:latest -o jenkins-agent-linux.tar"
								archiveArtifacts artifacts: 'jenkins-agent-linux.tar', fingerprint: true
								sh "rm jenkins-agent-linux.tar"
								sh "docker tag jenkins-agent-linux:latest registry.bgfamily.ca/jenkins-agent-linux:latest"
								sh "docker push registry.bgfamily.ca/jenkins-agent-linux:latest"
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
								bat "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile windows"
								bat "docker save jenkins-agent-windows:latest -o jenkins-agent-windows.tar"
								archiveArtifacts artifacts: 'jenkins-agent-windows.tar', fingerprint: true
								bat "del jenkins-agent-windows.tar"
								bat "docker tag jenkins-agent-windows:latest registry.bgfamily.ca/jenkins-agent-windows:latest"
								bat "docker push registry.bgfamily.ca/jenkins-agent-windows:latest"
							} else {
								sh "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile windows"
								sh "docker save jenkins-agent-windows:latest -o jenkins-agent-windows.tar"
								archiveArtifacts artifacts: 'jenkins-agent-windows.tar', fingerprint: true
								sh "rm jenkins-agent-windows.tar"
								sh "docker tag jenkins-agent-windows:latest registry.bgfamily.ca/jenkins-agent-windows:latest"
								sh "docker push registry.bgfamily.ca/jenkins-agent-windows:latest"
							}
						}
					}
				}
				stage("Build controller docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						script {
							if(!isUnix()){
								bat "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
								bat "docker save jenkins-controller:latest -o jenkins-controller.tar"
								archiveArtifacts artifacts: 'jenkins-controller.tar', fingerprint: true
								bat "del jenkins-controller.tar"
								bat "docker tag jenkins-controller:latest registry.bgfamily.ca/jenkins-controller:latest"
								bat "docker push registry.bgfamily.ca/jenkins-controller:latest"
							} else {
								sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
								sh "docker save jenkins-controller:latest -o jenkins-controller.tar"
								archiveArtifacts artifacts: 'jenkins-controller.tar', fingerprint: true
								sh "rm jenkins-controller.tar"
								sh "docker tag jenkins-controller:latest registry.bgfamily.ca/jenkins-controller:latest"
								sh "docker push registry.bgfamily.ca/jenkins-controller:latest"
							}
						}
					}
				}
			}
		}
	}
}
