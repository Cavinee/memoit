import fs from "node:fs";
import path from "node:path";

const projectRoot = path.resolve(import.meta.dirname, "..");

function readJSON(relativePath) {
  const fullPath = path.join(projectRoot, relativePath);
  return JSON.parse(fs.readFileSync(fullPath, "utf8"));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(projectRoot, relativePath), "utf8");
}

function expect(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const packageJSON = readJSON("package.json");
const dependencies = packageJSON.dependencies ?? {};
for (const dependency of [
  "@qvac/sdk",
  "expo",
  "expo-build-properties",
  "react",
  "react-native",
  "react-native-bare-kit",
]) {
  expect(
    typeof dependencies[dependency] === "string",
    `package.json must declare dependency ${dependency}`,
  );
}

expect(
  packageJSON.scripts?.["validate:embedded-qvac-host"] ===
    "node scripts/validate-production-embedded-qvac-host.mjs",
  "package.json must expose validate:embedded-qvac-host",
);

const appJSON = readJSON("app.json");
const expo = appJSON.expo ?? {};
expect(expo.slug === "memoit", "app.json must describe the production MemoIt Expo host");
expect(expo.newArchEnabled === true, "app.json must enable the Expo/RN new architecture");
expect(
  expo.ios?.bundleIdentifier === "com.nullabs.memoit",
  "app.json must use the production iOS bundle identifier",
);
expect(
  expo.ios?.deploymentTarget === "17.0",
  "app.json must keep the embedded host compatible with iOS 17+",
);
const plugins = JSON.stringify(expo.plugins ?? []);
expect(
  plugins.includes("expo-build-properties"),
  "app.json must include expo-build-properties",
);
expect(
  plugins.includes("@qvac/sdk/expo-plugin"),
  "app.json must include @qvac/sdk/expo-plugin",
);

const podfileProperties = readJSON("Podfile.properties.json");
expect(
  podfileProperties["ios.deploymentTarget"] === "17.0",
  "Podfile.properties.json must set ios.deploymentTarget to 17.0",
);
expect(
  podfileProperties["expo.jsEngine"] === "hermes",
  "Podfile.properties.json must select Hermes",
);

const podfile = readText("Podfile");
const baseXCConfig = readText("Base.xcconfig");
const projectFile = readText("qvac2026.xcodeproj/project.pbxproj");
const productionHostRuntime = readText("qvac2026/Services/ProductionEmbeddedQVACHostRuntime.swift");
for (const requiredText of [
  "expo/package.json",
  "react-native/package.json",
  "prepare_react_native_project!",
  "target 'qvac2026' do",
  "use_expo_modules!",
  "use_react_native!(",
  ":app_path => \"#{Pod::Config.instance.installation_root}\"",
]) {
  expect(
    podfile.includes(requiredText),
    `Podfile must include ${requiredText}`,
  );
}

expect(
  fs.existsSync(path.join(projectRoot, "qvac2026.xcodeproj")),
  "production validation requires the production Xcode project at Qvac2026/qvac2026.xcodeproj",
);
expect(
  fs.existsSync(path.join(projectRoot, "node_modules", "react-native", "package.json")),
  "node_modules/react-native/package.json must exist under Qvac2026",
);
expect(
  fs.existsSync(
    path.join(
      projectRoot,
      "node_modules",
      "react-native-bare-kit",
      "react-native-bare-kit.podspec",
    ),
  ),
  "node_modules/react-native-bare-kit/react-native-bare-kit.podspec must exist under Qvac2026",
);
expect(
  podfile.includes("native_modules_config = list_native_modules!(config_command)"),
  "Podfile must list native modules before linking so repo-layout paths can be normalized",
);
expect(
  podfile.includes("ENV['PROJECT_ROOT'] ||= Pod::Config.instance.installation_root.to_s"),
  "Podfile must pin Expo constants script PROJECT_ROOT to Qvac2026",
);
expect(
  podfile.includes("native_modules_config[:ios_project_root_path] = Pod::Config.instance.installation_root.to_s"),
  "Podfile must normalize autolinked native module pods against Qvac2026, not Qvac2026/ios",
);
expect(
  podfile.includes("config = link_native_modules!(native_modules_config)"),
  "Podfile must link native modules after normalizing the autolinked ios project root",
);
expect(
  !podfile.includes("config = use_native_modules!(config_command)"),
  "Podfile must not call use_native_modules! directly because it links pods before path normalization",
);
expect(
  podfile.includes("$CODEGEN_OUTPUT_DIR = File.join(Pod::Config.instance.installation_root, 'build/generated/ios')"),
  "Podfile must pin React Native codegen output to Qvac2026/build/generated/ios",
);
expect(
  podfile.includes("autolinked_ios_project_root = File.join(Pod::Config.instance.installation_root, 'ios')"),
  "Podfile must derive Expo autolinking's ios project root from Qvac2026",
);
expect(
  podfile.includes("react_native_absolute_path = File.expand_path(config[:reactNativePath], autolinked_ios_project_root)"),
  "Podfile must derive an absolute React Native path from the autolinked ios project root",
);
expect(
  podfile.includes("react_native_path = Pathname.new(react_native_absolute_path).relative_path_from(Pod::Config.instance.installation_root).to_s"),
  "Podfile must pass React Native a path relative to Qvac2026 after robust absolute-path normalization",
);
expect(
  podfile.includes(":path => react_native_path"),
  "Podfile use_react_native! must use the normalized React Native path",
);
expect(
  podfile.includes("react_native_post_install(") &&
    podfile.includes("react_native_path,"),
  "Podfile post_install must use the normalized React Native path",
);
expect(
  podfile.includes("patch_expo_modules_provider_for_default_main_actor") &&
    podfile.includes("post_integrate do |installer|") &&
    podfile.includes("unless provider.include?('public nonisolated required init()')") &&
    podfile.includes("public nonisolated required init()") &&
    podfile.includes("public nonisolated override func"),
  "Podfile must patch ExpoModulesProvider for the app target's default MainActor isolation",
);
expect(
  !podfile.includes(":path => config[:reactNativePath]"),
  "Podfile must not pass Expo autolinked relative reactNativePath directly to use_react_native!",
);

expect(
  !podfile.includes("QVACSmokeHost"),
  "Podfile must not copy the smoke host app target",
);
expect(
  baseXCConfig.includes("PODS_ROOT = $(SRCROOT)/Pods"),
  "Base.xcconfig must define PODS_ROOT for CocoaPods build phase file-list expansion",
);
expect(
  projectFile.includes("ENABLE_USER_SCRIPT_SANDBOXING = NO;"),
  "Xcode project must disable user script sandboxing so Expo/RN build phases can read package.json and node_modules",
);
expect(
  !projectFile.includes("SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;"),
  "Xcode target must not set Swift default actor isolation to MainActor because generated ExpoModulesProvider overrides nonisolated Expo APIs",
);

const nativeStatusModulePath = "qvac2026/Services/ProductionEmbeddedQVACHostStatusModule.swift";
const bareHostBridgePath = "qvac2026/Services/ProductionEmbeddedQVACBareHostBridge.m";
const bareStatusResponderPath = "embedded-qvac-host/status-responder.js";
const bridgingHeaderPath = "qvac2026/qvac2026-Bridging-Header.h";
expect(
  fs.existsSync(path.join(projectRoot, nativeStatusModulePath)),
  "production app must include a native embedded QVAC host status module",
);
expect(
  fs.existsSync(path.join(projectRoot, bareStatusResponderPath)),
  "production app must include a JS/Bare embedded QVAC host status responder",
);
expect(
  fs.existsSync(path.join(projectRoot, bareHostBridgePath)),
  "production app must include an ObjC Bare host bridge for native BareKit IPC",
);
expect(
  fs.existsSync(path.join(projectRoot, bridgingHeaderPath)),
  "production app must include a Swift bridging header for the ObjC Bare host bridge",
);
expect(
  projectFile.includes("SWIFT_OBJC_BRIDGING_HEADER = \"qvac2026/qvac2026-Bridging-Header.h\";"),
  "Xcode target must expose the ObjC Bare host bridge to Swift through a bridging header",
);

const nativeStatusModule = readText(nativeStatusModulePath);
const bareHostBridge = readText(bareHostBridgePath);
const bareStatusResponder = readText(bareStatusResponderPath);
const bridgingHeader = readText(bridgingHeaderPath);
const appEntry = readText("qvac2026/qvac2026App.swift");
const embeddedHostStatusService = readText("qvac2026/Services/EmbeddedQVACHostStatusService.swift");
const gitignore = readText(".gitignore");
const packageManifest = JSON.parse(readText("package.json"));
expect(
  packageManifest.dependencies["@qvac/sdk"] === "0.13.5",
  "package.json must pin @qvac/sdk to the lockfile-verified version",
);
expect(
  gitignore.includes("Pods/") && gitignore.includes("node_modules/"),
  ".gitignore must exclude installed Pods and node_modules",
);
expect(
  appEntry.includes("DatabaseService.shared.notes.purgeExpiredTrash()") &&
    appEntry.includes("EmbeddedQVACHostStatusService.shared.startStartupProbe()"),
  "app startup must preserve trash cleanup while adding the embedded QVAC host probe",
);
expect(
  embeddedHostStatusService.includes("diagnosticCode=embedded-qvac-host-provider-failed") &&
    !embeddedHostStatusService.includes("String(describing: error)"),
  "embedded host status provider failure logging must remain content-free",
);
for (const requiredText of [
  "ProductionEmbeddedQVACHostStatusModule",
  "Name(\"ProductionEmbeddedQVACHostStatus\")",
  "AsyncFunction(\"statusAsync\")",
  "ProductionEmbeddedQVACHostStatusResponder",
  "enum CodingKeys",
  "case protocolValue = \"protocol\"",
  "ProductionEmbeddedQVACBareHostBridge.sendStatusRequest",
  "requestID",
]) {
  expect(
    nativeStatusModule.includes(requiredText),
    `native embedded status module must include ${requiredText}`,
  );
}
expect(
  !nativeStatusModule.includes("NSClassFromString(\"ProductionEmbeddedQVACBareHostBridge\")"),
  "native embedded status module must not rely on runtime string lookup for the ObjC Bare host bridge",
);
expect(
  !nativeStatusModule.includes("workletSource") &&
    !nativeStatusModule.includes("IPC.on('data'"),
  "native embedded status module must not retain an unused stale IPC responder source",
);
expect(
  bridgingHeader.includes("#import \"Services/ProductionEmbeddedQVACBareHostBridge.h\""),
  "Swift bridging header must import the ObjC Bare host bridge header",
);
expect(
  bareHostBridge.includes("[self.worklet push:self.requestData") &&
    bareHostBridge.includes("dispatch_async(dispatch_get_main_queue()") &&
    bareHostBridge.includes("![NSThread isMainThread]") &&
    bareHostBridge.includes("[self finishWithData:data error:error]") &&
    !bareHostBridge.includes("BareIPC") &&
    !bareHostBridge.includes("ipc.writable") &&
    !bareHostBridge.includes("[self writeRequestWhenWritable:self.ipc]") &&
    !bareHostBridge.includes("[readyIPC write:self.requestData completion:") &&
    !bareHostBridge.includes("NSInteger writtenBytes = [ipc write:requestData]"),
  "ObjC Bare host bridge must start BareKit on the main queue, use BareWorklet push for request-scoped status, serialize teardown, and avoid the failing BareIPC write path",
);
for (const requiredText of [
  "qvac.embeddedHost.status.v1",
  "BareKit.on('push'",
  "reply(null",
  "status",
  "requestID",
]) {
  expect(
    bareStatusResponder.includes(requiredText),
    `JS/Bare embedded status responder must include ${requiredText}`,
  );
}
expect(
  productionHostRuntime.includes("ProductionEmbeddedQVACHostStatusModule") &&
    productionHostRuntime.includes("sendStatusRequest"),
  "ProductionEmbeddedQVACHostRuntime must send a request-scoped status request through the production host status module",
);

console.log("production embedded QVAC host config validated");
