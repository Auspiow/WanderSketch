import http from 'node:http'
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

const envPath = resolve(process.cwd(), 'server/.env')
if (existsSync(envPath)) {
  const lines = readFileSync(envPath, 'utf8').split(/\r?\n/)
  for (const line of lines) {
    const trimmed = line.trim()
    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      continue
    }
    const index = trimmed.indexOf('=')
    if (index > 0) {
      const key = trimmed.slice(0, index).trim()
      const value = trimmed.slice(index + 1).trim()
      process.env[key] = value
    }
  }
}

const PORT = Number(process.env.PORT || '3000')
const SILICONFLOW_API_KEY = process.env.SILICONFLOW_API_KEY || ''
const SILICONFLOW_MODEL = process.env.SILICONFLOW_MODEL || 'Qwen/Qwen-Image-Edit'
const SILICONFLOW_ENDPOINT = 'https://api.siliconflow.cn/v1/images/generations'
const SKETCH_IMAGE_SIZE = process.env.SKETCH_IMAGE_SIZE || '768x768'
const SKETCH_INFERENCE_STEPS = Number(process.env.SKETCH_INFERENCE_STEPS || '18')
const SKETCH_GUIDANCE_SCALE = Number(process.env.SKETCH_GUIDANCE_SCALE || '7')
const UPSTREAM_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS || '360000')
const MAX_BODY_BYTES = 25 * 1024 * 1024

class SketchError extends Error {
  constructor(stage, message) {
    super(message)
    this.name = 'SketchError'
    this.stage = stage
  }
}

function nowMs() {
  return Date.now()
}

function elapsedMs(startedAt) {
  return Date.now() - startedAt
}

function logRequest(requestId, message) {
  console.log(`[sketch:${requestId}] ${message}`)
}

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  })
  response.end(JSON.stringify(body))
}

function readBody(request) {
  return new Promise((resolveBody, rejectBody) => {
    let body = ''
    let size = 0

    request.on('data', chunk => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        request.destroy()
        rejectBody(new Error('Request body is too large'))
        return
      }
      body += chunk.toString('utf8')
    })

    request.on('end', () => {
      resolveBody(body)
    })

    request.on('error', error => {
      rejectBody(error)
    })
  })
}

function normalizeBase64Image(image) {
  if (typeof image !== 'string' || image.length === 0) {
    throw new Error('image is required')
  }
  if (image.startsWith('data:image/')) {
    return image
  }
  return `data:image/png;base64,${image}`
}

function buildPayload(input) {
  return {
    model: SILICONFLOW_MODEL,
    prompt: input.prompt,
    image: normalizeBase64Image(input.image),
    image_size: SKETCH_IMAGE_SIZE,
    batch_size: 1,
    num_inference_steps: SKETCH_INFERENCE_STEPS,
    guidance_scale: SKETCH_GUIDANCE_SCALE,
  }
}

async function fetchImageAsBase64(url, requestId) {
  const startedAt = nowMs()
  let imageResponse
  try {
    imageResponse = await fetch(url, {
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown download error'
    throw new SketchError('download', `Generated image download timed out or failed after ${elapsedMs(startedAt)}ms: ${message}`)
  }
  if (!imageResponse.ok) {
    throw new SketchError('download', `Generated image download failed with HTTP ${imageResponse.status}`)
  }

  const contentType = imageResponse.headers.get('content-type') || 'image/png'
  const buffer = Buffer.from(await imageResponse.arrayBuffer())
  logRequest(requestId, `downloaded generated image in ${elapsedMs(startedAt)}ms, bytes=${buffer.length}`)
  return {
    imageBase64: buffer.toString('base64'),
    mimeType: contentType,
  }
}

async function generateSketch(input, requestId) {
  if (SILICONFLOW_API_KEY.length === 0 || SILICONFLOW_API_KEY === 'replace_with_your_key') {
    throw new SketchError('config', 'SILICONFLOW_API_KEY is not configured')
  }

  const payload = buildPayload(input)
  const payloadBytes = Buffer.byteLength(JSON.stringify(payload), 'utf8')
  logRequest(requestId, `upstream start model=${SILICONFLOW_MODEL}, image_size=${SKETCH_IMAGE_SIZE}, steps=${SKETCH_INFERENCE_STEPS}, payloadBytes=${payloadBytes}`)

  let siliconFlowResponse
  const startedAt = nowMs()
  try {
    siliconFlowResponse = await fetch(SILICONFLOW_ENDPOINT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SILICONFLOW_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown upstream error'
    throw new SketchError('upstream', `SiliconFlow request timed out or failed after ${elapsedMs(startedAt)}ms: ${message}`)
  }
  logRequest(requestId, `upstream response in ${elapsedMs(startedAt)}ms, status=${siliconFlowResponse.status}`)

  const responseText = await siliconFlowResponse.text()
  if (!siliconFlowResponse.ok) {
    throw new SketchError('upstream', `SiliconFlow failed with HTTP ${siliconFlowResponse.status}: ${responseText}`)
  }

  const data = JSON.parse(responseText)
  const firstImage = data.images && data.images.length > 0 ? data.images[0] : null
  if (!firstImage || typeof firstImage.url !== 'string') {
    throw new SketchError('upstream', 'SiliconFlow response does not contain images[0].url')
  }

  const downloaded = await fetchImageAsBase64(firstImage.url, requestId)
  return {
    imageBase64: downloaded.imageBase64,
    mimeType: downloaded.mimeType,
    taskId: data.id || firstImage.url,
  }
}

async function handleSketchMap(request, response) {
  const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
  const startedAt = nowMs()
  try {
    const rawBody = await readBody(request)
    logRequest(requestId, `received request bytes=${Buffer.byteLength(rawBody, 'utf8')}`)
    const input = JSON.parse(rawBody)
    const result = await generateSketch(input, requestId)
    logRequest(requestId, `completed in ${elapsedMs(startedAt)}ms`)
    sendJson(response, 200, result)
  } catch (error) {
    const stage = error instanceof SketchError ? error.stage : 'server'
    const message = error instanceof Error ? error.message : 'Unknown server error'
    logRequest(requestId, `failed stage=${stage} elapsed=${elapsedMs(startedAt)}ms error=${message}`)
    sendJson(response, 500, {
      error: message,
      stage,
    })
  }
}

const server = http.createServer((request, response) => {
  if (request.method === 'OPTIONS') {
    sendJson(response, 200, { ok: true })
    return
  }

  if (request.method === 'GET' && request.url === '/health') {
    sendJson(response, 200, {
      ok: true,
      model: SILICONFLOW_MODEL,
      imageSize: SKETCH_IMAGE_SIZE,
      inferenceSteps: SKETCH_INFERENCE_STEPS,
      upstreamTimeoutMs: UPSTREAM_TIMEOUT_MS,
      hasApiKey: SILICONFLOW_API_KEY.length > 0 && SILICONFLOW_API_KEY !== 'replace_with_your_key',
    })
    return
  }

  if (request.method === 'POST' && request.url === '/api/sketch-map') {
    handleSketchMap(request, response)
    return
  }

  sendJson(response, 404, { error: 'Not found' })
})

server.listen(PORT, '0.0.0.0', () => {
  console.log(`VisMap sketch proxy listening on http://0.0.0.0:${PORT}`)
})

server.requestTimeout = UPSTREAM_TIMEOUT_MS + 60000
server.headersTimeout = UPSTREAM_TIMEOUT_MS + 65000
