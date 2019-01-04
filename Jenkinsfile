#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

def isPullRequest = env.BRANCH_NAME.startsWith('PR-')
def slackChannel = '#test-build-notify'

def opts = []
// keep last 20 builds for regular branches, no keep for pull requests
opts.push(buildDiscarder(logRotator(numToKeepStr: (isPullRequest ? '' : '20'))))
// disable concurrent build
opts.push(disableConcurrentBuilds())
// set upstream triggers
// if (env.BRANCH_NAME == 'master') {
//   opts.push(pipelineTriggers([
//     upstream(threshold: 'SUCCESS', upstreamProjects: '/zowe-install-packaging-pipeline/master')
//   ]))
// }

// define custom build parameters
def customParameters = []
// >>>>>>>> parameters to control pipeline behavior
customParameters.push(booleanParam(
  name: 'SKIP_RESET_IMAGE',
  description: 'If skip the "reset_test_image" step.',
  defaultValue: false
))
customParameters.push(booleanParam(
  name: 'SKIP_INSTALLATION',
  description: 'If skip the "install" step. If check this, the pipeline will go straight to test stage.',
  defaultValue: false
))
customParameters.push(booleanParam(
  name: 'SKIP_TEMP_FIXES',
  description: 'If skip the "temp_fixes_before/after_install" step.',
  defaultValue: false
))
// >>>>>>>> parameters of artifactory
customParameters.push(string(
  name: 'ARTIFACTORY_SERVER',
  description: 'Artifactory server, should be pre-defined in Jenkins configuration',
  defaultValue: 'gizaArtifactory',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_ARTIFACTORY_PATTERN',
  description: 'Zowe artifactory download pattern',
  defaultValue: 'libs-snapshot-local/com/project/zowe/*.pax',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_ARTIFACTORY_BUILD',
  description: 'Zowe artifactory download build',
  defaultValue: 'zowe-install-packaging :: master',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_ARTIFACTORY_PATTERN',
  description: 'Zowe artifactory download pattern',
  defaultValue: 'libs-snapshot-local/org/zowe/cli/zowe-cli-package/*.zip',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_ARTIFACTORY_BUILD',
  description: 'Zowe artifactory download build',
  defaultValue: 'Zowe CLI Bundle :: master',
  trim: true
))
// >>>>>>>> parameters of installation config
customParameters.push(string(
  name: 'ZOWE_ROOT_DIR',
  description: 'Zowe installation root directory',
  defaultValue: '/zaas1/zowe',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'INSTALL_DIR',
  description: 'Installation working directory',
  defaultValue: '/zaas1/zowe-install',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'PROCLIB_DS',
  description: 'PROCLIB data set name',
  defaultValue: 'auto',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'PROCLIB_MEMBER',
  description: 'PROCLIB member name',
  defaultValue: 'ZOWESVR',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOSMF_PORT',
  description: 'Port of z/OSMF service',
  defaultValue: '10443',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_ZLUX_HTTP_PORT',
  description: 'httpPort for Zowe zLux service',
  defaultValue: '8543',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_ZLUX_HTTPS_PORT',
  description: 'httpsPort for Zowe zLux service',
  defaultValue: '8544',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_ZLUX_ZSS_PORT',
  description: 'zssPort for Zowe zLux service',
  defaultValue: '8542',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_EXPLORER_SERVER_HTTP_PORT',
  description: 'httpPort for Zowe explorer server',
  defaultValue: '7080',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_EXPLORER_SERVER_HTTPS_PORT',
  description: 'httpsPort for Zowe explorer server',
  defaultValue: '7443',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_API_MEDIATION_CATALOG_HTTP_PORT',
  description: 'catalogPort for Zowe API mediation',
  defaultValue: '7552',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT',
  description: 'discoveryPort for Zowe API mediation',
  defaultValue: '7553',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT',
  description: 'gatewayPort for Zowe API mediation',
  defaultValue: '7554',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_MVD_SSH_PORT',
  description: 'sshPort for Zowe MVD terminals',
  defaultValue: '22',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_MVD_TELNET_PORT',
  description: 'telnetPort for Zowe MVD terminals',
  defaultValue: '23',
  trim: true,
  required: true
))
// >>>>>>>> SSH access of testing server Ubuntu layer
customParameters.push(string(
  name: 'TEST_IMAGE_HOST_SSH_HOST',
  description: 'Test image host IP',
  defaultValue: 'river.zowe.org',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'TEST_IMAGE_HOST_SSH_PORT',
  description: 'Test image host SSH port',
  defaultValue: '22',
  trim: true,
  required: true
))
customParameters.push(credentials(
  name: 'TEST_IMAGE_HOST_SSH_CREDENTIAL',
  description: 'The SSH credential used to connect to zD&T test image host (Ubuntu layer)',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'ssh-zdt-test-image-host',
  required: true
))
// >>>>>>>> SSH access of testing server zOSaaS layer
customParameters.push(string(
  name: 'TEST_IMAGE_GUEST_SSH_HOST',
  description: 'Test image guest IP',
  defaultValue: 'river.zowe.org',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'TEST_IMAGE_GUEST_SSH_PORT',
  description: 'Test image guest SSH port',
  defaultValue: '2022',
  trim: true,
  required: true
))
customParameters.push(credentials(
  name: 'TEST_IMAGE_GUEST_SSH_CREDENTIAL',
  description: 'The SSH credential used to connect to zD&T test image guest (zOSaaS layer)',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'ssh-zdt-test-image-guest',
  required: true
))
// >>>>>>>> parametters for test cases
customParameters.push(string(
  name: 'TEST_CASE_DEBUG_INFORMATION',
  description: 'How to show debug logging for running test cases.',
  defaultValue: '',
  trim: true
))
opts.push(parameters(customParameters))

