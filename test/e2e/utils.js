/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */

/*eslint no-console: ["error", { allow: ["log", "warn", "error"] }] */

const _ = require('lodash');
const fs = require('fs');
const path = require('path');
const util = require('util');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:utils');
const { Capabilities, Builder, By, logging } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');

const writeFile = util.promisify(fs.writeFile);

const ZOWE_JOB_NAME = 'ZOWESVR';
const PRE_INSTALLED_APPS = [
  'JES Explorer',
  'MVS Explorer',
  'USS Explorer',
  'TN3270',
  'VT Terminal',
  'IFrame',
  'ZOS Subsystems',
  'Hello World',
];

const DEFAULT_PAGE_LOADING_TIMEOUT = 30000;
const DEFAULT_SCREENSHOT_PATH = './reports';
let SCREENSHOT_FILECOUNT = 0;

const getImagePath = async(driver, testScript, screenshotName) => {
  const dc = await driver.getCapabilities();
  const browserName = dc.getBrowserName(),
    browserVersion = dc.getBrowserVersion() || dc.get('version'),
    platform = dc.getPlatform() || dc.get('platform');

  let file = [
    browserName ? browserName.toUpperCase() : 'ANY',
    browserVersion ? browserVersion.toUpperCase() : 'ANY',
    platform.toUpperCase(),
    testScript.replace(/ /g, '-').toLowerCase(),
    _.padStart(SCREENSHOT_FILECOUNT++, 3, '0'),
    screenshotName,
  ].join('_');

  return `${file}.png`;
};

const saveScreenshot = async(driver, testScript, screenshotName) => {
  const base64png = await driver.takeScreenshot();
  const file = await getImagePath(driver, testScript, screenshotName);
  await writeFile(path.join(DEFAULT_SCREENSHOT_PATH, file), new Buffer(base64png, 'base64'));

  // expose screenshot information
  debug(`- login error returned, screenshot: ${file}`);
  console.log(`[[ATTACHMENT|${file}]]`);

  return file;
};

const getDefaultDriver = async(browserType) => {
  if (!browserType) {
    browserType = 'firefox';
  }
  const browser = browserType === 'chrome' ? chrome : firefox;

  // define Logging Preferences
  let loggingPrefs = new logging.Preferences();
  loggingPrefs.setLevel(logging.Type.BROWSER, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.CLIENT, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.DRIVER, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.PERFORMANCE, logging.Level.ALL);
  loggingPrefs.setLevel(logging.Type.SERVER, logging.Level.ALL);

  // configure ServiceBuilder
  let service = new browser.ServiceBuilder();
  if (browserType === 'firefox') {
    service.enableVerboseLogging(true);
  } else if (browserType === 'chrome') {
    service.loggingTo('./logs/chrome-service.log')
      .enableVerboseLogging();
  }
  service.build();

  // configure Options
  let options = new browser.Options()
    .setLoggingPrefs(loggingPrefs);
  if (browserType === 'firefox') {
    // options.setBinary('/Applications/IBM Firefox.app/Contents/MacOS/firefox');
    // options.setPreference('marionette', true)
    //   .setPreference('marionette.logging', 'ALL');
  } else if (browserType === 'chrome') {
    // options.setChromeBinaryPath('/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary');
    options.setChromeLogFile('./logs/chrome-options.log');
    options.addArguments('--no-sandbox', '--disable-gpu', '--allow-insecure-localhost', '--disable-dev-shm-usage');
  }
  // use headless mode
  options.headless();

  // define Capabilities
  let capabilities = browserType === 'chrome' ? Capabilities.chrome() : Capabilities.firefox();
  capabilities.setLoggingPrefs(loggingPrefs)
    .setAcceptInsecureCerts(true);

  // init webdriver
  let driver = await new Builder()
    .forBrowser(browserType)
    .withCapabilities(capabilities);
  if (browserType === 'firefox') {
    driver = driver.setFirefoxOptions(options).setFirefoxService(service);
  } else if (browserType === 'chrome') {
    driver = driver.setChromeOptions(options).setChromeService(service);
  }
  driver = driver.build();

  return driver;
};

