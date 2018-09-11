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
  DEFAULT_PAGE_LOADING_TIMEOUT,
  MVD_ATLAS_APP_CONTEXT,
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
  switchToAppContext,
  saveScreenshotWithAppContext,
} = require('./utils');
let driver;

const APP_TO_TEST = 'MVS Explorer';
const DS_TO_TEST = 'TCPIP.TCPIP.DATA';

const MVD_EXPLORER_TREE_SECTION = 'div.tree-card > div > div:nth-child(2)';

let appLaunched = false;
let testDsIndex = -1;

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
    await loginMVD(driver);
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

    // locate app iframe
    const iframe = await waitUntilIframe(driver, 'rs-com-mvd-iframe-component > iframe', app);
    expect(iframe).to.be.an('object');
    debug('app iframe found');

    // wait for atlas iframe
    const atlas = await waitUntilIframe(driver, 'iframe#atlasIframe');
    expect(atlas).to.be.an('object');
    debug('atlas iframe is ready');

    // FIXME: shouldn't pop out authentication
    const alert = await driver.wait(until.alertIsPresent(), DEFAULT_PAGE_LOADING_TIMEOUT);
    await alert.sendKeys(process.env.SSH_USER + Key.TAB + process.env.SSH_PASSWD);
    await alert.accept();
    // to avoid StaleElementReferenceError, find the iframes context again
    await switchToAppContext(driver, APP_TO_TEST, MVD_ATLAS_APP_CONTEXT);
    debug('atlas login successfully');

    // wait for page is loaded
    let treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    // the loading icon is not there right after page is loaded, so wait a little
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);
    debug('page is fully loaded');

    // save screenshot
    await saveScreenshotWithAppContext(this, driver, testName, 'app-loaded', APP_TO_TEST, MVD_ATLAS_APP_CONTEXT);

    appLaunched = true;
  });

  it('should be able to list TCPIP.T* data sets', async function() {
    if (!appLaunched) {
      this.skip();
    }

    let treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    // replace qualifier
    const qualifier = await getElement(treeContent, 'input#path');
    expect(qualifier).to.be.an('object');
    await qualifier.clear();
    await qualifier.sendKeys('TCPIP.T*' + Key.ENTER);
    debug('qualifier updated');

    // wait for results
    await driver.sleep(1000);
    await waitUntilElementIsGone(driver, 'div[mode=indeterminate]', treeContent);
    debug('page reloaded');

    // save screenshot
    await saveScreenshotWithAppContext(this, driver, testName, 'ds-list-loaded', APP_TO_TEST, MVD_ATLAS_APP_CONTEXT);
    treeContent = await waitUntilElement(driver, MVD_EXPLORER_TREE_SECTION);

    const items = await getElements(treeContent, 'div.node ul li');
    expect(items).to.be.an('array').that.have.lengthOf.above(0);
    debug(`found ${items.length} of menu items`);
    for (let i in items) {
      const label = await getElement(items[i], 'div.react-contextmenu-wrapper span.node-label');
      if (label) {
        const text = await label.getText();
        if (text === DS_TO_TEST) {
          testDsIndex = parseInt(i, 10);
          break;
        }
      }
    }
    expect(testDsIndex).to.be.above(-1);
    debug(`found ${DS_TO_TEST} at ${testDsIndex}`);
  });

  it(`should be able to load content of ${DS_TO_TEST} data set`, async function() {
    if (!appLaunched || testDsIndex < 0) {
      this.skip();
    }

    // prepare app context and find the li of DS_TO_TEST
    await driver.switchTo().defaultContent();
    await switchToAppContext(driver, APP_TO_TEST, MVD_ATLAS_APP_CONTEXT);
    let treeContent = await getElement(driver, MVD_EXPLORER_TREE_SECTION);
    expect(treeContent).to.be.an('object');
    const items = await getElements(treeContent, 'div.node ul li');
    const testDsFound = items[testDsIndex];

    // find the file icon and click load content
    let contentLink = await getElement(testDsFound, 'div.react-contextmenu-wrapper span.content-link');
    expect(contentLink).to.be.an('object');
    await contentLink.click();
    debug(`${DS_TO_TEST} is clicked`);

    // find right panel header
    let fileContentPanelHeader = await getElement(driver, 'div.component-no-vertical-pad div.component-no-vertical-pad > div:nth-child(1)');
    expect(fileContentPanelHeader).to.be.an('object');
    await driver.wait(
      async() => {
        const text = await fileContentPanelHeader.getText();

        if (text.indexOf(DS_TO_TEST) > -1) {
          return true;
        }

        await driver.sleep(300); // not too fast
        return false;
      },
      DEFAULT_PAGE_LOADING_TIMEOUT
    );
    debug('right panel is loaded');

    // save screenshot
    await saveScreenshotWithAppContext(this, driver, testName, 'ds-content-loaded', APP_TO_TEST, MVD_ATLAS_APP_CONTEXT);
  });


  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