// set build properties
properties(opts)

node ('ibm-jenkins-slave-nvm') {
  currentBuild.result = 'SUCCESS'

  try {

    stage('checkout') {
      // checkout source code
      checkout scm

      // check if it's pull request
      echo "Current branch is ${env.BRANCH_NAME}"
      if (isPullRequest) {
        echo "This is a pull request"
      }
    }

    // lock testing server
    lock("testing-server-${params.TEST_IMAGE_HOST_SSH_HOST}") {

      utils.conditionalStage('prepare', !params.SKIP_INSTALLATION) {
        def tasks = [:]

        tasks["download_zowe"] = {
          // download artifactories
          def server = Artifactory.server params.ARTIFACTORY_SERVER
          def downloadSpec = readFile "artifactory-download-spec-zos.json.template"
          downloadSpec = downloadSpec.replaceAll(/\{ARTIFACTORY_PATTERN\}/, params.ZOWE_ARTIFACTORY_PATTERN)
          downloadSpec = downloadSpec.replaceAll(/\{ARTIFACTORY_BUILD\}/, params.ZOWE_ARTIFACTORY_BUILD)
          timeout(20) {
            server.download(downloadSpec)
          }

          // verify downloaded files
          sh "ls -la .tmp"
        }

        if (!params.SKIP_RESET_IMAGE) {
          tasks["reset_test_image"] = {
            withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_HOST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
              // send script to test image host
              sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_HOST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_HOST_SSH_HOST} << EOF
put scripts/refresh-zosaas.sh /home/ibmsys1
put scripts/temp-fixes-prereqs-image.sh /home/ibmsys1
chmod 755 /home/ibmsys1/refresh-zosaas.sh
chmod 755 /home/ibmsys1/temp-fixes-prereqs-image.sh
EOF"""

              // run refresh-zosaas.sh
              timeout(90) {
                sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_HOST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_HOST_SSH_HOST} << EOF
~/refresh-zosaas.sh
exit 0
EOF"""
              }

              // wait a while before testing z/OSMF
              sleep time: 10, unit: 'MINUTES'
              // check if zD&T & z/OSMF are started
              timeout(120) {
                sh "./scripts/is-website-ready.sh -r 720 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOSMF_PORT}/zosmf/info"
              }
            }
          }
        }

        parallel tasks
      }

      utils.conditionalStage('install-zowe', !params.SKIP_INSTALLATION) {
        withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
          // create INSTALL_DIR
          sh "SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} 'mkdir -p ${params.INSTALL_DIR}'"

          // send file to test image host
          sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR}
