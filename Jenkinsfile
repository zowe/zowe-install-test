#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */


node('ibm-jenkins-slave-dind') {
  // upgrade npm
  sh 'npm install -g npm'

  def lib = library("jenkins-library").org.zowe.jenkins_shared_library

  def pipeline = lib.pipelines.nodejs.NodeJSPipeline.new(this)

  def installDir = ''
  def testImageGuestSshHostPort = ''
  def testImageGuestSshCredential = ''

  pipeline.admins.add("jackjia")

  // we have extra parameters for integration test
  pipeline.addBuildParameters(
    booleanParam(
      name: 'STARTED_BY_AUTOMATION',
      description: 'If this task is started with pipeline automation. Set to true if you want to skip the Continue prompt question.',
      defaultValue: false
    ),
    booleanParam(
      name: 'SKIP_RESET_IMAGE',
      description: 'If skip the "reset_test_image" step.',
      defaultValue: true
    ),
    booleanParam(
      name: 'SKIP_INSTALLATION',
      description: 'If skip the "install" step. If check this, the pipeline will go straight to test stage.',
      defaultValue: false
    ),
    booleanParam(
      name: 'SKIP_TEMP_FIXES',
      description: 'If skip the "temp_fixes_before/after_install" step.',
      defaultValue: false
    ),
    // >>>>>>>> parameters of artifactory
    string(
      name: 'ZOWE_ARTIFACTORY_PATTERN',
      description: 'Zowe artifactory download pattern',
      defaultValue: 'libs-snapshot-local/org/zowe/*.pax',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_ARTIFACTORY_BUILD',
      description: 'Zowe artifactory download build',
      defaultValue: 'zowe-install-packaging :: staging',
      trim: true
    ),
    string(
      name: 'ZOWE_CLI_ARTIFACTORY_PATTERN',
      description: 'Zowe artifactory download pattern',
      defaultValue: 'libs-snapshot-local/org/zowe/cli/zowe-cli-package/*.zip',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_CLI_ARTIFACTORY_BUILD',
      description: 'Zowe artifactory download build',
      defaultValue: 'Zowe CLI Bundle :: master',
      trim: true
    ),
    // >>>>>>>> parameters of installation config
    choice(
      name: 'TARGET_SERVER',
      choices: ['marist', 'river'],
      description: 'Choose which server to run test',
      trim: true
    ),
    // >>>>>>>> parametters for test cases
    string(
      name: 'TEST_CASE_DEBUG_INFORMATION',
      description: 'How to show debug logging for running test cases.',
      defaultValue: '',
      trim: true
    )
  )

  pipeline.setup(
    github: [
      email                      : lib.Constants.DEFAULT_GITHUB_ROBOT_EMAIL,
      usernamePasswordCredential : lib.Constants.DEFAULT_GITHUB_ROBOT_CREDENTIAL,
    ],
    artifactory: [
      url                        : lib.Constants.DEFAULT_ARTIFACTORY_URL,
      usernamePasswordCredential : lib.Constants.DEFAULT_ARTIFACTORY_ROBOT_CREDENTIAL,
    ],
    // don't want audit failure blocks nightly test
    ignoreAuditFailure           : true
  )

  pipeline.build(
    timeout       : [time: 5, unit: 'MINUTES'],
    isSkippable   : false,
    operation     : {
      if (!params.STARTED_BY_AUTOMATION) {
        // The purpose of this stage is when you scan the repository, all branches/PRs builds will be
        // kicked off. This stage will pause the pipeline so you have time to cancel the build.
        //
        // NOTE: you have 5 minutes to cancel the build. After 5 minutes, the build will continue to
        //       next stage.
        timeout(time: 5, unit: 'MINUTES') { 
          input message: 'Do you want to continue the pipeline?', ok: "Continue"
        }
      }

      def configFile = "install-config-${params.TARGET_SERVER}.sh"
      if (!fileExists("scripts/${configFile}")) {
        error "Cannot find installation config file [${params.TARGET_SERVER}]"
      }
      sh "cp scripts/${configFile} scripts/install-config.sh"
      installDir = sh(
        script: ". scripts/install-config.sh && echo \$CIZT_INSTALL_DIR",
        returnStdout: true
      ).trim()
      testImageGuestSshHostPort = sh(
        script: ". scripts/install-config.sh && echo \$CIZT_TEST_IMAGE_GUEST_SSH_HOSTPORT",
        returnStdout: true
      ).trim()
      testImageGuestSshCredential = sh(
        script: ". scripts/install-config.sh && echo \$CIZT_TEST_IMAGE_GUEST_SSH_CREDENTIAL",
        returnStdout: true
      ).trim()
      if (!testImageGuestSshHostPort || !testImageGuestSshCredential) {
        error "Cannot find target server information"
      }
      echo "Credentials to target server: ${testImageGuestSshHostPort} and ${testImageGuestSshCredential}."
    }
  )

  // we need sonar scan
  pipeline.sonarScan(
    scannerTool     : lib.Constants.DEFAULT_SONARQUBE_SCANNER_TOOL,
    scannerServer   : lib.Constants.DEFAULT_SONARQUBE_SERVER
  )

  pipeline.createStage(
    name          : "Download Zowe",
    isSkippable   : true,
    stage         : {
      pipeline.artifactory.download(
        specContent : params.SKIP_INSTALLATION ? """
{
  "files": [{
    "pattern": "${params.ZOWE_CLI_ARTIFACTORY_PATTERN}",
    "target": ".tmp/",
    "flat": "true",
    "build": "${params.ZOWE_CLI_ARTIFACTORY_BUILD}",
    "explode": "true"
  }]
}
""" : """
{
  "files": [{
    "pattern": "${params.ZOWE_ARTIFACTORY_PATTERN}",
    "target": ".tmp/zowe.pax",
    "flat": "true",
    "build": "${params.ZOWE_ARTIFACTORY_BUILD}"
  }, {
    "pattern": "${params.ZOWE_CLI_ARTIFACTORY_PATTERN}",
    "target": ".tmp/",
    "flat": "true",
    "build": "${params.ZOWE_CLI_ARTIFACTORY_BUILD}",
    "explode": "true"
  }]
}
""",
        expected    : 2
      )
    },
    timeout: [time: 20, unit: 'MINUTES']
  )

  pipeline.createStage(
    name          : "Install Zowe",
    isSkippable   : true,
    shouldExecute : {
      return !params.SKIP_INSTALLATION
    },
    stage         : {
      withCredentials([
        usernamePassword(
          credentialsId: testImageGuestSshHostPort,
          passwordVariable: 'SSH_PORT',
          usernameVariable: 'SSH_HOST'
        )
      ]) {
      withCredentials([
        usernamePassword(
          credentialsId: testImageGuestSshCredential,
          passwordVariable: 'PASSWORD',
          usernameVariable: 'USERNAME'
        )
      ]) {
        // create INSTALL_DIR
        sh "SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${SSH_PORT} ${USERNAME}@${SSH_HOST} 'mkdir -p ${installDir}'"

        // send file to test image host
        sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${SSH_PORT} ${USERNAME}@${SSH_HOST} << EOF
cd ${installDir}
put scripts/temp-fixes-before-install.sh
put scripts/temp-fixes-after-install.sh
put scripts/temp-fixes-after-started.sh
put scripts/install-zowe.sh
put scripts/uninstall-zowe.sh
put scripts/install-config.sh
put scripts/opercmd
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
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${SSH_PORT} ${USERNAME}@${SSH_HOST} << EOF
cd ${installDir} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-zowe.sh > install-zowe.sh.new) && mv install-zowe.sh.new install-zowe.sh && chmod +x install-zowe.sh
./install-zowe.sh -n ${SSH_HOST}${skipTempFixes}${uninstallZowe} \
  ${installDir}/zowe.pax || { echo "[install-zowe.sh] failed"; exit 1; }
echo "[install-zowe.sh] succeeds" && exit 0
EOF"""
        }

        // wait for Zowe is fully started
        timeout(60) {
          def port = ''
          // check if zLux is started
          port = sh(
            script: ". scripts/install-config.sh && echo \$CIZT_ZOWE_ZLUX_HTTPS_PORT",
            returnStdout: true
          ).trim()
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${SSH_HOST}:${port}/"
          // check if explorer server is started
          port = sh(
            script: ". scripts/install-config.sh && echo \$CIZT_ZOWE_EXPLORER_JOBS_PORT",
            returnStdout: true
          ).trim()
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 'https://${USERNAME}:${PASSWORD}@${SSH_HOST}:${port}/api/v1/jobs?prefix=ZOWE*&status=ACTIVE'"
          // check if apiml gateway is started
          port = sh(
            script: ". scripts/install-config.sh && echo \$CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT",
            returnStdout: true
          ).trim()
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${USERNAME}:${PASSWORD}@${SSH_HOST}:${port}/"
          // check if apiml catalog is started
          port = sh(
            script: ". scripts/install-config.sh && echo \$CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT",
            returnStdout: true
          ).trim()
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 -d '{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}' 'https://${SSH_HOST}:${port}/api/v1/apicatalog/auth/login'"
        }

        // post install verify script
        timeout(30) {
          // always exit 0 to ignore failures in zowe-verify.sh
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${SSH_PORT} ${USERNAME}@${SSH_HOST} << EOF
cd ${installDir} && \
  temp-fixes-after-started.sh "${SSH_HOST}" "${USERNAME}" "${PASSWORD}" || { echo "[temp-fixes-after-started.sh] failed"; exit 0; }
echo "[temp-fixes-after-started.sh] succeeds" && exit 0
EOF"""
        }
      }
      }
    },
    timeout: [time: 120, unit: 'MINUTES']
  )

  pipeline.createStage(
    name          : "Install CLI",
    isSkippable   : true,
    stage         : {
      ansiColor('xterm') {
        // install CLI
        sh 'npm install -g .tmp/zowe-cli*.tgz'
      }
    },
    timeout: [time: 10, unit: 'MINUTES']
  )

  pipeline.test(
    name              : "Smoke",
    operation         : {
      ansiColor('xterm') {
      withCredentials([
        usernamePassword(
          credentialsId: testImageGuestSshHostPort,
          passwordVariable: 'SSH_PORT',
          usernameVariable: 'SSH_HOST'
        )
      ]) {
        withCredentials([
          usernamePassword(
            credentialsId: testImageGuestSshCredential,
            passwordVariable: 'PASSWORD',
            usernameVariable: 'USERNAME'
          )
        ]) {
          sh """. scripts/install-config.sh
ZOWE_ROOT_DIR=${CIZT_ZOWE_ROOT_DIR} \
SSH_HOST=${SSH_HOST} \
SSH_PORT=${SSH_PORT} \
SSH_USER=${USERNAME} \
SSH_PASSWD=${PASSWORD} \
ZOSMF_PORT=${CIZT_ZOSMF_PORT} \
ZOWE_DS_MEMBER=${CIZT_PROCLIB_MEMBER} \
ZOWE_JOB_PREFIX=${CIZT_ZOWE_JOB_PREFIX} \
ZOWE_ZLUX_HTTPS_PORT=${CIZT_ZOWE_ZLUX_HTTPS_PORT} \
ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=${CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT} \
ZOWE_EXPLORER_JOBS_PORT=${CIZT_ZOWE_EXPLORER_JOBS_PORT} \
ZOWE_EXPLORER_DATASETS_PORT=${CIZT_ZOWE_EXPLORER_DATASETS_PORT} \
DEBUG=${params.TEST_CASE_DEBUG_INFORMATION} \
npm test"""
        }
        }
      }
    },
    junit         : "reports/junit.xml",
    htmlReports   : [
      [dir: "reports", files: "index.html", name: "Report: Test Result"],
    ],
    timeout: [time: 30, unit: 'MINUTES'],
  )

  pipeline.end()
}
