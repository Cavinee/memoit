import React, { useMemo, useState } from "react";
import {
  ActivityIndicator,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TouchableOpacity,
  View
} from "react-native";
import * as Device from "expo-device";
import {
  LLAMA_3_2_1B_INST_Q4_0,
  completion,
  loadModel,
  unloadModel
} from "@qvac/sdk";

const MODEL_PROFILE = {
  identifier: "LLAMA_3_2_1B_INST_Q4_0",
  name: "Llama 3.2 1B Instruct Q4_0",
  source: "QVAC quickstart constant"
};

const SMOKE_PROMPT =
  "Return one short sentence confirming this local iPhone QVAC smoke test generated text.";

export default function App() {
  const [running, setRunning] = useState(false);
  const [events, setEvents] = useState([]);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [offlineRepeatMode, setOfflineRepeatMode] = useState(false);

  const deviceSummary = useMemo(() => {
    return {
      device: Device.modelName ?? "unknown iPhone",
      osName: Device.osName ?? "iOS",
      osVersion: Device.osVersion ?? "unknown"
    };
  }, []);

  async function runSmoke() {
    setRunning(true);
    setEvents([]);
    setResult(null);
    setError(null);

    const startedAt = Date.now();
    let modelId;
    let tokenCount = 0;
    let generatedTextNonEmpty = false;

    try {
      appendEvent("loadModel.started");
      modelId = await loadModel({
        modelSrc: LLAMA_3_2_1B_INST_Q4_0,
        onProgress: (progress) => {
          appendEvent("loadModel.progress", compactProgress(progress));
        }
      });
      appendEvent("loadModel.completed");

      appendEvent("completion.started");
      const run = completion({
        modelId,
        history: [{ role: "user", content: SMOKE_PROMPT }],
        stream: true
      });

      if (run.events) {
        for await (const event of run.events) {
          if (event.type === "contentDelta" && event.text) {
            tokenCount += 1;
            generatedTextNonEmpty = true;
          }
        }
        if (run.final) {
          await run.final;
        }
      } else if (run.tokenStream) {
        for await (const token of run.tokenStream) {
          if (token) {
            tokenCount += 1;
            generatedTextNonEmpty = true;
          }
        }
      } else if (run.text) {
        const text = await run.text;
        generatedTextNonEmpty = text.trim().length > 0;
        tokenCount = generatedTextNonEmpty ? 1 : 0;
      }

      appendEvent("completion.completed", {
        generatedTextNonEmpty,
        tokenCount
      });
      if (offlineRepeatMode) {
        appendEvent("offlineRepeat.completed", {
          success: generatedTextNonEmpty
        });
      }

      setResult({
        status: generatedTextNonEmpty
          ? "validatedOnPhysicalDevice"
          : "blockedPendingPhysicalDeviceRun",
        hostPath: "embeddedExpoBareRuntime",
        modelProfile: MODEL_PROFILE,
        generatedTextNonEmpty,
        offlineRepeatabilityChecked: offlineRepeatMode && generatedTextNonEmpty,
        networkDisabledRepeat: offlineRepeatMode
          ? generatedTextNonEmpty
            ? "passed"
            : "failed"
          : "run again in Airplane Mode after first setup",
        durationMs: Date.now() - startedAt,
        device: deviceSummary
      });
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : String(caught);
      appendEvent("error", { category: classifyError(message) });
      setError({
        status: "blockedPendingPhysicalDeviceRun",
        hostPathAttempted: "embeddedExpoBareRuntime",
        blockingDetail: message
      });
    } finally {
      if (modelId) {
        try {
          appendEvent("unloadModel.started");
          await unloadModel({ modelId });
          appendEvent("unloadModel.completed");
        } catch (caught) {
          appendEvent("unloadModel.error", {
            category: classifyError(caught instanceof Error ? caught.message : String(caught))
          });
        }
      }
      setRunning(false);
    }
  }

  function appendEvent(name, metadata = {}) {
    setEvents((current) => [
      ...current,
      {
        name,
        metadata,
        timestamp: new Date().toISOString()
      }
    ]);
  }

  return (
    <SafeAreaView style={styles.root}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>QVAC iPhone Smoke</Text>
        <Text style={styles.subtitle}>
          Runs one local model generation on a physical iPhone. The UI never displays
          generated prose, only content-free status.
        </Text>

        <View style={styles.panel}>
          <Text style={styles.label}>Device</Text>
          <Text style={styles.value}>
            {deviceSummary.device} · {deviceSummary.osName} {deviceSummary.osVersion}
          </Text>
        </View>

        <View style={styles.panel}>
          <Text style={styles.label}>Model</Text>
          <Text style={styles.value}>{MODEL_PROFILE.identifier}</Text>
        </View>

        <View style={styles.togglePanel}>
          <View style={styles.toggleText}>
            <Text style={styles.label}>Offline repeat</Text>
            <Text style={styles.muted}>Turn this on only after enabling Airplane Mode.</Text>
          </View>
          <Switch value={offlineRepeatMode} onValueChange={setOfflineRepeatMode} />
        </View>

        <TouchableOpacity
          style={[styles.button, running && styles.buttonDisabled]}
          onPress={runSmoke}
          disabled={running}
        >
          {running ? <ActivityIndicator color="#ffffff" /> : <Text style={styles.buttonText}>Run Smoke Test</Text>}
        </TouchableOpacity>

        {result ? <ResultPanel result={result} /> : null}
        {error ? <ErrorPanel error={error} /> : null}

        <View style={styles.panel}>
          <Text style={styles.label}>Content-free events</Text>
          {events.length === 0 ? (
            <Text style={styles.muted}>No events yet.</Text>
          ) : (
            events.map((event, index) => (
              <Text key={`${event.timestamp}-${index}`} style={styles.event}>
                {event.name} {Object.keys(event.metadata).length ? JSON.stringify(event.metadata) : ""}
              </Text>
            ))
          )}
        </View>

        <Text style={styles.footer}>
          First run online to let QVAC download/cache the model if needed. Then enable
          Airplane Mode and run again. Report only generatedTextNonEmpty, model metadata,
          and pass/fail status.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function ResultPanel({ result }) {
  return (
    <View style={styles.result}>
      <Text style={styles.resultTitle}>Smoke Result</Text>
      <Text style={styles.resultText}>status: {result.status}</Text>
      <Text style={styles.resultText}>hostPath: {result.hostPath}</Text>
      <Text style={styles.resultText}>generatedTextNonEmpty: {String(result.generatedTextNonEmpty)}</Text>
      <Text style={styles.resultText}>offlineRepeatabilityChecked: {String(result.offlineRepeatabilityChecked)}</Text>
      <Text style={styles.resultText}>networkDisabledRepeat: {result.networkDisabledRepeat}</Text>
      <Text style={styles.resultText}>durationMs: {result.durationMs}</Text>
    </View>
  );
}

function ErrorPanel({ error }) {
  return (
    <View style={styles.error}>
      <Text style={styles.resultTitle}>Blocked</Text>
      <Text style={styles.resultText}>status: {error.status}</Text>
      <Text style={styles.resultText}>hostPathAttempted: {error.hostPathAttempted}</Text>
      <Text style={styles.resultText}>blockingDetail: {error.blockingDetail}</Text>
    </View>
  );
}

function compactProgress(progress) {
  if (!progress || typeof progress !== "object") return {};
  const compact = {};
  for (const key of ["percentage", "loaded", "total", "status", "state"]) {
    if (key in progress) compact[key] = progress[key];
  }
  return compact;
}

function classifyError(message) {
  const lower = message.toLowerCase();
  if (lower.includes("simulator") || lower.includes("emulator")) return "physical-device-required";
  if (lower.includes("network") || lower.includes("download")) return "model-download-or-cache";
  if (lower.includes("metal") || lower.includes("llama")) return "local-runtime";
  return "qvac-smoke";
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#f7f4ed"
  },
  content: {
    gap: 16,
    padding: 20
  },
  title: {
    color: "#18202a",
    fontSize: 30,
    fontWeight: "700"
  },
  subtitle: {
    color: "#47515f",
    fontSize: 16,
    lineHeight: 22
  },
  panel: {
    backgroundColor: "#ffffff",
    borderColor: "#d8d1c2",
    borderRadius: 8,
    borderWidth: 1,
    padding: 14
  },
  togglePanel: {
    alignItems: "center",
    backgroundColor: "#fffaf0",
    borderColor: "#d8d1c2",
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    gap: 12,
    justifyContent: "space-between",
    padding: 14
  },
  toggleText: {
    flex: 1
  },
  label: {
    color: "#6d5f45",
    fontSize: 12,
    fontWeight: "700",
    marginBottom: 6,
    textTransform: "uppercase"
  },
  value: {
    color: "#18202a",
    fontSize: 15
  },
  button: {
    alignItems: "center",
    backgroundColor: "#275d6b",
    borderRadius: 8,
    minHeight: 52,
    justifyContent: "center"
  },
  buttonDisabled: {
    opacity: 0.65
  },
  buttonText: {
    color: "#ffffff",
    fontSize: 16,
    fontWeight: "700"
  },
  result: {
    backgroundColor: "#e8f4ee",
    borderColor: "#86b79c",
    borderRadius: 8,
    borderWidth: 1,
    padding: 14
  },
  error: {
    backgroundColor: "#f9e8e4",
    borderColor: "#ca8b7e",
    borderRadius: 8,
    borderWidth: 1,
    padding: 14
  },
  resultTitle: {
    color: "#18202a",
    fontSize: 17,
    fontWeight: "700",
    marginBottom: 8
  },
  resultText: {
    color: "#26313d",
    fontSize: 14,
    lineHeight: 20
  },
  event: {
    color: "#26313d",
    fontFamily: "Menlo",
    fontSize: 12,
    lineHeight: 18
  },
  muted: {
    color: "#7a746c",
    fontSize: 14
  },
  footer: {
    color: "#5f6873",
    fontSize: 13,
    lineHeight: 19
  }
});
