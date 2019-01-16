/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('test:explorer:api-datasets');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;
const DS_PATTERN_TO_TEST = 'TCPIP.T*';
const DS_TO_TEST = 'TCPIP.TCPIP.DATA';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server datasets api', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_DATASETS_PORT, 'ZOWE_EXPLORER_DATASETS_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_DATASETS_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_DATASETS_PORT}`);
  });

  it(`should be able to list data sets of ${DS_PATTERN_TO_TEST}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/datasets/' + encodeURIComponent(DS_PATTERN_TO_TEST),
      auth: {
        username,
        password,
      }
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
        expect(res.data).to.be.an('array');
        expect(res.data.map(one => one.name)).to.include(DS_TO_TEST);
      });
  });

  it(`should be able to get content of data set ${DS_TO_TEST}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/datasets/' + encodeURIComponent(DS_TO_TEST) + '/content',
      auth: {
        username,
        password,
      }
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
        expect(res.data).to.have.property('records');
        expect(res.data.records).to.be.a('string');
        expect(res.data.records).to.include('TCPIP.DATA');
      });
  });
});
