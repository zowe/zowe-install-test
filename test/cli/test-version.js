/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

const expect = require('chai').expect;
const debug = require('debug')('test:cli:version');
const util = require('util');
const exec = util.promisify(require('child_process').exec);

describe('cli version', function() {
  it.skip('command should return version without error', async function() {
    const result = await exec('bright --version');

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.equal('1.0.1\n');
  });
});
