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
const debug = require('debug')('test:explorer:docs');
const axios = require('axios');

let REQ, username, password;

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server docs', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT, 'ZOWE_EXPLORER_SERVER_HTTPS_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`);
  });

  it('should be able to access Swagger UI (/ibm/api/explorer/)', function() {
    const req = {
      method: 'get',
      url: '/ibm/api/explorer/',
      auth: {
        username,
        password,
      },
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

  it('should be able to access Swagger JSON file (/ibm/api/docs)', function() {
    const req = {
      method: 'get',
      url: '/ibm/api/docs',
      params: {
        compact: 'true',
        displayPorts: 'true',
      },
      auth: {
        username,
        password,
      },
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data).to.be.an('object');
        expect(res.data).to.nested.include({
          'swagger': '2.0',
          'x-ibm-services[0]': '/Atlas',
        });
        expect(res.data).to.have.nested.property('paths./Atlas/api/system/version');
        expect(res.data).to.have.nested.property('paths./Atlas/api/jobs');
        expect(res.data).to.have.nested.property('paths./Atlas/api/datasets/{filter}');
        expect(res.data).to.have.nested.property('paths./Atlas/api/uss/files');
      });
  });

});
