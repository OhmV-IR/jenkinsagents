pipeline {
	agent { label 'host' }
	stages {
		stage("Checkout"){
			steps {
				checkout scm
			}
		}
		stage("Build linux image"){
			steps {
				bat "docker build -t jenkins-agent-linux:latest linux"
			}
		}
		stage("Save linux image to file"){
			steps {
				bat "docker save jenkins-agent-linux:latest -o jenkins-agent-linux.tar"
			}
		}
		stage("Archive artifact"){
			steps {
				archiveArtifacts artifacts: 'jenkins-agent-linux.tar', fingerprint: true
				bat "del jenkins-agent-linux.tar"
			}
		}
	}
}
