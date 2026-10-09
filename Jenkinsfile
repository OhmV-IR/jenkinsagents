pipeline {
    agent none
    environment {
        // Image pushes go to localhost:5000 (registry.ohmvir.dev sits behind Cloudflare, whose 100MB request
        // limit breaks layer uploads); image pulls go through registry.ohmvir.dev.
        PULL_REGISTRY = 'registry.ohmvir.dev'
    }
    parameters {
        // Toolchain images are slow to build, so they are only (re)built on purpose: via these flags, or
        // (ESP-IDF / build tools) when a commit in this build touches their own directory.
        booleanParam(name: 'BUILD_WINDOWS_BUILDTOOLS', defaultValue: false,
                     description: 'Rebuild windows-buildtools (Chocolatey tools, VS 2026 Build Tools, GDK), and esp-idf-windows on top of it.')
        booleanParam(name: 'BUILD_ESP_IDF', defaultValue: false,
                     description: 'Rebuild the esp-idf-linux and esp-idf-windows images (eim + ESP-IDF toolchains).')
        // Compiling the engine takes hours, so its images are only (re)built when asked for explicitly.
        booleanParam(name: 'BUILD_UNREAL_ENGINE', defaultValue: false,
                     description: 'Compile the Unreal Engine images for UE_GIT_TAG from source (takes hours). Needed once per tag.')
        string(name: 'UE_GIT_TAG', defaultValue: '5.8.3-release',
               description: 'EpicGames/UnrealEngine git tag. The agent images ship unreal-engine-{linux,windows}:<tag> (pushed to localhost:5000, pulled from registry.ohmvir.dev).')
        string(name: 'UE_WINDOWS_BUILD_MEMORY', defaultValue: '32g',
               description: 'Memory limit for the Windows engine build containers (docker build -m).')
    }
    stages {
        stage("Build Windows build tools image"){
            agent { label 'docker-windows' }
            when {
                beforeAgent true
                anyOf { expression { params.BUILD_WINDOWS_BUILDTOOLS }; changeset 'windows-buildtools/**' }
            }
            steps {
                checkout scm
                withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    bat 'echo %REG_PASS%| docker login localhost:5000 -u "%REG_USER%" --password-stdin'
                    bat 'docker build -t localhost:5000/windows-buildtools:latest -f windows-buildtools/Dockerfile windows-buildtools'
                    bat 'docker push localhost:5000/windows-buildtools:latest'
                    bat 'docker logout localhost:5000'
                }
            }
        }
        stage("Build ESP-IDF images"){
            parallel {
                stage("Build linux ESP-IDF image"){
                    agent { label 'docker-linux' }
                    when {
                        beforeAgent true
                        anyOf { expression { params.BUILD_ESP_IDF }; changeset 'esp-idf/linux/**' }
                    }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh 'docker build -t localhost:5000/esp-idf-linux:latest -f esp-idf/linux/Dockerfile esp-idf/linux'
                            sh 'docker push localhost:5000/esp-idf-linux:latest'
                            sh 'docker logout localhost:5000'
                        }
                    }
                }
                stage("Build windows ESP-IDF image"){
                    agent { label 'docker-windows' }
                    // Also rebuilt whenever its base (windows-buildtools) was, so the chain never goes stale.
                    when {
                        beforeAgent true
                        anyOf {
                            expression { params.BUILD_ESP_IDF || params.BUILD_WINDOWS_BUILDTOOLS }
                            changeset 'esp-idf/windows/**'
                            changeset 'windows-buildtools/**'
                        }
                    }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                            bat 'echo %REG_PASS%| docker login localhost:5000 -u "%REG_USER%" --password-stdin'
                            bat 'echo %REG_PASS%| docker login %PULL_REGISTRY% -u "%REG_USER%" --password-stdin'
                            bat 'docker build --build-arg BUILDTOOLS_IMAGE=%PULL_REGISTRY%/windows-buildtools:latest -t localhost:5000/esp-idf-windows:latest -f esp-idf/windows/Dockerfile esp-idf/windows'
                            bat 'docker push localhost:5000/esp-idf-windows:latest'
                            bat 'docker logout localhost:5000'
                            bat 'docker logout %PULL_REGISTRY%'
                        }
                    }
                }
            }
        }
        stage("Build Unreal Engine images"){
            when { expression { params.BUILD_UNREAL_ENGINE } }
            parallel {
                stage("Build linux Unreal Engine image"){
                    agent { label 'docker-linux' }
                    options {
                        throttle(['RamIntensiveJob-OldLaptop'])
                    }
                    steps {
                        checkout scm
                        // epic_github_token: Secret text, a GitHub token of an account linked to Epic (EpicGames/UnrealEngine access).
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
                                         string(credentialsId: 'epic_github_token', variable: 'GITHUB_TOKEN')]) {
                            sh 'echo "$REG_PASS" | docker login localhost:5000 -u "$REG_USER" --password-stdin'
                            sh 'docker build --secret id=github_token,env=GITHUB_TOKEN --build-arg UE_GIT_TAG="$UE_GIT_TAG" -t "localhost:5000/unreal-engine-linux:$UE_GIT_TAG" -f unreal/linux/Dockerfile unreal/linux'
                            sh 'docker push "localhost:5000/unreal-engine-linux:$UE_GIT_TAG"'
                            sh 'docker logout localhost:5000'
                        }
                    }
                }
                stage("Build windows Unreal Engine image"){
                    agent { label 'docker-windows' }
                    options {
                        throttle(['RamIntensiveJob-OldLaptop'])
                    }
                    steps {
                        checkout scm
                        withCredentials([usernamePassword(credentialsId: 'docker_server_priv_registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS'),
                                         string(credentialsId: 'epic_github_token', variable: 'GITHUB_TOKEN')]) {
                            bat 'echo %REG_PASS%| docker login localhost:5000 -u "%REG_USER%" --password-stdin'
                            bat 'echo %REG_PASS%| docker login %PULL_REGISTRY% -u "%REG_USER%" --password-stdin'
                            bat 'docker build -m %UE_WINDOWS_BUILD_MEMORY% --build-arg GITHUB_TOKEN=%GITHUB_TOKEN% --build-arg UE_GIT_TAG=%UE_GIT_TAG% --build-arg BUILDTOOLS_IMAGE=%PULL_REGISTRY%/windows-buildtools:latest -t localhost:5000/unreal-engine-windows:%UE_GIT_TAG% -f unreal/windows/Dockerfile unreal/windows'
                            bat 'docker push localhost:5000/unreal-engine-windows:%UE_GIT_TAG%'
                            bat 'docker logout localhost:5000'
                            bat 'docker logout %PULL_REGISTRY%'
                        }
                    }
                }
            }
        }
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
}
