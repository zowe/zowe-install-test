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
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));

const {
  PRE_INSTALLED_APPS,
  DEFAULT_PAGE_LOADING_TIMEOUT,
  getElements,
  getElement,
  getElementText,
  waitUntilElement,
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
  await waitUntilElement(driver, '#\\#loginButton');
});

describe('test MVD login page', function() {

  it('should redirect to login page', async function() {
    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login');
    addContext(this, file);

    const title = await driver.getTitle();
    expect(title).to.be.equal('Mainframe Virtual Desktop');
  });


  it('should show error with wrong login password', async function() {
    const loginForm = await getElement(driver, 'form.login-form');
    expect(loginForm).to.be.an('object');
    // fill in login form
    let usernameInput = await getElement(loginForm, 'input#usernameInput');
    expect(usernameInput).to.be.an('object');
    await usernameInput.clear();
    await usernameInput.sendKeys(process.env.SSH_USER);
    let passwordInput = await getElement(loginForm, 'input#passwordInput');
    expect(passwordInput).to.be.an('object');
    await passwordInput.clear();
    await passwordInput.sendKeys('wrong+passdword!');
    // submit login
    let loginButton = await getElement(driver, '#\\#loginButton');
    expect(loginButton).to.be.an('object');
    await loginButton.click();
    // wait for login error
    await driver.wait(
      async() => {
        let result = false;

        if (!result) {
          let error = await getElementText(driver, 'p.login-error');
          if (error !== false) {
            error = error.trim();
            if (error && error !== '&nbsp;') {
              debug('login error message returned: %s', error);
              result = true;
            }
          }
        }

        await driver.sleep(300); // not too fast
        return result;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-wrong-password');
    addContext(this, file);

    // make sure we got authentication error
    let error = await getElementText(driver, 'p.login-error');
    expect(error).to.be.a('string');
    error = error.trim();
    expect(error).to.include('Authentication failed');
  });


  it('should login successfully with correct password', async function() {
    const loginForm = await getElement(driver, 'form.login-form');
    expect(loginForm).to.be.an('object');
    // fill in login form
    let usernameInput = await getElement(loginForm, 'input#usernameInput');
    expect(usernameInput).to.be.an('object');
    await usernameInput.clear();
    await usernameInput.sendKeys(process.env.SSH_USER);
    let passwordInput = await getElement(loginForm, 'input#passwordInput');
    expect(passwordInput).to.be.an('object');
    await passwordInput.clear();
    await passwordInput.sendKeys(process.env.SSH_PASSWD);
    // submit login
    let loginButton = await getElement(driver, '#\\#loginButton');
    expect(loginButton).to.be.an('object');
    await loginButton.click();
    // wait for login error or successfully
    await driver.wait(
      async() => {
        let result = false;

        if (!result) {
          let error = await getElementText(driver, 'p.login-error');
          if (error !== false) {
            error = error.trim();
            if (error && error !== '&nbsp;') {
              debug('login error message returned: %s', error);
              // authentication failed, no need to wait anymore
              result = true;
            }
          }
        }

        if (!result) {
          const loginPanel = await getElement(driver, 'div.login-panel', false);
          const isDisplayed = await loginPanel.isDisplayed();
          if (!isDisplayed) {
            debug('login panel is hidden, login should be successfully');
            result = true;
          }
        }

        await driver.sleep(300); // not too fast
        return result;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-successfully');
    addContext(this, file);

    // make sure we are not hitting login error
    let error = await getElementText(driver, 'p.login-error', false);
    expect(error).to.be.a('string');
    error = error.trim();
    expect(error).to.be.oneOf(['', '&nbsp;']);

    // launchbar should exist
    const launchbar = await getElement(driver, 'rs-com-launchbar');
    expect(launchbar).to.be.an('object');

    // check we have known apps launched
    const apps = await getElements(driver, 'rs-com-launchbar-icon');
    expect(apps).to.be.an('array').that.have.lengthOf(PRE_INSTALLED_APPS.length);
    for (let app of apps) {
      let icon = await getElement(app, 'div.launchbar-icon');
      let title = await icon.getAttribute('title');
      expect(title).to.be.oneOf(PRE_INSTALLED_APPS);
    }
  });


  it('should be able to popup apps menu', async function() {
    // menu should exist
    const menu = await getElement(driver, 'rs-com-launchbar-menu');
    expect(menu).to.be.an('object');
    const menuIcon = await getElement(menu, '.launchbar-icon');
    expect(menuIcon).to.be.an('object');

    // popup menu
    await menuIcon.click();
    await driver.sleep(1000);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'apps-menu-popped');
    addContext(this, file);

    // check popup menu existence
    const popup = await getElement(driver, 'rs-com-launchbar-menu .launch-widget-popup');
    expect(popup).to.be.an('object');

    // check popup menu items
    const menuItems = await getElements(popup, '.launch-widget-row > p');
    expect(menuItems).to.be.an('array').that.have.lengthOf(PRE_INSTALLED_APPS.length);
    for (let item of menuItems) {
      let text = await item.getText();
      expect(text).to.be.oneOf(PRE_INSTALLED_APPS);
    }
  });


  it('should be able to logout', async function() {
    // widget should exist
    const widget = await getElement(driver, 'rs-com-launchbar-widget');
    expect(widget).to.be.an('object');
    const clock = await getElement(widget, '.launchbar-clock');
    expect(clock).to.be.an('object');
    const userIcon = await getElement(widget, '.launchbar-user');
    expect(userIcon).to.be.an('object');

    // popup user info
    await userIcon.click();
    await driver.sleep(1000);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'user-info-popped');
    addContext(this, file);

    // check popup menu existence
    const popup = await getElement(widget, '.launchbar-user-popup');
    expect(popup).to.be.an('object');

    // check popup menu
    const usernameText = await getElementText(popup, 'h5');
    expect(usernameText).to.equal(process.env.SSH_USER);

    const signout = await getElement(popup, 'button');
    expect(signout).to.be.an('object');
    const signoutText = await signout.getText();
    expect(signoutText).to.equal('Sign Out');

    await signout.click();
    await waitUntilElement(driver, '#\\#loginButton');

    // save screenshot
    const file2 = await saveScreenshot(driver, testName, 'user-logout');
    addContext(this, file2);

    // logged out
    const loginPanel = await getElement(driver, 'div.login-panel');
    expect(loginPanel).to.be.an('object');
  });
});


after('quit webdriver', async function() {
  // quit webdriver
  await driver.quit();
});
