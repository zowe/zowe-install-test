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
  defaultValue: 'zowe-install-packaging-pipeline :: master',
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
  description: 'catalogHttpPort for Zowe API mediation',
  defaultValue: '7552',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT',
  description: 'discoveryHttpPort for Zowe API mediation',
  defaultValue: '7553',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT',
  description: 'gatewayHttpsPort for Zowe API mediation',
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

      if (!params.SKIP_RESET_IMAGE && !params.SKIP_INSTALLATION) {
        // send out notification to prepare for manual process
        emailext body: """Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} has been started, and it requires manual input. For river, it usually takes 30 ~ 40 minutes to reset the image.

Check detail: ${env.BUILD_URL}

To manually start zD&T, please follow these steps:
1. start SSH tunnel on VNC port 5901
   \$ ssh -L 5901:localhost:5901 ibmsys1@river.zowe.org
2. use vncviewer or other tools (like screen sharing) to connect to vnc
   \$ vncviewer localhost:1
3. from VNC Terminal command line, run command:
   \$ /zaas1/scripts/onboot.sh
4. go back to Jenkins job and click Continue.

It may take another 10 ~ 30 minutes for z/OS and z/OSMF to start.""",
            subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} started",
            recipientProviders: [
              [$class: 'RequesterRecipientProvider'],
              [$class: 'CulpritsRecipientProvider'],
              [$class: 'DevelopersRecipientProvider'],
              [$class: 'UpstreamComitterRecipientProvider']
            ]
      }
    }

    utils.conditionalStage('prepare', !params.SKIP_INSTALLATION) {
      def tasks = [:]

      tasks["download_zowe"] = {
        // download artifactories
        def server = Artifactory.server params.ARTIFACTORY_SERVER
        def downloadSpec = readFile "artifactory-download-spec.json"
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

            timeout(60) {
              input message: 'Please manually start zD&T /zaas1/scripts/onboot.sh and click on Continue...', ok: 'Continue'
            }

            // wait a while before testing z/OSMF
            sleep time: 10, unit: 'MINUTES'
            // check if zD&T & z/OSMF are started
            timeout(120) {
              sh "./scripts/is-website-ready.sh -r 720 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOSMF_PORT}/zosmf/"
            }
          }
        }
      }

      parallel tasks
    }

    utils.conditionalStage('install', !params.SKIP_INSTALLATION) {
      withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        // create INSTALL_DIR
        sh "SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} 'mkdir -p ${params.INSTALL_DIR}'"

        // send file to test image host
        sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR}
put scripts/temp-fixes-before-install.sh
put scripts/temp-fixes-after-install.sh
put scripts/install-zowe.sh
put scripts/uninstall-zowe.sh
put .tmp/zowe.pax
EOF"""

        // run install-zowe.sh
        timeout(30) {
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
  --apim-catelog-port ${params.ZOWE_API_MEDIATION_CATALOG_HTTP_PORT} --apim-discovery-port ${params.ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT} --apim-gateway-port ${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}\
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
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_EXPLORER_SERVER_HTTPS_PORT}/ibm/api/explorer/"
        }
        // check if zD&T & z/OSMF are started again in case z/OSMF is restarted
        timeout(60) {
          sh "./scripts/is-website-ready.sh -r 720 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOSMF_PORT}/zosmf/"
        }
      }
    }

    stage('test') {
      ansiColor('xterm') {
        sh "npm install"

        withCredentials([usernamePassword(credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
          // download cli
          sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
get ${params.INSTALL_DIR}/extracted/zowe-cli-bundle.zip
EOF"""
          // install CLI
          sh 'unzip zowe-cli-bundle.zip'
          sh 'npm install -g zowe-cli-1.*.tgz'

          // run tests
          sh """ZOWE_ROOT_DIR=${params.ZOWE_ROOT_DIR} \
SSH_HOST=${params.TEST_IMAGE_GUEST_SSH_HOST} \
SSH_PORT=${params.TEST_IMAGE_GUEST_SSH_PORT} \
SSH_USER=${USERNAME} \
SSH_PASSWD=${PASSWORD} \
ZOSMF_PORT=${params.ZOSMF_PORT} \
ZOWE_ZLUX_HTTPS_PORT=${params.ZOWE_ZLUX_HTTPS_PORT} \
ZOWE_EXPLORER_SERVER_HTTPS_PORT=${params.ZOWE_EXPLORER_SERVER_HTTPS_PORT} \
npm test"""
        }
      }

      // publish report
      junit 'reports/junit.xml'
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
