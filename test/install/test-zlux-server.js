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
  expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

  REQ = axios.create({
    baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`,
    timeout: 20000,
  });
});

describe(`test zLux server https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`, function() {
  describe('GET /', function() {
    it('should redirect to /ZLUX/plugins/com.rs.mvd/web/', function() {
      let req = {
        method: 'get',
        url: '/',
        maxRedirects: 0,
      };
      debug('request', req);

      return REQ.request(req)
        .catch(function(err) {
          debug('response err', err);
          expect(err).to.have.property('response');
          const res = err.response;
          expect(res.status).to.equal(302);
          expect(res.headers).to.have.property('location');
          expect(res.headers.location).to.equal('/ZLUX/plugins/com.rs.mvd/web/');
        });
    });
  });

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
    });
  });

  describe('GET /ZLUX/plugins', function() {
    it('/com.ibm.atlas.atlasJES/web/index.html should return ok', function() {
      let req = {
        method: 'get',
        url: '/ZLUX/plugins/com.ibm.atlas.atlasJES/web/index.html'
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
          expect(res.data).to.include('<html>');
          expect(res.data).to.include('<body>');
        });
    });

    it('/com.ibm.atlas.atlasMVS/web/index.html should return ok', function() {
      let req = {
        method: 'get',
        url: '/ZLUX/plugins/com.ibm.atlas.atlasMVS/web/index.html'
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
          expect(res.data).to.include('<html>');
          expect(res.data).to.include('<body>');
        });
    });

    it('/com.ibm.atlas.atlasUSS/web/index.html should return ok', function() {
      let req = {
        method: 'get',
        url: '/ZLUX/plugins/com.ibm.atlas.atlasUSS/web/index.html'
      };
      debug('request', req);

      return REQ.request(req)
        .then(function(res) {
          debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
          expect(res).to.have.property('status');
          expect(res.status).to.equal(200);
          expect(res.data).to.include('<html>');
          expect(res.data).to.include('<body>');
        });
    });
  });
});
