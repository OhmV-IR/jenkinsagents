pipeline {
	agent none
	stages {
		stage("Build docker images"){
			parallel {
				stage("Build linux docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						sh "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile linux"
						sh "docker tag jenkins-agent-linux:latest registry.bgfamily.ca/jenkins-agent-linux:latest"
						sh "docker push registry.bgfamily.ca/jenkins-agent-linux:latest"
					}
				}
				stage("Build linux-dind docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						sh "docker build -t jenkins-agent-linux-dind:latest -f linux-dind/Dockerfile linux-dind"
						sh "docker tag jenkins-agent-linux-dind:latest registry.bgfamily.ca/jenkins-agent-linux-dind:latest"
						sh "docker push registry.bgfamily.ca/jenkins-agent-linux-dind:latest"
					}
				}
				stage("Build windows docker image"){
					agent { label 'docker-windows' }
					steps {
						checkout scm
						bat "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile windows"
					}
				}
				stage("Build controller docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
						sh "docker tag jenkins-controller:latest registry.bgfamily.ca/jenkins-controller:latest"
						sh "docker push registry.bgfamily.ca/jenkins-controller:latest"
					}
				}
			}
		}
	}
}
