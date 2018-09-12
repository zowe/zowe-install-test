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
  DEFAULT_PAGE_LOADING_TIMEOUT,
  saveScreenshot,
  getDefaultDriver,
  waitUntilElement,
  loginMVD,
  launchApp,
  locateApp,
  getElement,
} = require('./utils');
let driver;

const APP_TO_TEST = 'Hello World';


describe(`test ${APP_TO_TEST}`, function() {
  before('verify environment variable and load login page', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

    // init webdriver
    driver = await getDefaultDriver();
    debug('webdriver initialized');

    // load MVD login page
    await loginMVD(
      driver,
      `https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );
  });


  it('should launch app correctly', async function() {
    // load app
    await launchApp(driver, APP_TO_TEST);
    const app = await locateApp(driver, APP_TO_TEST);
    expect(app).to.be.an('object');
    debug('app launched');

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'app-loading');
    addContext(this, file);

    // wait for caption is loaded
    const caption = await waitUntilElement(driver, 'rs-com-mvd-window .heading .caption');
    expect(caption).to.be.an('object');
    debug('caption is ready');
    const captionTest = await caption.getText();
    expect(captionTest).to.be.equal(APP_TO_TEST);
    debug('app caption checked ok');

    // wait for caption is loaded
    const viewport = await waitUntilElement(driver, 'rs-com-mvd-window .body com-rs-mvd-viewport');
    expect(viewport).to.be.an('object');
    debug('app viewport is ready');

    // wait for page is loaded
    const appTitle = await waitUntilElement(driver, 'app-root h1', viewport);
    expect(appTitle).to.be.an('object');
    const appTitleText = await appTitle.getText();
    expect(appTitleText.trim()).to.be.equal('Welcome to app!');
    debug('app is fully loaded');

    // save screenshot
    await saveScreenshot(driver, testName, 'app-loaded');
    addContext(this, file);
  });

  it('should say hello to me', async function() {
    const testMessage = 'Hello Jack';

    // locate app root
    const appRoot = await waitUntilElement(driver, 'rs-com-mvd-window .body com-rs-mvd-viewport app-root');

    // modify input message
    const input = await getElement(driver, 'input', appRoot);
    expect(input).to.be.an('object');
    await input.clear();
    await input.sendKeys(testMessage);
    debug('message updated');

    // submit
    const button = await getElement(driver, 'button', appRoot);
    expect(button).to.be.an('object');
    await button.click();
    debug('send out message');

    // wait for response
    const response = await getElement(driver, 'textarea', appRoot);
    expect(response).to.be.an('object');
    let serverResponseText;
    await driver.wait(
      async function() {
        const text = await response.getText();
        if (text.substr(0, 19) === 'Server replied with') {
          serverResponseText = text;
          return true;
        }

        await driver.sleep(300); // not too fast
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT,
    );
    debug('server responded');
    expect(serverResponseText).to.include(testMessage);

    // save screenshot
    await saveScreenshot(driver, testName, 'say-hello');
    addContext(this, file);
  });

  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
