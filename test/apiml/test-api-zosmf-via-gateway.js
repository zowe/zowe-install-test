/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('test:explorer:api-zos');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ;

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server zos api', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.CI_APIM_GATEWAY_PORT, 'CI_APIM_GATEWAY_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.CI_APIM_GATEWAY_PORT}`,
      timeout: 30000,
      headers: {'X-CSRF-ZOSMF-HEADER': ''}
    });
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.CI_APIM_GATEWAY_PORT}`);
  });

  it('should be able to get z/OS Info via the gateway port and endpoint (/api/v1/zosmf/info)', function() {
    const _this = this;
    const req = {
      method: 'get',
      url: '/api/v1/zosmf/info',
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data).to.be.an('object');
        expect(res.data).to.have.property('api_version');
        expect(res.data).to.have.property('plugins');
        expect(res.data).to.have.property('zosmf_full_version');
        expect(res.data).to.have.property('zos_version');
      });
  });
});
