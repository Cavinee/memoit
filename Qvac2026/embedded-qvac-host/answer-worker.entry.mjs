/**
 * In-process QVAC answer worklet. Runs inside a react-native-bare-kit BareWorklet:
 * takes a General AI Answer request over the BareKit push channel, runs the
 * @qvac/sdk model locally, and replies with the generated text.
 *
 * Must be built with bare-pack — raw node_modules imports don't resolve in a
 * worklet. Never log prompt, response, or context text.
 */

import process from "process";
import fs from "fs";
import path from "path";
import { initializeWorkerCore } from "@qvac/sdk/worker-core";
import { registerPlugin } from "@qvac/sdk/plugins";
import { llmPlugin } from "@qvac/sdk/llamacpp-completion/plugin";
import {
  loadModel,
  completion,
  LLAMA_3_2_1B_INST_Q4_0
} from "@qvac/sdk";

const PROTOCOL = "qvac.embeddedHost.answer.v1";
const REQUEST_TYPE = "qvac.host.answer";
const RESPONSE_TYPE = "qvac.host.answer.response";

let pendingReply = null;
let pendingRequestID = null;

function errorResponse(requestID, errorCode, errorMessage) {
  return {
    protocol: PROTOCOL,
    type: RESPONSE_TYPE,
    requestID,
    status: "error",
    errorCode,
    errorMessage
  };
}

function completedResponse(requestID, text) {
  return {
    protocol: PROTOCOL,
    type: RESPONSE_TYPE,
    requestID,
    status: "completed",
    text
  };
}

function settleReply(payload) {
  const reply = pendingReply;
  pendingReply = null;
  pendingRequestID = null;
  if (reply) {
    try {
      reply(null, Buffer.from(JSON.stringify(payload)));
    } catch {}
  }
}

function describe(reason) {
  if (reason && typeof reason.message === "string") {
    return reason.message;
  }
  return String(reason);
}

// Bare kills the whole process on an unhandled rejection or uncaught exception,
// so catch them here and reply with the error instead of crashing the app.
process.on("unhandledRejection", (reason) => {
  settleReply(errorResponse(pendingRequestID, "unhandled-rejection", describe(reason)));
});
process.on("uncaughtException", (error) => {
  settleReply(errorResponse(pendingRequestID, "uncaught-exception", describe(error)));
});

// The SDK keeps its models and lock file under `${HOME_DIR}/.qvac`. On iOS the
// container root isn't writable, so point HOME_DIR at Documents (which is) and
// create `.qvac` ourselves before initializeWorkerCore writes its lock file there.
// console/logger output doesn't reach os_log this early, so init failures are
// stashed and replied back to the app on the next request.
let resolvedHomeDir = "(unset)";
try {
  const baseHome =
    (process.argv && process.argv[0]) ||
    process.env.HOME ||
    process.env.USERPROFILE ||
    "/tmp";
  resolvedHomeDir = path.join(baseHome, "Documents");
  if (Array.isArray(process.argv)) {
    process.argv[0] = resolvedHomeDir;
  }
  process.env.HOME = resolvedHomeDir;
  const qvacDir = path.join(resolvedHomeDir, ".qvac");
  fs.mkdirSync(qvacDir, { recursive: true });
  if (!fs.existsSync(qvacDir)) {
    globalThis.__qvacAnswerInitError = "qvac dir missing after mkdir: " + qvacDir;
  }
} catch (error) {
  globalThis.__qvacAnswerInitError =
    "mkdir .qvac failed home=" + resolvedHomeDir + " err=" + describe(error);
}

try {
  initializeWorkerCore();
} catch (error) {
  if (!globalThis.__qvacAnswerInitError) {
    globalThis.__qvacAnswerInitError =
      "initCore home=" + resolvedHomeDir + " err=" + describe(error);
  }
}

try {
  registerPlugin(llmPlugin);
} catch (error) {
  // The plugin registry lives in the shared native addon and outlives a single
  // worklet, so a repeat registration on a later request is fine to ignore.
  if (!String(describe(error)).toLowerCase().includes("already registered")) {
    if (!globalThis.__qvacAnswerInitError) {
      globalThis.__qvacAnswerInitError = "registerPlugin err=" + describe(error);
    }
  }
}

let modelIdPromise = null;
function ensureModelLoaded() {
  if (modelIdPromise === null) {
    modelIdPromise = loadModel({
      modelSrc: LLAMA_3_2_1B_INST_Q4_0,
      modelType: "llm"
    }).catch((error) => {
      modelIdPromise = null;
      throw error;
    });
  }
  return modelIdPromise;
}

async function generate(request) {
  const modelId = await ensureModelLoaded();

  // Await only `final` — iterating events/tokenStream in-process can leave a
  // sibling promise rejecting with no handler, which Bare treats as fatal.
  const run = completion({
    modelId,
    history: [{ role: "user", content: request.prompt }],
    stream: false
  });

  const final = await run.final;
  return final.contentText ?? (final.raw && final.raw.fullText) ?? "";
}

BareKit.on("push", (data, reply) => {
  let requestID = null;

  try {
    const request = JSON.parse(data.toString());
    requestID = typeof request.requestID === "string" ? request.requestID : null;
  } catch (error) {
    try {
      reply(null, Buffer.from(JSON.stringify(errorResponse(null, "invalid-request", describe(error)))));
    } catch {}
    return;
  }

  // Remember the reply so the process-level handlers above can use it.
  pendingReply = reply;
  pendingRequestID = requestID;

  (async () => {
    try {
      const request = JSON.parse(data.toString());

      if (globalThis.__qvacAnswerInitError) {
        settleReply(errorResponse(requestID, "worker-init-failed", globalThis.__qvacAnswerInitError));
        return;
      }
      if (request.protocol !== PROTOCOL || request.type !== REQUEST_TYPE) {
        settleReply(errorResponse(requestID, "invalid-protocol", "Invalid protocol or type in answer request."));
        return;
      }
      if (typeof request.prompt !== "string" || request.prompt.length === 0) {
        settleReply(errorResponse(requestID, "invalid-prompt", "Answer request is missing a prompt."));
        return;
      }

      const text = await generate(request);
      settleReply(completedResponse(requestID, text));
    } catch (error) {
      settleReply(errorResponse(requestID, "generation-failed", describe(error)));
    }
  })().catch((error) => {
    settleReply(errorResponse(requestID, "answer-handler-failed", describe(error)));
  });
});
