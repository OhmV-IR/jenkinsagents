pipeline {
	agent { label 'linux' }
	stages {
		stage("Checkout"){
			steps {
				checkout scm
			}
		}
		stage("Build linux image"){
			steps {
				sh "docker build -t linux-jenkins-agent:latest linux"
			}
		}
		stage("Save linux image to file"){
			steps {
				sh "docker save linux-jenkins-agent:latest -o linux-jenkins-agent.tar"
			}
		}
		stage("Archive artifact"){
			steps {
				archiveArtifacts artifacts: 'linux-jenkins-agent.tar', fingerprint: true
				sh "rm linux-jenkins-agent.tar"
			}
		}
	}
}
