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

const { By } = require('selenium-webdriver');

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
    // until.elementLocated(By.css('#\\#loginButton')),
    async() => {
      let isDisplayed = false;
      try {
        const loginButton = await driver.findElement(By.css('#\\#loginButton'));
        isDisplayed = await loginButton.isDisplayed();
      } catch (err) {
        // don't care about errors, especially NoSuchElementError
      }
      await driver.sleep(300); // not too fast
      return isDisplayed;
    },
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
    const loginForm = await driver.findElement(By.css('form.login-form'));
    // fill in login form
    let usernameInput = await loginForm.findElement(By.css('input#usernameInput'));
    await usernameInput.clear();
    await usernameInput.sendKeys(process.env.SSH_USER);
    let passwordInput = await loginForm.findElement(By.css('input#passwordInput'));
    await passwordInput.clear();
    await passwordInput.sendKeys('wrong+passdword!');
    // submit login
    let loginButton = await driver.findElement(By.css('#\\#loginButton'));
    await loginButton.click();
    // wait for login error
    await driver.wait(async() => {
      let result = false;

      if (!result) {
        let error = await driver.findElement(By.css('p.login-error')).getText();
        error = error.trim();
        if (error && error !== '&nbsp;') {
          debug('login error message returned: %s', error);
          result = true;
        }
      }

      await driver.sleep(300); // not too fast
      return result;
    },
    DEFAULT_PAGE_LOADING_TIMEOUT);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-wrong-password');
    debug(`- login error returned, screenshot: ${file}`);

    // make sure we got authentication error
    let error = await driver.findElement(By.css('p.login-error')).getText();
    error = error.trim();
    expect(error).to.include('Authentication failed');
  });


  it('should login successfully with correct password', async function() {
    const loginForm = await driver.findElement(By.css('form.login-form'));
    // fill in login form
    let usernameInput = await loginForm.findElement(By.css('input#usernameInput'));
    await usernameInput.clear();
    await usernameInput.sendKeys(process.env.SSH_USER);
    let passwordInput = await loginForm.findElement(By.css('input#passwordInput'));
    await passwordInput.clear();
    await passwordInput.sendKeys(process.env.SSH_PASSWD);
    // submit login
    let loginButton = await driver.findElement(By.css('#\\#loginButton'));
    await loginButton.click();
    // wait for login error or successfully
    await driver.wait(async() => {
      let result = false;

      if (!result) {
        let error = await driver.findElement(By.css('p.login-error')).getText();
        error = error.trim();
        if (error && error !== '&nbsp;') {
          debug('login error message returned: %s', error);
          // authentication failed, no need to wait anymore
          result = true;
        }
      }

      if (!result) {
        const loginPanel = await driver.findElement(By.css('div.login-panel'));
        const isDisplayed = await loginPanel.isDisplayed();
        if (!isDisplayed) {
          debug('login panel is hidden, login should be successfully');
          result = true;
        }
      }

      await driver.sleep(300); // not too fast
      return result;
    },
    DEFAULT_PAGE_LOADING_TIMEOUT);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-successfully');
    debug(`- login successfully returned, screenshot: ${file}`);

    // make sure we are not hitting login error
    let error = await driver.findElement(By.css('p.login-error')).getText();
    error = error.trim();
    expect(error).to.be.oneOf(['', '&nbsp;']);
  });
});


after('quit webdriver', async function() {
  // quit webdriver
  await driver.quit();
});
