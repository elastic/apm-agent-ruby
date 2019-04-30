#!/usr/bin/env groovy
@Library('apm@current') _

import co.elastic.matrix.*
import groovy.transform.Field

/**
This is the parallel tasks generator,
it is need as field to store the results of the tests.
*/
@Field def rubyTasksGen

pipeline {
  agent any
  environment {
    REPO="git@github.com:elastic/apm-agent-ruby.git"
    BASE_DIR="src/github.com/elastic/apm-agent-ruby"
    PIPELINE_LOG_LEVEL='INFO'
    NOTIFY_TO = credentials('notify-to')
    JOB_GCS_BUCKET = credentials('gcs-bucket')
    JOB_GIT_CREDENTIALS = "f6c7695a-671e-4f4f-a331-acdce44ff9ba"
  }
  options {
    timeout(time: 2, unit: 'HOURS')
    buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '20', daysToKeepStr: '30'))
    timestamps()
    ansiColor('xterm')
    disableResume()
    durabilityHint('PERFORMANCE_OPTIMIZED')
    rateLimitBuilds(throttle: [count: 60, durationName: 'hour', userBoost: true])
    quietPeriod(10)
  }
  triggers {
    issueCommentTrigger('.*(?:jenkins\\W+)?run\\W+(?:the\\W+)?tests(?:\\W+please)?.*')
  }
  parameters {
    string(name: 'RUBY_VERSION', defaultValue: "ruby-2.6", description: "Ruby version to test")
    string(name: 'BRANCH_SPECIFIER', defaultValue: "master", description: "Git branch/tag to use")
    string(name: 'CHANGE_TARGET', defaultValue: "master", description: "Git branch/tag to merge before building")
  }
  stages {
    /**
    Checkout the code and stash it, to use it on other stages.
    */
    stage('Checkout') {
      agent { label 'master || immutable' }
      options { skipDefaultCheckout() }
      steps {
        deleteDir()
        gitCheckout(basedir: "${BASE_DIR}", 
          branch: "${params.BRANCH_SPECIFIER}",
          repo: "${REPO}",
          credentialsId: "${JOB_GIT_CREDENTIALS}",
          mergeTarget: "${params.CHANGE_TARGET}"
          reference: '/var/lib/jenkins/apm-agent-ruby.git')
        stash allowEmpty: true, name: 'source', useDefaultExcludes: false
      }
    }
    /**
    Execute unit tests.
    */
    stage('Test') {
      agent { label 'linux && immutable' }
      options { skipDefaultCheckout() }
      steps {
        deleteDir()
        unstash "source"
        dir("${BASE_DIR}"){
          script {
            rubyTasksGen = new RubyParallelTaskGenerator(
              xVersions: [ "${RUBY_VERSION}" ],
              yKey: 'FRAMEWORK',
              yFile: ".ci/.jenkins_framework.yml",
              exclusionFile: ".ci/.jenkins_exclude.yml",
              tag: "Ruby",
              name: "Ruby",
              steps: this
              )
              def mapPatallelTasks = rubyTasksGen.generateParallelTests()
              parallel(mapPatallelTasks)
            }
          }
        }
      }
    post {
      always{
        script{
          if(rubyTasksGen?.results){
            writeJSON(file: 'results.json', json: toJSON(rubyTasksGen.results), pretty: 2)
            def mapResults = ["Ruby": rubyTasksGen.results]
            def processor = new ResultsProcessor()
            processor.processResults(mapResults)
            archiveArtifacts allowEmptyArchive: true, artifacts: 'results.json,results.html', defaultExcludes: false
          }
        }
      }
      success {
        echoColor(text: '[SUCCESS]', colorfg: 'green', colorbg: 'default')
      }
      aborted {
        echoColor(text: '[ABORTED]', colorfg: 'magenta', colorbg: 'default')
      }
      failure {
        echoColor(text: '[FAILURE]', colorfg: 'red', colorbg: 'default')
        step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: "${NOTIFY_TO}", sendToIndividuals: false])
      }
      unstable {
        echoColor(text: '[UNSTABLE]', colorfg: 'yellow', colorbg: 'default')
      }
    }
  }

/**
Parallel task generator for the integration tests.
*/
class RubyParallelTaskGenerator extends DefaultParallelTaskGenerator {
  
  public RubyParallelTaskGenerator(Map params){
    super(params)
  }
  
  /**
  build a clousure that launch and agent and execute the corresponding test script,
  then store the results.
  */
  public Closure generateStep(x, y){
    return {
      steps.sleep steps.randomNumber(min:10, max: 30)
      steps.node('linux && immutable'){
        def label = "${tag}:${x}#${y}"
        try {
          steps.runScript(label: label, ruby: x, framework: y)
          saveResult(x, y, 1)
        } catch(e){
          saveResult(x, y, 0)
          error("${label} tests failed : ${e.toString()}\n")
        } finally {
          steps.junit(allowEmptyResults: false,
            keepLongStdio: true,
            testResults: "**/spec/ruby-agent-junit.xml")
          steps.codecov(repo: 'apm-agent-ruby', basedir: "${steps.env.BASE_DIR}")
        }
      }
    }
  }
}

/**
  Run tests for a Ruby version and framework version.
*/
def runScript(Map params = [:]){
  log(level: 'INFO', text: "${params.label}")
  env.HOME = "${env.WORKSPACE}"
  env.PATH = "${env.PATH}:${env.WORKSPACE}/bin"
  deleteDir()
  unstash 'source'
  dir("${BASE_DIR}"){
    retry(2){
      sleep randomNumber(min:10, max: 30)
      sh("./spec/scripts/spec.sh ${params.ruby} ${params.framework}")
    }
  }
}
