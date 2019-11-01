pipeline {
    agent any
    tools {
        maven 'mvn'
        jdk 'jdk8'
    }
    parameters {
        string( name: 'addressbook_ser', defaultValue: 'addressbookprepod.devopsprofessional.co.in', description: 'providing the name of the server')
        }
  stages{
  stage('source code git') {
         steps {
                 checkout([ $class: 'GitSCM', branches: [[name: '*/master']],
                 userRemoteConfigs: [[url: 'https://gitlab.devopsprofessional.co.in/santhosh.rch/addressbook.git',
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
               sshagent (credentials : ['addressbook-product']) {
               sh"""
               wget https://nexus.devopsprofessional.co.in/repository/maven-releases/test/addressbook/${version}/addressbook-${version}.war

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