const loginMVD = async(driver) => {
  // load MVD login page
  debug('- loading login page');
  await driver.get(`https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`);
  await driver.wait(
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
  await driver.wait(
    async() => {
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
    DEFAULT_PAGE_LOADING_TIMEOUT
  );

  // make sure we are not hitting login error
  let error = await driver.findElement(By.css('p.login-error')).getText();
  error = error.trim();
  expect(error).to.be.oneOf(['', '&nbsp;']);
};

const getElements = async(driver, selector, checkDisplayed) => {
  const elements = await driver.findElements(By.css(selector));
  if (!elements[0]) {
    debug(`[getElements] cannot find "${selector}"`);
    return false;
  }
  debug(`[getElements] find ${elements.length} of "${selector}"`);
  if (!checkDisplayed) {
    return elements;
  }
  const isDisplayed = await elements[0].isDisplayed();
  if (!isDisplayed) {
    return false;
  }
  debug('[getElements]     and the first element is displayed');
  return elements;
};

const getElement = async(driver, selector, checkDisplayed) => {
  const elements = await getElements(driver, selector, checkDisplayed);
  return elements[0] || false;
};

const getElementText = async(driver, selector, checkDisplayed) => {
  const element = await getElement(driver, selector, checkDisplayed);
  if (!element) {
    return false;
  }
  const text = await element.getText();
  return text;
};

const waitUntilElements = async(driver, selector, parent) => {
  let elements;

  if (!parent) {
    parent = driver;
  }

  await driver.wait(
    async() => {
      const elementsDisplayed = await getElements(parent, selector);
      if (elementsDisplayed) {
        elements = elementsDisplayed;
        return true;
      }

      await driver.sleep(300); // not too fast
      return false;
    },
    DEFAULT_PAGE_LOADING_TIMEOUT
  );
  debug(`[waitUntilElements] find ${elements.length} of "${selector}"`);

  return elements;
};

const waitUntilElementIsGone = async(driver, selector, parent) => {
  if (!parent) {
    parent = driver;
  }

  await driver.sleep(500);
  await driver.wait(
    async() => {
      const elementsDisplayed = await getElement(parent, selector, false);
      if (!elementsDisplayed) {
        return true;
      }

      await driver.sleep(300); // not too fast
      return false;
    },
    DEFAULT_PAGE_LOADING_TIMEOUT
  );
  await driver.sleep(500);

  return true;
};

const waitUntilElement = async(driver, selector, parent) => {
  const elements = await waitUntilElements(driver, selector, parent);

  return (elements && elements[0]) || false;
};

const waitUntilIframe = async(driver, iframeSelector, parent) => {
  const iframe = await waitUntilElement(driver, iframeSelector, parent);
  await driver.switchTo().frame(iframe);

  return iframe;
};

const launchApp = async(driver, appName) => {
  await driver.switchTo().defaultContent();

  // find the app icon
  const app = await driver.findElements(By.css(`rs-com-launchbar rs-com-launchbar-icon div[title="${appName}"]`));
  expect(app).to.be.an('array').that.have.lengthOf(1);

  // start app
  await app[0].click();
};

const locateApp = async(driver, appName) => {
  await driver.switchTo().defaultContent();

  // find all app windows
  const windows = await waitUntilElements(driver, 'rs-com-window-pane rs-com-mvd-window');

  let appWin;
  // locate the app window
  for (let win of windows) {
    const caption = await win.findElements(By.css('.border-box-sizing .heading .caption'));
    if (caption[0]) {
      const text = await caption[0].getText();
      if (text === appName) {
        // app window launched
        appWin = win;
        break;
      }
    }
  }
  if (!appWin) {
    debug(`[locateApp] cannot find app ${appName} in ${windows.length} windows`);
    return false;
  }

  // find the app body
  const body = await waitUntilElement(driver, '.border-box-sizing .body com-rs-mvd-viewport', appWin);

  return body;
};

module.exports = {
  ZOWE_JOB_NAME,
  PRE_INSTALLED_APPS,
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_SCREENSHOT_PATH,

  saveScreenshot,
  getDefaultDriver,
  getElements,
  getElement,
  getElementText,
  waitUntilElements,
  waitUntilElement,
  waitUntilElementIsGone,
  waitUntilIframe,
  loginMVD,
  launchApp,
  locateApp,
};
