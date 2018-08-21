# Zowe Install Test

Perform Zowe installation and run smoke/integration tests

## Run test cases manually

Example command:

```
ZOWE_ROOT_DIR=/path/to/zowe \
  SSH_HOST=test-server \
  SSH_PORT=12022 \
  SSH_USER=********* \
  SSH_PASSWD=********* \
  ZOSMF_PORT=10443 \
  ZOWE_ZLUX_HTTPS_PORT=8544 \
  ZOWE_EXPLORER_SERVER_HTTPS_PORT=7443 \
  npm test
```
