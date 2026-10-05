pipeline {
    agent none
    stages {
        stage("Build docker images"){
            parallel {
                stage("Build linux docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        // unreal_engine_linux_archive_url: Secret text credential holding the URL of Epic's
                        // Linux_Unreal_Engine_<ver>.zip mirror (see docs/unreal-engine.md).
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
                                         string(credentialsId: 'unreal_engine_linux_archive_url', variable: 'UE_ARCHIVE_URL')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh 'docker build --build-arg UE_ARCHIVE_URL="$UE_ARCHIVE_URL" -t jenkins-agent-linux:latest -f linux/Dockerfile linux'
                            sh "docker tag jenkins-agent-linux:latest localhost:5000/jenkins-agent-linux:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux:latest"
                            
                            sh "docker build -t jenkins-agent-linux-ndind:latest -f ndind/Dockerfile ndind"
                            sh "docker tag jenkins-agent-linux-ndind:latest localhost:5000/jenkins-agent-linux-ndind:latest"
                            sh "docker push localhost:5000/jenkins-agent-linux-ndind:latest"
                            sh 'docker logout localhost:5000'
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
						// unreal_engine_windows_archive_url: Secret text credential holding the URL of the zip made
						// by tools/New-UnrealEngineArchive.ps1 (see docs/unreal-engine.md).
						withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
						                 string(credentialsId: 'unreal_engine_windows_archive_url', variable: 'UE_ARCHIVE_URL')]) {
							bat 'echo %REG_PASS%| docker login localhost:5000 -u "%REG_USER%" --password-stdin'
							bat 'docker build --build-arg UE_ARCHIVE_URL="%UE_ARCHIVE_URL%" -t jenkins-agent-windows:latest -f windows/Dockerfile windows'
							bat "docker tag jenkins-agent-windows:latest localhost:5000/jenkins-agent-windows:latest"
							bat "docker push localhost:5000/jenkins-agent-windows:latest"
							bat 'docker logout localhost:5000'
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
            }
        }
    }
}