put scripts/temp-fixes-before-install.sh
put scripts/temp-fixes-after-install.sh
put scripts/temp-fixes-after-started.sh
put scripts/install-zowe.sh
put scripts/uninstall-zowe.sh
put .tmp/zowe.pax
EOF"""

          // run install-zowe.sh
          timeout(60) {
            def skipTempFixes = ""
            def uninstallZowe = ""
            if (params.SKIP_TEMP_FIXES) {
              skipTempFixes = " -s"
            }
            if (params.SKIP_RESET_IMAGE) {
              uninstallZowe = " -u"
            }
            sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-zowe.sh > install-zowe.sh.new) && mv install-zowe.sh.new install-zowe.sh && chmod +x install-zowe.sh
./install-zowe.sh -n ${params.TEST_IMAGE_GUEST_SSH_HOST} -t ${params.ZOWE_ROOT_DIR} -i ${params.INSTALL_DIR}${skipTempFixes}${uninstallZowe} --zosmf-port ${params.ZOSMF_PORT}\
  --proc-ds ${params.PROCLIB_DS} --proc-member ${params.PROCLIB_MEMBER}\
  --apim-catalog-port ${params.ZOWE_API_MEDIATION_CATALOG_HTTP_PORT} --apim-discovery-port ${params.ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT} --apim-gateway-port ${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}\
  --explorer-http-port ${params.ZOWE_EXPLORER_SERVER_HTTP_PORT} --explorer-https-port ${params.ZOWE_EXPLORER_SERVER_HTTPS_PORT}\
  --zlux-http-port ${params.ZOWE_ZLUX_HTTP_PORT} --zlux-https-port ${params.ZOWE_ZLUX_HTTPS_PORT} --zlux-zss-port ${params.ZOWE_ZLUX_ZSS_PORT}\
  --term-ssh-port ${params.ZOWE_MVD_SSH_PORT} --term-telnet-port ${params.ZOWE_MVD_TELNET_PORT}\
  ${params.INSTALL_DIR}/zowe.pax || { echo "[install-zowe.sh] failed"; exit 1; }
echo "[install-zowe.sh] succeeds" && exit 0
EOF"""
          }

          // wait a while before testing zLux
          sleep time: 2, unit: 'MINUTES'
          // check if zLux is started
          timeout(60) {
            sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_ZLUX_HTTPS_PORT}/"
          }
          // check if explorer server is started
          timeout(60) {
            sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_EXPLORER_SERVER_HTTPS_PORT}/api/v1/jobs"
          }
          // check if zD&T & z/OSMF are started again in case z/OSMF is restarted
          timeout(60) {
            sh "./scripts/is-website-ready.sh -r 720 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOSMF_PORT}/zosmf/info"
          }
          // post install verify script
          timeout(30) {
            // always exit 0 to ignore failures in zowe-verify.sh
            sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  temp-fixes-after-started.sh "${params.ZOWE_ROOT_DIR}" || { echo "[temp-fixes-after-started.sh] failed"; exit 0; }
echo "[temp-fixes-after-started.sh] succeeds" && exit 0
EOF"""
          }

          // wait a while before starting test
          sleep time: 10, unit: 'MINUTES'
          // FIXME: zLux login may hang there which blocks UI test cases
          // try a login to the zlux auth api
          def zluxAuth = sh(
            script: "curl -d '{\\\"username\\\":\\\"${USERNAME}\\\",\\\"password\\\":\\\"${PASSWORD}\\\"}' -H 'Content-Type: application/json' -X POST -k https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_ZLUX_HTTPS_PORT}/auth",
            returnStdout: true
          ).trim()
          echo "zLux login result:"
          echo zluxAuth
        }
      }

      stage('download-and-install-cli') {
        ansiColor('xterm') {
          withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
            // install CLI
            def server = Artifactory.server params.ARTIFACTORY_SERVER
            def downloadSpec = readFile "artifactory-download-spec-cli.json.template"
            downloadSpec = downloadSpec.replaceAll(/\{CLI_ARTIFACTORY_PATTERN\}/, params.ZOWE_CLI_ARTIFACTORY_PATTERN)
            downloadSpec = downloadSpec.replaceAll(/\{CLI_ARTIFACTORY_BUILD\}/, params.ZOWE_CLI_ARTIFACTORY_BUILD)
            timeout(time: 5, unit: 'MINUTES' ) {
              server.download(downloadSpec)
            }
            sh 'unzip .tmp/zowe-cli-package.zip'
            sh 'npm install -g zowe-cli-*.tgz'
          }
        }
      }

      stage('test') {
        ansiColor('xterm') {
          sh "npm install"
          sh "npm run lint"

          withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
            // run tests
            try {
              sh """ZOWE_ROOT_DIR=${params.ZOWE_ROOT_DIR} \
SSH_HOST=${params.TEST_IMAGE_GUEST_SSH_HOST} \
SSH_PORT=${params.TEST_IMAGE_GUEST_SSH_PORT} \
SSH_USER=${USERNAME} \
SSH_PASSWD=${PASSWORD} \
ZOSMF_PORT=${params.ZOSMF_PORT} \
ZOWE_DS_MEMBER=${params.PROCLIB_MEMBER} \
ZOWE_ZLUX_HTTPS_PORT=${params.ZOWE_ZLUX_HTTPS_PORT} \
ZOWE_EXPLORER_SERVER_HTTPS_PORT=${params.ZOWE_EXPLORER_SERVER_HTTPS_PORT} \
DEBUG=${params.TEST_CASE_DEBUG_INFORMATION} \
npm test"""
            } finally {
              // publish report
              junit 'reports/junit.xml'
              publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: false,
                keepAll: false,
                reportDir: 'reports',
                reportFiles: 'index.html',
                reportName: 'Test Result HTML Report',
                reportTitles: ''
              ])
            }
          }
        }
      }
    }

    stage('done') {
      // send out notification
      // slackSend channel: slackChannel,
      //           color: 'good',
      //           message: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} succeeded.\n\nCheck detail: ${env.BUILD_URL}"

      emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} succeeded.\n\nCheck detail: ${env.BUILD_URL}" ,
          subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} succeeded",
          recipientProviders: [
            [$class: 'RequesterRecipientProvider'],
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'UpstreamComitterRecipientProvider']
          ]
    }

  } catch (err) {
    currentBuild.result = 'FAILURE'

    // catch all failures to send out notification
    // slackSend channel: slackChannel,
    //           color: 'warning',
    //           message: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}"

    emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}" ,
        subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed",
        recipientProviders: [
          [$class: 'RequesterRecipientProvider'],
          [$class: 'CulpritsRecipientProvider'],
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'UpstreamComitterRecipientProvider']
        ]

    throw err
  }
}
