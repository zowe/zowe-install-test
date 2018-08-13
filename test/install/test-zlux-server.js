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
const debug = require('debug')('test:install:explore-server');
const axios = require('axios');
let REQ;

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

before('verify environment variables', function() {
  expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(process.env.ZOWE_ZLUX_URL, 'ZOWE_ZLUX_URL is not defined').to.not.be.empty;

  REQ = axios.create({
    baseURL: process.env.ZOWE_ZLUX_URL,
    timeout: 20000,
  });
});

describe('test zLux server ' + process.env.ZOWE_ZLUX_URL, function() {
  describe('GET /', function() {
    it('should return ok', function() {
      let req = {
        method: 'get',
        url: '/'
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
          expect(res.data).to.include('Mainframe Virtual Desktop');
        });
    })
  });
});
