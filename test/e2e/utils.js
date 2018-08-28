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
const fs = require('fs');
const path = require('path');
const util = require('util');
const { Capabilities, Builder } = require('selenium-webdriver');

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

  return file;
};

const getDefaultDriver = async() => {
  const chromeCapabilities = Capabilities.chrome();
  chromeCapabilities.set('chromeOptions', {
    args: ['--headless']
  });

  // init webdriver
  let driver = await new Builder()
    .forBrowser('chrome')
    // .withCapabilities(chromeCapabilities)
    .build();

  return driver;
};

module.exports = {
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_SCREENSHOT_PATH,

  saveScreenshot,
  getDefaultDriver,
};
