import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function assertContains(file, text) {
  const content = read(file);
  if (!content.includes(text)) {
    throw new Error(`${file} must contain ${JSON.stringify(text)}`);
  }
}

function assertNotContains(file, text) {
  const content = read(file);
  if (content.includes(text)) {
    throw new Error(`${file} must not contain ${JSON.stringify(text)}`);
  }
}

const requiredPackageDeps = [
  "@qvac/sdk",
  "expo",
  "expo-build-properties",
  "expo-device",
  "expo-file-system",
  "react-native-bare-kit"
];

const pkg = JSON.parse(read("package.json"));
for (const dependency of requiredPackageDeps) {
  if (!pkg.dependencies?.[dependency]) {
    throw new Error(`package.json must include dependency ${dependency}`);
  }
}
if (!pkg.devDependencies?.["bare-pack"]) {
  throw new Error("package.json must include devDependency bare-pack");
}
if (pkg.scripts?.["ios:uninstall"] !== "bash scripts/uninstall-from-iphone.sh") {
  throw new Error("package.json must include ios:uninstall script");
}

const appConfig = JSON.parse(read("app.json"));
const plugins = JSON.stringify(appConfig.expo?.plugins ?? []);
if (!plugins.includes("@qvac/sdk/expo-plugin")) {
  throw new Error("app.json must include @qvac/sdk/expo-plugin");
}
if (!plugins.includes("expo-build-properties")) {
  throw new Error("app.json must include expo-build-properties");
}
if (appConfig.expo?.ios?.deploymentTarget !== "17.0") {
  throw new Error("app.json must set iOS deployment target to 17.0");
}

assertContains("App.js", "LLAMA_3_2_1B_INST_Q4_0");
assertContains("App.js", "loadModel");
assertContains("App.js", "completion");
assertContains("App.js", "unloadModel");
assertContains("App.js", "generatedTextNonEmpty");
assertContains("App.js", "offlineRepeatabilityChecked");
assertContains("App.js", "offlineRepeatMode");
assertContains("App.js", "networkDisabledRepeat");
assertContains("App.js", "embeddedExpoBareRuntime");
assertNotContains("App.js", "setGeneratedText");

assertContains("README.md", "Connect the iPhone");
assertContains("README.md", "npm run ios:device");
assertContains("README.md", "Airplane Mode");
assertContains("README.md", "generatedTextNonEmpty");
assertContains("README.md", "VPN & Device Management");
assertContains("README.md", "npm run ios:uninstall");
assertContains("README.md", "embedded JavaScript bundle");
assertContains("scripts/install-on-iphone.sh", "-allowProvisioningUpdates");
assertContains("scripts/install-on-iphone.sh", "-allowProvisioningDeviceRegistration");
assertContains("scripts/install-on-iphone.sh", "QVAC_SMOKE_CONFIGURATION:-Release");
assertNotContains("scripts/install-on-iphone.sh", "SKIP_BUNDLING=0");
assertContains("scripts/install-on-iphone.sh", "RCT_NO_LAUNCH_PACKAGER=1");
assertContains("scripts/install-on-iphone.sh", "$app_path/main.jsbundle");
assertContains("scripts/install-on-iphone.sh", "Airplane Mode cold launch would fail");
assertContains("scripts/install-on-iphone.sh", "xcrun devicectl device install app");
assertContains("scripts/install-on-iphone.sh", "xcrun devicectl device process launch");
assertContains("scripts/install-on-iphone.sh", "profile is not trusted");
assertContains("scripts/install-on-iphone.sh", "Developer Mode is disabled");
assertContains("scripts/install-on-iphone.sh", "xcrun devicectl list devices");
assertContains("scripts/uninstall-from-iphone.sh", "dev.qvac.smokehost");
assertContains("scripts/uninstall-from-iphone.sh", "xcrun devicectl device uninstall app");

console.log("qvac-smoke-host scaffold is valid");
