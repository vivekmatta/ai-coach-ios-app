const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");
const exclusionList = require("metro-config/private/defaults/exclusionList").default;

const projectRoot = __dirname;
const config = getDefaultConfig(projectRoot);

config.resolver.blockList = exclusionList([
  new RegExp(`${escapePath(path.join(projectRoot, "research-dashboard"))}/.*`),
  new RegExp(`${escapePath(path.join(projectRoot, "server"))}/.*`),
  new RegExp(`${escapePath(path.join(projectRoot, "data"))}/.*`),
  new RegExp(`${escapePath(path.join(projectRoot, "secrets"))}/.*`),
]);

function escapePath(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

module.exports = config;
