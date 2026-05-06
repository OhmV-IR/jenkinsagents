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
								bat "docker tag jenkins-agent-linux:latest registry.bgfamily.ca/jenkins-agent-linux:latest"
								bat "docker push registry.bgfamily.ca/jenkins-agent-linux:latest"
								bat "docker tag jenkins-agent-linux:latest ohmivr/jenkins-agent-linux:latest"
								bat "docker push ohmivr/jenkins-agent-linux:latest"
							} else {
								sh "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile linux"
								sh "docker tag jenkins-agent-linux:latest registry.bgfamily.ca/jenkins-agent-linux:latest"
								sh "docker push registry.bgfamily.ca/jenkins-agent-linux:latest"
								sh "docker tag jenkins-agent-linux:latest ohmivr/jenkins-agent-linux:latest"
								sh "docker push ohmivr/jenkins-agent-linux:latest"
							}
						}
					}
				}
				stage("Build linux arm64 docker image"){
					agent { label 'docker-linux' }
					steps {
						checkout scm
						if(!isUnix()){
							bat "docker buildx build --platform linux/arm64 -t jenkins-agent-linux-arm64:latest --load -f linux/Dockerfile linux"
							bat "docker tag jenkins-agent-linux-arm64:latest registry.bgfamily.ca/jenkins-agent-linux-arm64:latest"
							bat "docker push registry.bgfamily.ca/jenkins-agent-linux-arm64:latest"
							bat "docker tag jenkins-agent-linux-arm64:latest ohmivr/jenkins-agent-linux-arm64:latest"
							bat "docker push ohmivr/jenkins-agent-linux-arm64:latest"
						} else {
							sh "docker buildx build --platform linux/arm64 -t jenkins-agent-linux-arm64:latest --load -f linux/Dockerfile linux"
							sh "docker tag jenkins-agent-linux-arm64:latest registry.bgfamily.ca/jenkins-agent-linux-arm64:latest"
							sh "docker push registry.bgfamily.ca/jenkins-agent-linux-arm64:latest"
							sh "docker tag jenkins-agent-linux-arm64:latest ohmivr/jenkins-agent-linux-arm64:latest"
							sh "docker push ohmivr/jenkins-agent-linux-arm64:latest"
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
								bat "docker tag jenkins-agent-windows:latest ohmivr/jenkins-agent-windows:latest"
								bat "docker push ohmivr/jenkins-agent-windows:latest"
							} else {
								sh "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile windows"
								sh "docker tag jenkins-agent-windows:latest ohmivr/jenkins-agent-windows:latest"
								sh "docker push ohmivr/jenkins-agent-windows:latest"
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
								bat "docker tag jenkins-controller:latest registry.bgfamily.ca/jenkins-controller:latest"
								bat "docker push registry.bgfamily.ca/jenkins-controller:latest"
								bat "docker tag jenkins-controller:latest ohmivr/jenkins-controller:latest"
								bat "docker push ohmivr/jenkins-controller:latest"
							} else {
								sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
								sh "docker tag jenkins-controller:latest registry.bgfamily.ca/jenkins-controller:latest"
								sh "docker push registry.bgfamily.ca/jenkins-controller:latest"
								sh "docker tag jenkins-controller:latest ohmivr/jenkins-controller:latest"
								sh "docker push ohmivr/jenkins-controller:latest"
							}
						}
					}
				}
			}
		}
	}
}
