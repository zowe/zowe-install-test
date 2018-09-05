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

const { Key, until } = require('selenium-webdriver');

const {
  ZOWE_JOB_NAME,
  DEFAULT_PAGE_LOADING_TIMEOUT,
  saveScreenshot,
  getDefaultDriver,
  getElement,
  getElements,
  waitUntilElement,
  waitUntilElementIsGone,
  waitUntilIframe,
  loginMVD,
  launchApp,
  locateApp,
} = require('./utils');
let driver;

const APP_TO_TEST = 'JES Explorer';

const switchToContext = async(driver, contexts) => {
  debug('[switchToContext] started');
  const app = await locateApp(driver, APP_TO_TEST);
  for (let i in contexts) {
    debug(`[switchToContext] - ${i}: ${contexts[i]}`);
    if (i === 0) {
      await waitUntilIframe(driver, contexts[i], app);
    } else {
      await waitUntilIframe(driver, contexts[i]);
    }
  }
  debug('[switchToContext] done');
};

const saveScreenshotWithContext = async(testcase, driver, testName, screenshot, contexts) => {
  debug('[saveScreenshotWithContext] started');
  await driver.switchTo().defaultContent();
  const file = await saveScreenshot(driver, testName, screenshot);
  addContext(testcase, file);
  switchToContext(driver, contexts);
  debug('[saveScreenshotWithContext] done');
};

before('verify environment variable and load login page', async function() {
  expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
  expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

  // init webdriver
  driver = await getDefaultDriver();
  debug('webdriver initialized');

  // load MVD login page
  await loginMVD(driver);
});

describe('test jes explorer', function() {

  it('should launch app correctly', async function() {
    // load app
    await launchApp(driver, APP_TO_TEST);
    const app = await locateApp(driver, APP_TO_TEST);
    expect(app).to.be.an('object');

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'app-loading');
    addContext(this, file);

    // locate app iframe
    const iframe = await waitUntilIframe(driver, 'rs-com-mvd-iframe-component > iframe', app);
    expect(iframe).to.be.an('object');

    // wait for atlas iframe
    const atlas = await waitUntilIframe(driver, 'iframe#atlasIframe');
    expect(atlas).to.be.an('object');

    // FIXME: shouldn't pop out authentication
    const alert = await driver.wait(until.alertIsPresent(), DEFAULT_PAGE_LOADING_TIMEOUT);
    await alert.sendKeys(process.env.SSH_USER + Key.TAB + process.env.SSH_PASSWD);
    await alert.accept();
    // to avoid StaleElementReferenceError, find the iframes context again
    await switchToContext(driver, ['rs-com-mvd-iframe-component > iframe', 'iframe#atlasIframe']);

    // wait for page is loaded
    let treeContent = await waitUntilElement(driver, '#tree-text-content');
    expect(treeContent).to.be.an('object');
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);

    // save screenshot
    await saveScreenshotWithContext(this, driver, testName, 'app-loaded', ['rs-com-mvd-iframe-component > iframe', 'iframe#atlasIframe']);
    treeContent = await waitUntilElement(driver, '#tree-text-content');

    // expand filter
    const filter = await getElement(treeContent, '#filter-view');
    expect(filter).to.be.an('object');
    await filter.click();

    // fill in filters
    const filterInputs = await getElements(treeContent, 'input');
    for (let input of filterInputs) {
      const id = await input.getAttribute('id');
      if (id.indexOf('-Owner-') > -1) {
        await input.clear();
        await input.sendKeys('IZU*');
      } else if (id.indexOf('-Prefix-') > -1) {
        await input.clear();
        await input.sendKeys('*');
      }
    }
    // save screenshot
    await saveScreenshotWithContext(this, driver, testName, 'reset-filter', ['rs-com-mvd-iframe-component > iframe', 'iframe#atlasIframe']);
    treeContent = await waitUntilElement(driver, '#tree-text-content');

    // submit filter
    const applyButton = await getElement(treeContent, 'button[type=submit]');
    expect(applyButton).to.be.an('object');
    await applyButton.click();

    // wait for results
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);

    // save screenshot
    await saveScreenshotWithContext(this, driver, testName, 'zowe-job-loaded', ['rs-com-mvd-iframe-component > iframe', 'iframe#atlasIframe']);
    treeContent = await waitUntilElement(driver, '#tree-text-content');

    const items = await getElements(treeContent, 'div.node ul li');
    expect(items).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${items.length} of menu items`);
    let findZoweJob = -1;
    for (let i in items) {
      const label = await getElement(items[i], '.node-label');
      if (label) {
        const text = await label.getText();
        if (text === ZOWE_JOB_NAME) {
          findZoweJob = parseInt(i, 10);
          break;
        }
      }
    }
    expect(findZoweJob).to.be.above(-1);
  });
});


after('quit webdriver', async function() {
  // quit webdriver
  await driver.quit();
});
