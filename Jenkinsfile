pipeline {
    agent none
    stages {
        stage("Build docker images"){
            parallel {
                stage("Build linux docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        docker.withRegistry('http://localhost:5000', 'docker_server_priv_registry') {
                            sh "docker build -t jenkins-agent-linux:latest -f linux/Dockerfile linux"
                            sh "docker tag jenkins-agent-linux:latest localhost:5000/jenkins-agent-linux:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux:latest"
                            sh "docker build -t jenkins-agent-linux-dind:latest -f linux-dind/Dockerfile linux-dind"
                            sh "docker tag jenkins-agent-linux-dind:latest localhost:5000/jenkins-agent-linux-dind:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux-dind:latest"
                        }
                    }
                }
                stage("Build p4 image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        docker.withRegistry('http://localhost:5000', 'docker_server_priv_registry') {
                            sh "docker build -t p4-server:latest -f p4/Dockerfile p4"
                            sh "docker tag p4-server:latest localhost:5000/p4-server:latest"
                            sh "docker push localhost:5000/p4-server:latest"
                        }
                    }
                }
                stage("Build windows docker image"){
                    agent { label 'docker-windows' }
                    steps {
                        checkout scm
                        docker.withRegistry('http://localhost:5000', 'docker_server_priv_registry') {
                            bat "docker build -t jenkins-agent-windows:latest -f windows/Dockerfile windows"
                            bat "docker tag jenkins-agent-windows:latest localhost:5000/jenkins-agent-windows:latest"
                            bat "docker push localhost:5000/jenkins-agent-windows:latest"
                        }
                    }
                }
                stage("Build controller docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        docker.withRegistry('http://localhost:5000', 'docker_server_priv_registry') {
                            sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
                            sh "docker tag jenkins-controller:latest localhost:5000/jenkins-controller:latest"
                            sh "docker push localhost:5000/jenkins-controller:latest"
                        }
                    }
                }
            }
        }
    }
}