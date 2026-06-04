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
const MAX_BODY_BYTES = 25 * 1024 * 1024

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
    image_size: '1024x1024',
    batch_size: 1,
    num_inference_steps: 28,
    guidance_scale: 7.5,
  }
}

async function fetchImageAsBase64(url) {
  const imageResponse = await fetch(url)
  if (!imageResponse.ok) {
    throw new Error(`Generated image download failed with HTTP ${imageResponse.status}`)
  }

  const contentType = imageResponse.headers.get('content-type') || 'image/png'
  const buffer = Buffer.from(await imageResponse.arrayBuffer())
  return {
    imageBase64: buffer.toString('base64'),
    mimeType: contentType,
  }
}

async function generateSketch(input) {
  if (SILICONFLOW_API_KEY.length === 0 || SILICONFLOW_API_KEY === 'replace_with_your_key') {
    throw new Error('SILICONFLOW_API_KEY is not configured')
  }

  const siliconFlowResponse = await fetch(SILICONFLOW_ENDPOINT, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SILICONFLOW_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(buildPayload(input)),
  })

  const responseText = await siliconFlowResponse.text()
  if (!siliconFlowResponse.ok) {
    throw new Error(`SiliconFlow failed with HTTP ${siliconFlowResponse.status}: ${responseText}`)
  }

  const data = JSON.parse(responseText)
  const firstImage = data.images && data.images.length > 0 ? data.images[0] : null
  if (!firstImage || typeof firstImage.url !== 'string') {
    throw new Error('SiliconFlow response does not contain images[0].url')
  }

  const downloaded = await fetchImageAsBase64(firstImage.url)
  return {
    imageBase64: downloaded.imageBase64,
    mimeType: downloaded.mimeType,
    taskId: data.id || firstImage.url,
  }
}

async function handleSketchMap(request, response) {
  try {
    const rawBody = await readBody(request)
    const input = JSON.parse(rawBody)
    const result = await generateSketch(input)
    sendJson(response, 200, result)
  } catch (error) {
    sendJson(response, 500, {
      error: error instanceof Error ? error.message : 'Unknown server error',
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
