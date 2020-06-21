pipeline {
    agent any
    tools {
        maven 'mvn'
        jdk 'jdk8'
    }
    parameters {
        string( name: 'addressbook_ser', defaultValue: 'addresssbook-hanu.devopsprofessional.co.in', description: 'providing the name of the server')
        }
  stages{
  stage('source code git') {
         steps {
                 checkout([ $class: 'GitSCM', branches: [[name: '*/dev_no_proxy']],
                 userRemoteConfigs: [[url: 'https://github.com/santhu3064/addressbook.git',
                 credentialsId: 'jenkins-user']]])
               }
            }
  stage('loading environmental variables') {
            steps {
            script {
              load "env.properties"
            }
          }
        }
  stage('Build') {
             steps {
               script {
                currentBuild.displayName = "${version}"
                 currentBuild.description = "This build is for pre-production environment"
             }
          }
        }

  stage("Unittest") {
          steps {
              sh "mvn clean test"
              }
           }
  stage("PMD") {
           steps {
               sh "mvn -P metric pmd:pmd"
               pmd([pattern:'**/*.xml'])
            }
        }
  stage("Test Coverage") {
            steps {
                sh "mvn cobertura:cobertura"
            }
        }
  stage("Results") {
             steps{
                publishHTML(target:[
                reportDir:'target/site/cobertura',
                reportFiles: 'index.html',
                reportName: 'HTML Report'
                ])
              }
            }

  stage("Package") {
              steps {
                  sh "mvn versions:set -DnewVersion=${version}"
                  sh "mvn clean deploy"
                  }
              }

    stage("Deploy") {
             steps {
              script {
                withCredentials([usernamePassword(credentialsId: 'nexus-creds', usernameVariable: 'nexus_username', passwordVariable: 'nexus_password')]) {
                   sshagent (credentials : ['addressbook-preprod']) {
                   sh """
                   wget --user ${nexus_username} --password ${nexus_password} https://${nexus_url}/repository/maven-releases/com/frontend/addressbook/addressbook/${version}/addressbook-${version}.war

                  scp addressbook-${version}.war ubuntu@${addressbook_ser}:/tmp
                  ssh ubuntu@${addressbook_ser} \
                  sudo cp /tmp/addressbook-${version}.war /opt/addressbook-prepoddeploy

                  ssh ubuntu@${addressbook_ser} \
                  sudo chgrp -R tomcat /opt/addressbook-prepoddeploy/addressbook-${version}.war

                  ssh ubuntu@${addressbook_ser} \
                  sudo service tomcat stop

                  ssh ubuntu@${addressbook_ser} \
                  sudo rm -rf /opt/tomcat/webapps/addressbook.war

                  ssh ubuntu@${addressbook_ser} \
                  sudo ln -s /opt/addressbook-prepoddeploy/addressbook-${version}.war /opt/tomcat/webapps/addressbook.war

                  ssh ubuntu@${addressbook_ser} \
                  sudo service tomcat restart
                    """
                }
                }
             }
             }
          }
        }
      }
