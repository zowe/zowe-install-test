/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

const path = require('path');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:login');
const testName = path.basename(__filename, path.extname(__filename));

const { until, By } = require('selenium-webdriver');

const {
  DEFAULT_PAGE_LOADING_TIMEOUT,
  saveScreenshot,
  getDefaultDriver,
} = require('./utils');
let driver;

before('verify environment variable and load login page', async function() {
  expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
  expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

  // init webdriver
  driver = await getDefaultDriver();
  debug('webdriver initialized');

  // load MVD login page
  debug('- loading login page');
  await driver.get(`https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`);
  await driver.wait(
    until.elementLocated(By.css('#\\#loginButton')),
    DEFAULT_PAGE_LOADING_TIMEOUT
  );
  const file = await saveScreenshot(driver, testName, 'login');
  debug(`- login page is loaded, screenshot: ${file}`);
});

describe('test MVD login page', function() {
  it('should redirect to login page', async function() {
    const title = await driver.getTitle();
    expect(title).to.be.equal('Mainframe Virtual Desktop');
  });

  it('should show error with wrong login password', async function() {
    var loginForm = await driver.findElement(By.css('form.login-form'));
    var usernameInput = await loginForm.findElement(By.css('input#usernameInput'));
    var passwordInput = await loginForm.findElement(By.css('input#passwordInput'));
    let loginButton = await driver.findElement(By.css('#\\#loginButton'));
    await usernameInput.sendKeys(process.env.SSH_USER);
    await passwordInput.sendKeys('wrong+passdword!');
    await loginButton.click();
    await driver.wait(async function() {
        let error = await driver.findElement(By.css('p.login-error')).getText();
        error = error.trim();

        if (error && error !== '&nbsp;') {
          debug('login error message returned: %s', error);
          return true;
        }
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );

    const file = await saveScreenshot(driver, testName, 'login-wrong-password');
    debug(`- login error returned, screenshot: ${file}`);
  });
});

after('quit webdriver', async function() {
  // quit webdriver
  await driver.quit();
});
