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
const debug = require('debug')('test:e2e:utils');
const { Capabilities, Builder, logging } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const firefox = require('selenium-webdriver/firefox');

const writeFile = util.promisify(fs.writeFile);

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

module.exports = {
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_SCREENSHOT_PATH,

  saveScreenshot,
  getDefaultDriver,
};
