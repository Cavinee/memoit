const protocol = 'qvac.embeddedHost.status.v1'

function unavailableResponse(requestID) {
  return {
    protocol,
    type: 'qvac.host.status.response',
    requestID,
    status: 'unavailable',
    diagnostic: 'embedded-qvac-host-unavailable'
  }
}

BareKit.on('push', (data, reply) => {
  let requestID = null

  try {
    const request = JSON.parse(data.toString())
    requestID = typeof request.requestID === 'string' ? request.requestID : null

    if (request.protocol !== protocol || request.type !== 'qvac.host.status') {
      reply(null, Buffer.from(JSON.stringify(unavailableResponse(requestID))))
      return
    }

    reply(null, Buffer.from(JSON.stringify({
      protocol,
      type: 'qvac.host.status.response',
      requestID,
      status: 'ready',
      diagnostic: 'embedded-qvac-host-ready',
      runtime: 'bare'
    })))
  } catch {
    reply(null, Buffer.from(JSON.stringify(unavailableResponse(requestID))))
  }
})
