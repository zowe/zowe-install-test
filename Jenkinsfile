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
    string(
      name: 'ZOWE_ROOT_DIR',
      description: 'Zowe installation root directory',
      defaultValue: '/ZOWE/staging/zowe',
      trim: true,
      required: true
    ),
    string(
      name: 'INSTALL_DIR',
      description: 'Installation working directory',
      defaultValue: '/ZOWE/zowe-installs',
      trim: true,
      required: true
    ),
    string(
      name: 'PROCLIB_DS',
      description: 'PROCLIB data set name',
      defaultValue: 'auto',
      trim: true,
      required: true
    ),
    string(
      name: 'PROCLIB_MEMBER',
      description: 'PROCLIB member name',
      defaultValue: 'ZOWESVR',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_JOB_PREFIX',
      description: 'Zowe job prefix',
      defaultValue: 'ZOWE',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOSMF_PORT',
      description: 'Port of z/OSMF service',
      defaultValue: '10443',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_ZLUX_HTTPS_PORT',
      description: 'httpsPort for Zowe zLux service',
      defaultValue: '8544',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_ZLUX_ZSS_PORT',
      description: 'zssPort for Zowe zLux service',
      defaultValue: '8542',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_EXPLORER_JOBS_PORT',
      description: 'jobsPort for Zowe explorer server',
      defaultValue: '8545',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_EXPLORER_DATASETS_PORT',
      description: 'dataSetsPort for Zowe explorer server',
      defaultValue: '8547',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_EXPLORER_UI_JES_PORT',
      description: 'explorerJESUI for Zowe explorer UI',
      defaultValue: '8546',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_EXPLORER_UI_MVS_PORT',
      description: 'explorerMVSUI for Zowe explorer UI',
      defaultValue: '8548',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_EXPLORER_UI_USS_PORT',
      description: 'explorerUSSUI for Zowe explorer UI',
      defaultValue: '8550',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_API_MEDIATION_CATALOG_HTTP_PORT',
      description: 'catalogPort for Zowe API mediation',
      defaultValue: '7552',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT',
      description: 'discoveryPort for Zowe API mediation',
      defaultValue: '7553',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT',
      description: 'gatewayPort for Zowe API mediation',
      defaultValue: '7554',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_MVD_SSH_PORT',
      description: 'sshPort for Zowe MVD terminals',
      defaultValue: '22',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_MVD_TELNET_PORT',
      description: 'telnetPort for Zowe MVD terminals',
      defaultValue: '23',
      trim: true,
      required: true
    ),
    // >>>>>>>> SSH access of testing server zOSaaS layer
    string(
      name: 'TEST_IMAGE_GUEST_SSH_HOST',
      description: 'Test image guest IP',
      defaultValue: 'zzow01.zowe.marist.cloud',
      trim: true,
      required: true
    ),
    string(
      name: 'TEST_IMAGE_GUEST_SSH_PORT',
      description: 'Test image guest SSH port',
      defaultValue: '22',
      trim: true,
      required: true
    ),
    credentials(
      name: 'TEST_IMAGE_GUEST_SSH_CREDENTIAL',
      description: 'The SSH credential used to connect to zD&T test image guest (zOSaaS layer)',
      credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
      defaultValue: 'ssh-marist-server-zzow01',
      required: true
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
    ]
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
          credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL,
          passwordVariable: 'PASSWORD',
          usernameVariable: 'USERNAME'
        )
      ]) {
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
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-zowe.sh > install-zowe.sh.new) && mv install-zowe.sh.new install-zowe.sh && chmod +x install-zowe.sh
./install-zowe.sh -n ${params.TEST_IMAGE_GUEST_SSH_HOST} -t ${params.ZOWE_ROOT_DIR} -i ${params.INSTALL_DIR}${skipTempFixes}${uninstallZowe} --zfp ${params.ZOSMF_PORT}\
  --ds ${params.PROCLIB_DS} --dm ${params.PROCLIB_MEMBER} --jp ${params.ZOWE_JOB_PREFIX}\
  --acp ${params.ZOWE_API_MEDIATION_CATALOG_HTTP_PORT} --adp ${params.ZOWE_API_MEDIATION_DISCOVERY_HTTP_PORT} --agp ${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}\
  --ejp ${params.ZOWE_EXPLORER_JOBS_PORT} --edp ${params.ZOWE_EXPLORER_DATASETS_PORT}\
  --ujp ${params.ZOWE_EXPLORER_UI_JES_PORT} --ump ${params.ZOWE_EXPLORER_UI_MVS_PORT} --uup ${params.ZOWE_EXPLORER_UI_USS_PORT}\
  --zp ${params.ZOWE_ZLUX_HTTPS_PORT} --zsp ${params.ZOWE_ZLUX_ZSS_PORT}\
  --tsp ${params.ZOWE_MVD_SSH_PORT} --ttp ${params.ZOWE_MVD_TELNET_PORT}\
  ${params.INSTALL_DIR}/zowe.pax || { echo "[install-zowe.sh] failed"; exit 1; }
echo "[install-zowe.sh] succeeds" && exit 0
EOF"""
        }

        // wait for Zowe is fully started
        timeout(60) {
          // check if zLux is started
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_ZLUX_HTTPS_PORT}/"
          // check if explorer server is started
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 'https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_EXPLORER_JOBS_PORT}/api/v1/jobs?prefix=ZOWE*&status=ACTIVE'"
          // check if apiml gateway is started
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/"
          // check if apiml catalog is started
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 -d '{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}' 'https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/api/v1/apicatalog/auth/login'"
        }

        // post install verify script
        timeout(30) {
          // always exit 0 to ignore failures in zowe-verify.sh
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  temp-fixes-after-started.sh "${params.ZOWE_ROOT_DIR}" \
    "${USERNAME}" "${PASSWORD}" \
    "${TEST_IMAGE_GUEST_SSH_HOST}" "${ZOWE_ZLUX_HTTPS_PORT}" || { echo "[temp-fixes-after-started.sh] failed"; exit 0; }
echo "[temp-fixes-after-started.sh] succeeds" && exit 0
EOF"""
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
            credentialsId: params.TEST_IMAGE_GUEST_SSH_CREDENTIAL,
            passwordVariable: 'PASSWORD',
            usernameVariable: 'USERNAME'
          )
        ]) {
          sh """ZOWE_ROOT_DIR=${params.ZOWE_ROOT_DIR} \
SSH_HOST=${params.TEST_IMAGE_GUEST_SSH_HOST} \
SSH_PORT=${params.TEST_IMAGE_GUEST_SSH_PORT} \
SSH_USER=${USERNAME} \
SSH_PASSWD=${PASSWORD} \
ZOSMF_PORT=${params.ZOSMF_PORT} \
ZOWE_DS_MEMBER=${params.PROCLIB_MEMBER} \
ZOWE_JOB_PREFIX=${params.ZOWE_JOB_PREFIX} \
ZOWE_ZLUX_HTTPS_PORT=${params.ZOWE_ZLUX_HTTPS_PORT} \
ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT} \
ZOWE_EXPLORER_JOBS_PORT=${params.ZOWE_EXPLORER_JOBS_PORT} \
ZOWE_EXPLORER_DATASETS_PORT=${params.ZOWE_EXPLORER_DATASETS_PORT} \
DEBUG=${params.TEST_CASE_DEBUG_INFORMATION} \
npm test"""
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
