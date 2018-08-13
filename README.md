# Zowe Install Test

Perform Zowe installation and run smoke/integration tests

## Execute Pipeline on Local

- Follow instruction https://ibm.ent.box.com/notes/300587046955 to prepare zD&T image (with Zowe pre-reqs image) on your local computer.
- Follow instruction [Start Testing Jenkins Server Locally](https://github.com/gizafoundation/jenkins#start-testing-jenkins-server-locally) to start Jenkins on local computer.
- Create multiple branch pipeline job from current repository.

## Run test cases manually

Example command:

```
ZOWE_ROOT_DIR=/zaas1/zowe \
  SSH_HOST=localhost \
  SSH_PORT=12022 \
  SSH_USER=tstradm \
  SSH_PASSWD=********* \
  ZOSMF_URL=https://localhost:10443/zosmf/ \
  ZOWE_ZLUX_URL=https://localhost:8544/ \
  ZOWE_EXPLORER_SERVER=https://localhost:7443/ \
  npm test
```
