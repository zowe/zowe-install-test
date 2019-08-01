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

  def smpeReadmePattern = ''
  // some SMP/e build constants/variables
  def smpeHlq           = 'ZOE'
  def smpeHlqCsi        = 'ZOE.SMPE'
  def smpeHlqTzone      = 'ZOE.SMPE'
  def smpeHlqDzone      = 'ZOE.SMPE'
  def smpePathPrefix    = '/tmp/'
  def smpePathZfs       = ''
  def smpeFmid          = ''
  def smpeRelfilePrefix = 'ZOE'
  def artifactsForUploadAndInstallation = [
    "scripts/temp-fixes-before-install.sh",
    "scripts/temp-fixes-after-install.sh",
    "scripts/temp-fixes-after-started.sh",
    "scripts/install-zowe.sh",
    "scripts/uninstall-zowe.sh",
    "scripts/install-SMPE-PAX.sh",
    "scripts/uninstall-SMPE-PAX.sh",
    "scripts/opercmd",
  ]

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
      defaultValue: 'libs-snapshot-local/com/project/zowe/*.pax',
      trim: true,
      required: true
    ),
    string(
      name: 'ZOWE_ARTIFACTORY_BUILD',
      description: 'Zowe artifactory download build',
      defaultValue: 'zowe-install-packaging :: master',
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
    string(
      name: 'ZOWE_ROOT_DIR',
      description: 'Zowe installation root directory',
      defaultValue: '/zaas1/zowe',
      trim: true,
      required: true
    ),
    string(
      name: 'INSTALL_DIR',
      description: 'Installation working directory',
      defaultValue: '/zaas1/zowe-install',
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
    // >>>>>>>> SSH access of testing server Ubuntu layer
    string(
      name: 'TEST_IMAGE_HOST_SSH_HOST',
      description: 'Test image host IP',
      defaultValue: 'river.zowe.org',
      trim: true,
      required: true
    ),
    string(
      name: 'TEST_IMAGE_HOST_SSH_PORT',
      description: 'Test image host SSH port',
      defaultValue: '22',
      trim: true,
      required: true
    ),
    credentials(
      name: 'TEST_IMAGE_HOST_SSH_CREDENTIAL',
      description: 'The SSH credential used to connect to zD&T test image host (Ubuntu layer)',
      credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
      defaultValue: 'ssh-zdt-test-image-host',
      required: true
    ),
    // >>>>>>>> SSH access of testing server zOSaaS layer
    string(
      name: 'TEST_IMAGE_GUEST_SSH_HOST',
      description: 'Test image guest IP',
      defaultValue: 'river.zowe.org',
      trim: true,
      required: true
    ),
    string(
      name: 'TEST_IMAGE_GUEST_SSH_PORT',
      description: 'Test image guest SSH port',
      defaultValue: '2022',
      trim: true,
      required: true
    ),
    credentials(
      name: 'TEST_IMAGE_GUEST_SSH_CREDENTIAL',
      description: 'The SSH credential used to connect to zD&T test image guest (zOSaaS layer)',
      credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
      defaultValue: 'ssh-zdt-test-image-guest',
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
        smpeFmid = sh(
          script: "ls -1 .tmp/AZWE*.pax.Z | head -n 1 | awk -F- '{print \$1}'",
          returnStdout: true
        ).trim()
        // rename and prepare for upload
        sh "mv .tmp/${smpeFmid}*.pax.Z .tmp/${smpeFmid}.pax.Z && mv .tmp/${smpeFmid}*.txt .tmp/${smpeFmid}.readme.txt"
        artifactsForUploadAndInstallation.add(".tmp/${smpeFmid}.pax.Z")
        artifactsForUploadAndInstallation.add(".tmp/${smpeFmid}.readme.txt")
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
      }
    },
    timeout: [time: 20, unit: 'MINUTES']
  )

//   pipeline.createStage(
//     name          : "Reset zOSaaS Image",
//     isSkippable   : true,
//     shouldExecute : {
//       return !params.SKIP_RESET_IMAGE
//     },
//     stage         : {
//       withCredentials([
//         usernamePassword(
//           credentialsId: params.TEST_IMAGE_HOST_SSH_CREDENTIAL,
//           passwordVariable: 'PASSWORD',
//           usernameVariable: 'USERNAME'
//         )
//       ]) {
//         // send script to test image host
//         sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_HOST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_HOST_SSH_HOST} << EOF
// put scripts/refresh-zosaas.sh /home/ibmsys1
// put scripts/temp-fixes-prereqs-image.sh /home/ibmsys1
// chmod 755 /home/ibmsys1/refresh-zosaas.sh
// chmod 755 /home/ibmsys1/temp-fixes-prereqs-image.sh
// EOF"""

//         // run refresh-zosaas.sh
//         timeout(90) {
//           sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_HOST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_HOST_SSH_HOST} << EOF
// ~/refresh-zosaas.sh
// exit 0
// EOF"""
//         }

