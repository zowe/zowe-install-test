/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

/*eslint no-console: ["error", { allow: ["log", "warn", "error"] }] */

const expect = require('chai').expect;
const debug = require('debug')('test:cli:jobs');
const fs = require('fs');
const util = require('util');
const fsReadfile = util.promisify(fs.readFile);
const addContext = require('mochawesome/addContext');

const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

const TCPIP_DATA_DSNAME = 'TCPIP.TCPIP.DATA';

describe('cli list data sets of tcpip.*', function() {
  before('verify environment variables', async function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    const result = await createDefaultZOSMFProfile(
      process.env.SSH_HOST,
      process.env.ZOSMF_PORT,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.have.string('Profile created successfully');
  });

  it(`should have an data set of ${TCPIP_DATA_DSNAME}`, async function() {
    const result = await execZoweCli(`zowe zos-files list data-set "tcpip.*" --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    addContext(this, {
      title: 'cli result',
      value: result
    });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('object');
    expect(res.data.success).to.be.true;
    expect(res.data.apiResponse).to.be.an('object');
    expect(res.data.apiResponse.items).to.be.an('array');
    const dsIndex = res.data.apiResponse.items.findIndex(item => item.dsname === TCPIP_DATA_DSNAME);
    debug(`found ${TCPIP_DATA_DSNAME} at ${dsIndex}`);
    expect(dsIndex).to.be.above(-1);
  });

  it('should be able to download file', async function() {
    const targetFile = '.tmp/' + TCPIP_DATA_DSNAME.replace(/\./g, '-') + '.txt';
    const result = await execZoweCli(`zowe zos-files download data-set ${TCPIP_DATA_DSNAME} --file "${targetFile}" --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    addContext(this, {
      title: 'cli result',
      value: result
    });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('object');
    expect(res.data.success).to.be.true;
    expect(res.data.commandResponse).to.be.a('string');
    expect(res.data.commandResponse).to.include('Data set downloaded successfully');
    expect(res.data.apiResponse).to.be.a('object');
    expect(res.data.apiResponse.type).to.be.a('string');
    expect(res.data.apiResponse.type).to.include('Buffer');

    // file should be downloaded
    const file = await fsReadfile(targetFile);
    expect(file.toString()).to.include('Name of Data Set:');
  });
});
