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

  def artifactsForUploadAndInstallation = [
    "scripts/temp-fixes-before-install.sh",
    "scripts/temp-fixes-after-install.sh",
    "scripts/temp-fixes-after-started.sh",
    "scripts/install-zowe.sh",
    "scripts/install-config.sh",
    "scripts/install-xmem-server.sh",
    "scripts/uninstall-zowe.sh",
    "scripts/install-SMPE-PAX.sh",
    "scripts/uninstall-SMPE-PAX.sh",
    "scripts/opercmd",
  ]
  def zoweArtifact = ''
  def zoweRootDir = ''
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
    booleanParam(
      name: 'IS_SMPE_PACKAGE',
      description: 'If ZOWE_ARTIFACTORY_PATTERN is referring to a SMPE package.',
      defaultValue: false
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
      choices: ['marist', 'river', 'river-c3'],
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

      zoweRootDir = sh(
        script: ". scripts/install-config.sh && echo \$CIZT_ZOWE_ROOT_DIR",
        returnStdout: true
      ).trim()
      if (params.IS_SMPE_PACKAGE) {
        // overwrite CIZT_ZOWE_ROOT_DIR for SMP/e package.
        zoweRootDir = sh(
          script: ". scripts/install-config.sh && echo \"\$CIZT_SMPE_PATH_PREFIX\$CIZT_SMPE_PATH_DEFAULT\"",
          returnStdout: true
        ).trim()
        sh """
echo "[scripts/install-config.sh] before updating ..."
cat scripts/install-config.sh | grep CIZT_ZOWE_ROOT_DIR
sed -e 's#CIZT_ZOWE_ROOT_DIR=.*\$#CIZT_ZOWE_ROOT_DIR=${zoweRootDir}#' \
  scripts/install-config.sh > scripts/install-config.sh.tmp
mv scripts/install-config.sh.tmp scripts/install-config.sh
echo "[scripts/install-config.sh] after updated ..."
cat scripts/install-config.sh | grep CIZT_ZOWE_ROOT_DIR
"""
        echo "CIZT_ZOWE_ROOT_DIR is updated to ${zoweRootDir}"
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
      if (params.SKIP_INSTALLATION) {
        pipeline.artifactory.download(
          specContent : """
{
  "files": [{
    "pattern": "${params.ZOWE_CLI_ARTIFACTORY_PATTERN}",
    "target": ".tmp/",
    "flat": "true",
    "build": "${params.ZOWE_CLI_ARTIFACTORY_BUILD}",
    "explode": "true"
  }]
}
""",
          expected    : 1
        )
      } else if (params.IS_SMPE_PACKAGE) {
        def smpeReadmePattern = ''
        if (params.ZOWE_ARTIFACTORY_PATTERN =~ /\/[^\/-]+-[0-9]+\.[0-9]+\.[0-9]+-[^\/]+\.pax\.Z$/) {
          // the pattern is a static path pointing to one pax.Z file
          smpeReadmePattern = params.ZOWE_ARTIFACTORY_PATTERN.replaceAll(/\/([^\/-]+)-([0-9]+\.[0-9]+\.[0-9]+-[^\/]+)\.pax\.Z$/, "/\$1.readme-\$2.txt")
        } else if (params.ZOWE_ARTIFACTORY_PATTERN =~ /\/[^\/]+\.pax\.Z$/) {
          // the pattern is not a static path but including *
          smpeReadmePattern = params.ZOWE_ARTIFACTORY_PATTERN.replaceAll(/\/([^\/]+)\.pax\.Z$/, "/\$1.txt")
        } else {
          error "The Zowe SMP/e package pattern (ZOWE_ARTIFACTORY_PATTERN) should end with .pax.Z"
        }
        pipeline.artifactory.download(
          specContent : """
{
  "files": [{
    "pattern": "${params.ZOWE_ARTIFACTORY_PATTERN}",
    "target": ".tmp/",
    "flat": "true",
    "build": "${params.ZOWE_ARTIFACTORY_BUILD}"
  }, {
    "pattern": "${smpeReadmePattern}",
    "target": ".tmp/",
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
          expected    : 3
        )
        // extract FMID from downloaded artifact
        def smpeFmid = sh(
          script: "cd .tmp && ls -1 AZWE*.pax.Z | head -n 1 | awk -F- '{print \$1}'",
          returnStdout: true
        ).trim()
        // rename and prepare for upload
        sh "mv .tmp/${smpeFmid}*.pax.Z .tmp/${smpeFmid}.pax.Z && mv .tmp/${smpeFmid}*.txt .tmp/${smpeFmid}.readme.txt"
        artifactsForUploadAndInstallation.add(".tmp/${smpeFmid}.pax.Z")
        artifactsForUploadAndInstallation.add(".tmp/${smpeFmid}.readme.txt")
        zoweArtifact = "${smpeFmid}.pax.Z"
      } else {
        pipeline.artifactory.download(
          specContent : """
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
        artifactsForUploadAndInstallation.add(".tmp/zowe.pax")
        zoweArtifact = 'zowe.pax'
      }
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
        def allPuts = artifactsForUploadAndInstallation.collect {
          "put ${it}"
        }.join("\n")
        sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${SSH_PORT} ${USERNAME}@${SSH_HOST} << EOF
cd ${installDir}
${allPuts}
EOF"""

        // run install-zowe.sh
        timeout(90) {
          def skipTempFixes = ""
          if (params.SKIP_TEMP_FIXES) {
            skipTempFixes = " -s"
          }
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${SSH_PORT} ${USERNAME}@${SSH_HOST} << EOF
cd ${installDir} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-zowe.sh > install-zowe.sh.new) && mv install-zowe.sh.new install-zowe.sh && chmod +x install-zowe.sh
./install-zowe.sh --uninstall -n ${SSH_HOST}${skipTempFixes} \
  ${installDir}/${zoweArtifact} || { echo "[install-zowe.sh] failed"; exit 1; }
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
ZOWE_ROOT_DIR=${zoweRootDir} \
SSH_HOST=${SSH_HOST} \
SSH_PORT=${SSH_PORT} \
SSH_USER=${USERNAME} \
SSH_PASSWD=${PASSWORD} \
ZOSMF_PORT=\${CIZT_ZOSMF_PORT} \
ZOWE_DS_MEMBER=\${CIZT_PROCLIB_MEMBER} \
ZOWE_JOB_PREFIX=\${CIZT_ZOWE_JOB_PREFIX} \
ZOWE_ZLUX_HTTPS_PORT=\${CIZT_ZOWE_ZLUX_HTTPS_PORT} \
ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT=\${CIZT_ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT} \
ZOWE_EXPLORER_JOBS_PORT=\${CIZT_ZOWE_EXPLORER_JOBS_PORT} \
ZOWE_EXPLORER_DATASETS_PORT=\${CIZT_ZOWE_EXPLORER_DATASETS_PORT} \
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