//         // wait a while before testing z/OSMF
//         sleep time: 10, unit: 'MINUTES'
//         // check if zD&T & z/OSMF are started
//         timeout(120) {
//           sh "./scripts/is-website-ready.sh -r 720 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOSMF_PORT}/zosmf/info"
//         }
//       }
//     },
//     timeout: [time: 120, unit: 'MINUTES']
//   )

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
        def allPuts = artifactsForUploadAndInstallation.collect {
          "put ${it}"
        }.join("\n")
        sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR}
${allPuts}
EOF"""

        // run install-zowe.sh
        timeout(60) {
          def skipTempFixes = ""
          Boolean uninstallZowe = false
          if (params.SKIP_TEMP_FIXES) {
            skipTempFixes = " -s"
          }
          if (params.SKIP_RESET_IMAGE) {
            // if we are not resetting image, we need to uninstall Zowe first
            uninstallZowe = true
          }
          // FIXME: since we are not resetting image, we always need to run uninstall
          uninstallZowe = true
          if (uninstallZowe) {
            // FIXME: modify uninstall-zowe.sh to uninstall Zowe installed with SMP/e package
            // FIXME: since we don't know what's the last installation is with regular PAX or SMP/e package,
            //        we need to test and uninstall both of them.
            sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  (iconv -f ISO8859-1 -t IBM-1047 uninstall-zowe.sh > uninstall-zowe.sh.new) && mv uninstall-zowe.sh.new uninstall-zowe.sh && chmod +x uninstall-zowe.sh \
  (iconv -f ISO8859-1 -t IBM-1047 uninstall-SMPE-PAX.sh > uninstall-SMPE-PAX.sh.new) && mv uninstall-SMPE-PAX.sh.new uninstall-SMPE-PAX.sh && chmod +x uninstall-SMPE-PAX.sh
./uninstall-zowe.sh -i ${params.INSTALL_DIR} -t ${params.ZOWE_ROOT_DIR} -m ${params.PROCLIB_MEMBER} || { echo "[uninstall-zowe.sh] failed"; exit 0; }
./uninstall-SMPE-PAX.sh || { echo "[uninstall-SMPE-PAX.sh] failed"; exit 0; }
echo "[uninstall-zowe.sh] succeeds" && exit 0
EOF"""
          }

          if (params.IS_SMPE_PACKAGE) {
            smpePathZfs = "${params.INSTALL_DIR}/zowe/smpe"
            sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-SMPE-PAX.sh > install-SMPE-PAX.sh.new) && mv install-SMPE-PAX.sh.new install-SMPE-PAX.sh && chmod +x install-SMPE-PAX.sh
./install-SMPE-PAX.sh \
  ${smpeHlq} \
  ${smpeHlqCsi} \
  ${smpeHlqTzone} \
  ${smpeHlqDzone} \
  ${smpePathPrefix} \
  ${params.INSTALL_DIR} \
  ${smpePathZfs} \
  ${smpeFmid} \
  ${smpeRelfilePrefix} || { echo "[install-SMPE-PAX.sh] failed"; exit 1; }
echo "[install-SMPE-PAX.sh] done, start configuring ..."
. ${smpePathPrefix}/scripts/configure/zowe-configure.sh
echo "[zowe-configure.sh] done, starting Zowe ..."
. ${smpePathPrefix}/scripts/zowe-start.sh
exit 0
EOF"""
          } else {
            sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.TEST_IMAGE_GUEST_SSH_PORT} ${USERNAME}@${params.TEST_IMAGE_GUEST_SSH_HOST} << EOF
cd ${params.INSTALL_DIR} && \
  (iconv -f ISO8859-1 -t IBM-1047 install-zowe.sh > install-zowe.sh.new) && mv install-zowe.sh.new install-zowe.sh && chmod +x install-zowe.sh
./install-zowe.sh -n ${params.TEST_IMAGE_GUEST_SSH_HOST} -t ${params.ZOWE_ROOT_DIR} -i ${params.INSTALL_DIR}${skipTempFixes} --zfp ${params.ZOSMF_PORT}\
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
        }

        // wait a while before testing zLux
        sleep time: 2, unit: 'MINUTES'
        // check if zLux is started
        timeout(60) {
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_ZLUX_HTTPS_PORT}/"
        }
        // check if explorer server is started
        timeout(60) {
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 'https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_EXPLORER_JOBS_PORT}/api/v1/jobs?prefix=ZOWE*&status=ACTIVE'"
        }
        // check if apiml gateway is started
        timeout(60) {
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 https://${USERNAME}:${PASSWORD}@${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/"
        }
        // check if apiml catalog is started
        timeout(60) {
          sh "./scripts/is-website-ready.sh -r 360 -t 10 -c 20 -d '{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}' 'https://${params.TEST_IMAGE_GUEST_SSH_HOST}:${params.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/api/v1/apicatalog/auth/login'"
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
