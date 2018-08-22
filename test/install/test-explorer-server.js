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
  expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
  expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT, 'ZOWE_EXPLORER_SERVER_HTTPS_PORT is not defined').to.not.be.empty;

  REQ = axios.create({
    baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`,
    timeout: 30000,
  });
});

describe(`test explorer server https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`, function() {
  describe('GET /ibm/api/explorer/', function() {
    it('should return ok', function() {
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
          expect(res.data).to.include('<html>');
          expect(res.data).to.include('<title>REST API Documentation</title>');
        });
    });
  });

  describe('GET /Atlas/api/jobs', function() {
    it('should have a job ZOWESVR', function() {
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
          expect(res.data).to.be.an('array');
          expect(res.data).to.have.lengthOf(1);
          expect(res.data[0]).to.have.all.keys('name', 'jobInstances');
          expect(res.data[0].name).to.equal('ZOWESVR');
        });
    });
  });
});
