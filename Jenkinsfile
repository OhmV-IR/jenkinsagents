pipeline {
    agent none
    parameters {
        string(name: 'UE_GIT_TAGS', defaultValue: '5.8.4-release',
               description: 'Space-separated EpicGames/UnrealEngine git tags compiled into the Linux and Windows agent images (each one installed under UE_ROOT/<tag>).')
        string(name: 'WINDOWS_BUILD_MEMORY', defaultValue: '12g',
               description: 'Memory limit for the Windows agent image build container (docker build -m).')
    }
    stages {
        stage("Build docker images"){
            parallel {
                stage("Build linux docker image"){
                    agent { label 'docker-linux' }
                    options {
                        throttle(['RamIntensiveJob-OldLaptop'])
                    }
                    steps {
                        checkout scm
                        // epic_github_token: Secret text, a GitHub token of an account linked to Epic (EpicGames/UnrealEngine access).
                        withCredentials([string(credentialsId: 'gh_classic_token', variable: 'GITHUB_TOKEN')]) {
                            withDockerRegistry(credentialsId: 'docker_server_priv_registry', url: 'https://localhost:5000') {
                                sh 'docker build --secret id=github_token,env=GITHUB_TOKEN --build-arg UE_GIT_TAGS="$UE_GIT_TAGS" -t jenkins-agent-linux:latest -f linux/Dockerfile linux'
                                sh "docker tag jenkins-agent-linux:latest localhost:5000/jenkins-agent-linux:latest"
                                sh "docker push localhost:5000/jenkins-agent-linux:latest"

                                sh "docker build -t jenkins-agent-linux-ndind:latest -f ndind/Dockerfile ndind"
                                sh "docker tag jenkins-agent-linux-ndind:latest localhost:5000/jenkins-agent-linux-ndind:latest"
                                sh "docker push localhost:5000/jenkins-agent-linux-ndind:latest"
                            }
                        }
                    }
                    post {
                        always {
                            // Images whose tags moved to the new builds (also those of the other image builds on this daemon).
                            sh 'docker image prune -f'
                            // BuildKit keeps its cache apart from images, so image prune leaves it alone. Every cache record
                            // this build used or created was just used, so this only drops cache of the builds it replaced
                            // (and anything else on this daemon nothing has used for a day).
                            sh 'docker builder prune -a -f --filter until=24h'
                        }
                    }
                }
                stage("Build p4 image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withDockerRegistry(credentialsId: 'docker_server_priv_registry', url: 'https://localhost:5000') {
                            sh "docker build -t p4-server:latest -f p4/Dockerfile p4"
                            sh "docker tag p4-server:latest localhost:5000/p4-server:latest"
                            sh "docker push localhost:5000/p4-server:latest"
                        }
                    }
                }
                stage("Build windows docker image"){
                    agent { label 'docker-windows' }
                    options {
                        throttle(['RamIntensiveJob-OldLaptop'])
                    }
                    steps {
                        checkout scm
                        withCredentials([string(credentialsId: 'gh_classic_token', variable: 'GITHUB_TOKEN')]) {
                            withDockerRegistry(credentialsId: 'docker_server_priv_registry', url: 'https://localhost:5000') {
                                // The Windows builder has no build secrets, so the token is a build arg. "--build-arg NAME"
                                // without a value reads it from the environment, which keeps it off the command line. Only
                                // the local ue-builder stage sees it; the pushed image does not (see windows/Dockerfile).
                                // ue-builder is tagged first so the engine build cache is not dangling and survives the prune.
                                bat 'docker build --isolation=process -m %WINDOWS_BUILD_MEMORY% --build-arg GITHUB_TOKEN --build-arg UE_GIT_TAGS --target ue-builder -t jenkins-agent-windows-ue-builder:latest -f windows/Dockerfile windows'
                                bat 'docker build --isolation=process -m %WINDOWS_BUILD_MEMORY% --build-arg GITHUB_TOKEN --build-arg UE_GIT_TAGS -t jenkins-agent-windows:latest -f windows/Dockerfile windows'
                                bat "docker tag jenkins-agent-windows:latest localhost:5000/jenkins-agent-windows:latest"
                                bat "docker push localhost:5000/jenkins-agent-windows:latest"
                            }
                        }
                    }
                    post {
                        always {
                            // The classic Windows builder's cache is the images themselves, so this also drops the cache of
                            // the builds that were replaced; there is no separate build cache to prune.
                            bat 'docker image prune -f'
                        }
                    }
                }
                stage("Build controller docker image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withDockerRegistry(credentialsId: 'docker_server_priv_registry', url: 'https://localhost:5000') {
                            sh "docker build -t jenkins-controller:latest -f controller/Dockerfile controller"
                            sh "docker tag jenkins-controller:latest localhost:5000/jenkins-controller:latest"
                            sh "docker push localhost:5000/jenkins-controller:latest"
                        }
                    }
                }
                stage("Build backrest image"){
                    agent { label 'docker-linux' }
                    steps {
                        checkout scm
                        withDockerRegistry(credentialsId: 'docker_server_priv_registry', url: 'https://localhost:5000') {
                            sh "docker build -t backrest:latest -f backrest/Dockerfile backrest"
                            sh "docker tag backrest:latest localhost:5000/backrest:latest"
                            sh "docker push localhost:5000/backrest:latest"
                        }
                    }
                }
            }
        }
    }
}
