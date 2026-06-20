// answer-responder.js — embedded QVAC host answer worker
//
// This file is loaded by BareKit (BareWorklet) on the physical iOS device.
// It handles a single push/reply cycle: receives an answer request from Swift,
// runs on-device inference via @qvac/sdk, and replies with the generated text.
//
// REQUIREMENTS:
//   - Must run on a physical iOS device (not the simulator).
//   - Requires the bundled QVAC worker and native addons (see qvac-smoke-host/qvac/)
//     to be present and accessible to the BareWorklet runtime.
//   - @qvac/sdk loadModel / completion / unloadModel follow the same patterns
//     validated in qvac-smoke-host/App.js (issue 13).
//
// PENDING PHYSICAL-DEVICE VALIDATION: this responder has not yet been run
// end-to-end on device. The wire protocol and SDK call patterns are modelled
// directly on qvac-smoke-host/App.js and the status-responder.js baseline.
//
// PRIVACY: prompt, context, and generated text are NEVER logged.

import { LLAMA_3_2_1B_INST_Q4_0, completion, loadModel, unloadModel } from '@qvac/sdk'

const PROTOCOL = 'qvac.embeddedHost.answer.v1'

function errorResponse(requestID, errorCode, errorMessage) {
  return {
    protocol: PROTOCOL,
    type: 'qvac.host.answer.response',
    requestID,
    status: 'error',
    errorCode,
    errorMessage
  }
}

function completedResponse(requestID, text) {
  return {
    protocol: PROTOCOL,
    type: 'qvac.host.answer.response',
    requestID,
    status: 'completed',
    text
  }
}

BareKit.on('push', async (data, reply) => {
  let requestID = null

  try {
    const request = JSON.parse(data.toString())
    requestID = typeof request.requestID === 'string' ? request.requestID : null

    if (request.protocol !== PROTOCOL || request.type !== 'qvac.host.answer') {
      reply(null, Buffer.from(JSON.stringify(
        errorResponse(requestID, 'invalid-protocol', 'Invalid protocol or type.')
      )))
      return
    }

    const { prompt, mode, context } = request

    if (typeof prompt !== 'string' || prompt.trim().length === 0) {
      reply(null, Buffer.from(JSON.stringify(
        errorResponse(requestID, 'invalid-prompt', 'Prompt must be a non-empty string.')
      )))
      return
    }

    // Build the user message. If context notes were provided (note-grounded mode),
    // prepend them as reference material. The Swift runtime selects which notes
    // to include — this responder forwards them verbatim without further retrieval.
    let userContent = prompt
    if (Array.isArray(context) && context.length > 0) {
      const contextBlock = context
        .map((note) => {
          const title = typeof note.title === 'string' ? note.title : ''
          const body = typeof note.body === 'string' ? note.body : ''
          return `[Note: ${title}]\n${body}`
        })
        .join('\n\n')
      userContent = `${contextBlock}\n\n${prompt}`
    }

    let modelId
    try {
      modelId = await loadModel({
        modelSrc: LLAMA_3_2_1B_INST_Q4_0,
        onProgress: () => {
          // Progress events are intentionally not surfaced in this slice (issue 18).
        }
      })
    } catch (loadError) {
      const msg = loadError instanceof Error ? loadError.message : String(loadError)
      reply(null, Buffer.from(JSON.stringify(
        errorResponse(requestID, classifyError(msg), msg)
      )))
      return
    }

    try {
      const run = completion({
        modelId,
        history: [{ role: 'user', content: userContent }],
        stream: true
      })

      let generatedText = ''

      if (run.events) {
        for await (const event of run.events) {
          if (event.type === 'contentDelta' && typeof event.text === 'string') {
            generatedText += event.text
          }
        }
        if (run.final) {
          await run.final
        }
      } else if (run.tokenStream) {
        for await (const token of run.tokenStream) {
          if (typeof token === 'string') {
            generatedText += token
          }
        }
      } else if (run.text) {
        generatedText = await run.text
      }

      reply(null, Buffer.from(JSON.stringify(
        completedResponse(requestID, generatedText)
      )))
    } finally {
      if (modelId !== undefined) {
        try {
          await unloadModel({ modelId })
        } catch {
          // Unload failure is not fatal; the worklet terminates after reply.
        }
      }
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    reply(null, Buffer.from(JSON.stringify(
      errorResponse(requestID, classifyError(msg), msg)
    )))
  }
})

function classifyError(message) {
  const lower = message.toLowerCase()
  if (lower.includes('simulator') || lower.includes('emulator')) return 'physical-device-required'
  if (lower.includes('network') || lower.includes('download')) return 'model-download-or-cache'
  if (lower.includes('metal') || lower.includes('llama')) return 'local-runtime'
  return 'qvac-answer-error'
}
