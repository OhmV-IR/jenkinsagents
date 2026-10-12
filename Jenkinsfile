pipeline {
    agent none
    stages {
        stage("Build docker images"){
            parallel {
                stage("Build linux docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh 'echo "$REG_PASS" | docker login "$PULL_REGISTRY" -u "$REG_USER" --password-stdin'
                            sh 'docker build --build-arg ESP_IDF_IMAGE="$PULL_REGISTRY/esp-idf-linux:latest" --build-arg UE_ENGINE_IMAGE="$PULL_REGISTRY/unreal-engine-linux:$UE_GIT_TAG" -t jenkins-agent-linux:latest -f linux/Dockerfile linux'
                            sh "docker tag jenkins-agent-linux:latest localhost:5000/jenkins-agent-linux:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux:latest"
                            
                            sh "docker build -t jenkins-agent-linux-ndind:latest -f ndind/Dockerfile ndind"
                            sh "docker tag jenkins-agent-linux-ndind:latest localhost:5000/jenkins-agent-linux-ndind:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux-ndind:latest"
                            sh 'docker logout localhost:5000'
                            sh 'docker logout "$PULL_REGISTRY"'
                        }
                    }
                }
                stage("Build p4 image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh "docker build -t p4-server:latest -f p4/Dockerfile p4"
                            sh "docker tag p4-server:latest localhost:5000/p4-server:latest"
                            sh "docker push localhost:5000/p4-server:latest"
                            sh 'docker logout localhost:5000'
                        }
                    }
                }
                stage("Build windows docker image"){
					agent { label 'docker-windows' }
					steps {
						checkout scm
						withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
							bat 'echo %REG_PASS%| docker login localhost:5000 -u "%REG_USER%" --password-stdin'
							bat 'echo %REG_PASS%| docker login %PULL_REGISTRY% -u "%REG_USER%" --password-stdin'
							bat 'docker build --build-arg ESP_IDF_IMAGE=%PULL_REGISTRY%/esp-idf-windows:latest --build-arg UE_ENGINE_IMAGE=%PULL_REGISTRY%/unreal-engine-windows:%UE_GIT_TAG% -t jenkins-agent-windows:latest -f windows/Dockerfile windows'
							bat "docker tag jenkins-agent-windows:latest localhost:5000/jenkins-agent-windows:latest"
							bat "docker push localhost:5000/jenkins-agent-windows:latest"
							bat 'docker logout localhost:5000'
							bat 'docker logout %PULL_REGISTRY%'
						}
					}
				}
                stage("Build controller docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
                            sh "docker tag jenkins-controller:latest localhost:5000/jenkins-controller:latest"
                            sh "docker push localhost:5000/jenkins-controller:latest"
                            sh 'docker logout localhost:5000'
                        }
                    }
                }
                stage("Build backrest image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh "docker build -t backrest:latest -f backrest/Dockerfile backrest"
                            sh "docker tag backrest:latest localhost:5000/backrest:latest"
                            sh "docker push localhost:5000/backrest:latest"
                            sh 'docker logout localhost:5000'
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            node('docker-linux'){
                sh 'docker system prune -a -f'
            }
            node('docker-windows'){
                bat 'docker system prune -a -f'
            }
        }
    }
}
