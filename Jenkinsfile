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
    BASE_DIR="src/github.com/elastic/apm-agent-ruby"
    PIPELINE_LOG_LEVEL='INFO'
    NOTIFY_TO = credentials('notify-to')
    JOB_GCS_BUCKET = credentials('gcs-bucket')
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
    booleanParam(name: 'Run_As_Master_Branch', defaultValue: false, description: 'Allow to run any steps on a PR, some steps normally only run on master branch.')
    booleanParam(name: 'doc_ci', defaultValue: true, description: 'Enable build docs.')
    booleanParam(name: 'bench_ci', defaultValue: true, description: 'Enable run benchmarks.')
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
        gitCheckout(basedir: "${BASE_DIR}")
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
              xKey: 'RUBY_VERSION',
              yKey: 'FRAMEWORK',
              xFile: "./spec/.jenkins_ruby.yml",
              yFile: "./spec/.jenkins_framework.yml",
              exclusionFile: "./spec/.jenkins_exclude.yml",
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
      stage('Benchmarks') {
        options { skipDefaultCheckout() }
        when {
          beforeAgent true
          allOf {
            anyOf {
              not {
                changeRequest()
              }
              branch 'master'
              branch "\\d+\\.\\d+"
              branch "v\\d?"
              tag "v\\d+\\.\\d+\\.\\d+*"
              expression { return params.Run_As_Master_Branch }
            }
            expression { return params.bench_ci }
          }
        }
        stages {
          stage('Clean Workspace') {
            agent { label 'metal' }
            steps {
              echo "Cleaning Workspace"
            }
            post {
              always {
                cleanWs()
              }
            }
          }
          /**
            Run the benchmarks and store the results on ES.
            The result JSON files are also archive into Jenkins.
          */
          stage('Run Benchmarks') {
            agent { label 'linux && immutable' }
            steps {
              deleteDir()
              unstash 'source'
              dir("${BASE_DIR}"){
                script {
                  def versions = readYaml(file: "./spec/.jenkins_ruby.yml")
                  def benchmarkTask = [:]
                  versions['RUBY_VERSION'].each{ v ->
                    benchmarkTask[v] = runBenchmark(v)
                  }
                  parallel(benchmarkTask)
                }
              }
            }
          }
        }
      }
      /**
      Build the documentation.
      */
      stage('Documentation') {
        agent { label 'linux && immutable' }
        options { skipDefaultCheckout() }
        when {
          beforeAgent true
          allOf {
            anyOf {
              not {
                changeRequest()
              }
              branch 'master'
              branch "\\d+\\.\\d+"
              branch "v\\d?"
              tag "v\\d+\\.\\d+\\.\\d+*"
              expression { return params.Run_As_Master_Branch }
            }
            expression { return params.doc_ci }
          }
        }
        steps {
          deleteDir()
          unstash 'source'
          buildDocs(docsDir: "${BASE_DIR}/docs", archive: true)
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
  def label = params.label
  def ruby = params.ruby
  def framework = params.framework
  log(level: 'INFO', text: "${label}")
  env.HOME = "${env.WORKSPACE}"
  env.PATH = "${env.PATH}:${env.WORKSPACE}/bin"
  deleteDir()
  unstash 'source'
  dir("${BASE_DIR}"){
    retry(2){
      sleep randomNumber(min:10, max: 30)
      sh("./spec/scripts/spec.sh ${ruby} ${framework}")
    }
  }
}

/**
  Run benchmarks for a Ruby version, then report the results to the Elasticsearch server.
*/
def runBenchmark(version){
  return {
    node('metal'){
      env.HOME = "${env.WORKSPACE}/${version}"
      dir("${version}"){
        deleteDir()
        unstash 'source'
        dir("${BASE_DIR}"){
          try{
            sh "./spec/scripts/benchmarks.sh ${version}"
          } catch(e){
            throw e
          } finally {
            sendBenchmarks(file: "benchmark-${version}.bulk",
              index: "benchmark-ruby", archive: true)
          }
        }
      }
    }
  }
}
