/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

const fs = require('fs');
const path = require('path');
const debug = require('debug')('test:cli:utils');
const url = require('url');
const util = require('util');
const exec = util.promisify(require('child_process').exec);
const writeFile = util.promisify(fs.writeFile);
const chmod = util.promisify(fs.chmod);

const wrapperFileName = 'zowe-cli-command-wrapper.sh';
const wrapperFileContent = `#!/usr/bin/env bash

# Unlock the keyring
echo 'jenkins' | gnome-keyring-daemon --unlock

# Your commands here
`;

const execZoweCli = async(command) => {
  let result;

  let keyringExists = false;

  try {
    keyringExists = await exec('which gnome-keyring-daemon');
    if (keyringExists && keyringExists.stdout && keyringExists.stdout.trim() !== '') {
      keyringExists = await exec('which dbus-launch');
      if (keyringExists && keyringExists.stdout && keyringExists.stdout.trim() !== '') {
        keyringExists = true;
      }
    }
  } catch (e) {
    keyringExists = false;
  }

  if (keyringExists) {
    const fn = path.join(__dirname, wrapperFileName);

    await writeFile(fn, wrapperFileContent + command);
    await chmod(fn, 0o755);
    result = await exec(`dbus-launch ${fn}`);
  } else {
    result = await exec(command);
  }

  debug('cli result:', result);

  return result;
};

const defaultZOSMFProfileName = 'zowe-install-test';
const createDefaultZOSMFProfile = async() => {
  const zosmfUrl = url.parse(`https://${process.env.SSH_HOST}:${process.env.ZOSMF_PORT}/zosmf/`);
  const command = [
    'bright',
    'profiles',
    'create',
    'zosmf-profile',
    defaultZOSMFProfileName,
    '--host',
    zosmfUrl.hostname,
    '--port',
    zosmfUrl.port,
    '--user',
    process.env.SSH_USER,
    '--password',
    process.env.SSH_PASSWD,
    '--reject-unauthorized',
    'false',
    '--overwrite',
  ];

  return await execZoweCli(command.join(' '));
};

module.exports = {
  execZoweCli,
  defaultZOSMFProfileName,
  createDefaultZOSMFProfile,
};
