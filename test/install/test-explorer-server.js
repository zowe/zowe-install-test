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
  expect(process.env.ZOWE_EXPLORER_SERVER, 'ZOWE_EXPLORER_SERVER is not defined').to.not.be.empty;

  REQ = axios.create({
    baseURL: process.env.ZOWE_EXPLORER_SERVER,
    timeout: 30000,
  });
});

describe('test explorer server ' + process.env.ZOWE_EXPLORER_SERVER, function() {
  describe('GET /ibm/api/explorer/', function() {
    it.skip('should return ok', function() {
      let req = {
        method: 'get',
        url: '/ibm/api/explorer/',
        auth: {
          username: process.env.SSH_USER,
          password: process.env.SSH_PASSWD
        }
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
        });
    })
  });

  describe('GET /Atlas/api/jobs', function() {
    it.skip('should have a job ZOWESVR', function() {
      let req = {
        method: 'get',
        url: '/Atlas/api/jobs',
        params: {
          prefix: 'ZOWE*',
          owner: '*'
        },
        auth: {
          username: process.env.SSH_USER,
          password: process.env.SSH_PASSWD
        }
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
        });
    });
  })
});
