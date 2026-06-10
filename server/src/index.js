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
const SILICONFLOW_MODEL = process.env.SILICONFLOW_MODEL || 'Kwai-Kolors/Kolors'
const SILICONFLOW_ENDPOINT = 'https://api.siliconflow.cn/v1/images/generations'
const SILICONFLOW_CHAT_MODEL = process.env.SILICONFLOW_CHAT_MODEL || 'Qwen/Qwen2.5-VL-72B-Instruct'
const SILICONFLOW_CHAT_ENDPOINT = process.env.SILICONFLOW_CHAT_ENDPOINT || 'https://api.siliconflow.cn/v1/chat/completions'
const SKETCH_IMAGE_SIZE = process.env.SKETCH_IMAGE_SIZE || '768x768'
const SKETCH_INFERENCE_STEPS = Number(process.env.SKETCH_INFERENCE_STEPS || '18')
const SKETCH_GUIDANCE_SCALE = Number(process.env.SKETCH_GUIDANCE_SCALE || '7')
const UPSTREAM_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS || '360000')
const MAX_BODY_BYTES = 25 * 1024 * 1024
const MAX_POST_TEXT_CHARS = 12000
const MAX_FETCHED_TEXT_CHARS = 16000
const ALLOWED_TRAVEL_PURPOSES = new Set(['parent_child', 'family', 'fast_paced', 'relaxed', 'foodie', 'photo'])
const ALLOWED_PLACE_CATEGORIES = new Set(['restaurant', 'landmark', 'shopping', 'museum', 'cafe'])

class SketchError extends Error {
  constructor(stage, message) {
    super(message)
    this.name = 'SketchError'
    this.stage = stage
  }
}

class TravelPlanError extends Error {
  constructor(stage, message) {
    super(message)
    this.name = 'TravelPlanError'
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

function logTravelRequest(requestId, message) {
  console.log(`[travel-plan:${requestId}] ${message}`)
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

function compactText(value, maxChars) {
  if (typeof value !== 'string') {
    return ''
  }
  const compacted = value
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
  if (compacted.length <= maxChars) {
    return compacted
  }
  return compacted.slice(0, maxChars)
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

function normalizeOptionalBase64Image(image) {
  if (typeof image !== 'string' || image.length === 0) {
    return ''
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

function normalizeTravelPreference(input) {
  const preference = input && typeof input.preference === 'object' && input.preference !== null ? input.preference : {}
  const travelDate = typeof preference.travelDate === 'string' && preference.travelDate.length > 0 ? preference.travelDate : ''
  const startDate = typeof preference.startDate === 'string' && preference.startDate.length > 0 ? preference.startDate : travelDate
  const endDate = typeof preference.endDate === 'string' && preference.endDate.length > 0 ? preference.endDate : startDate
  const rawPeopleCount = Number(preference.peopleCount)
  const peopleCount = Number.isFinite(rawPeopleCount) ? Math.min(20, Math.max(1, Math.round(rawPeopleCount))) : 1
  const purpose = typeof preference.purpose === 'string' && ALLOWED_TRAVEL_PURPOSES.has(preference.purpose) ? preference.purpose : 'relaxed'
  return {
    travelDate,
    startDate,
    endDate,
    startTime: typeof preference.startTime === 'string' && preference.startTime.length > 0 ? preference.startTime : '09:00',
    peopleCount,
    purpose,
    attractionPreference: compactText(typeof preference.attractionPreference === 'string' ? preference.attractionPreference : '', 1200),
    hotelPreference: compactText(typeof preference.hotelPreference === 'string' ? preference.hotelPreference : '', 1200),
  }
}

function assertValidXhsInput(input) {
  if (!input || typeof input !== 'object') {
    throw new TravelPlanError('request', 'JSON body is required')
  }

  const postUrl = typeof input.postUrl === 'string' ? input.postUrl.trim() : ''
  const postText = typeof input.postText === 'string' ? input.postText.trim() : ''
  const sharedPostText = typeof input.sharedPostText === 'string' ? input.sharedPostText.trim() : ''
  const screenshotImage = typeof input.screenshotImage === 'string' ? input.screenshotImage.trim() : ''
  if (postUrl.length === 0 && postText.length === 0 && sharedPostText.length === 0 && screenshotImage.length === 0) {
    throw new TravelPlanError('request', 'postUrl, postText/sharedPostText, or screenshotImage is required')
  }

  const preference = normalizeTravelPreference(input)
  assertValidPreference(preference)
}

function isDateText(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
}

function isTimeText(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value)
}

function daysBetween(startDate, endDate) {
  const start = Date.parse(`${startDate}T00:00:00Z`)
  const end = Date.parse(`${endDate}T00:00:00Z`)
  if (!Number.isFinite(start) || !Number.isFinite(end)) {
    return NaN
  }
  return Math.round((end - start) / 86400000) + 1
}

function assertValidPreference(preference) {
  if (!isDateText(preference.startDate) || !isDateText(preference.endDate)) {
    throw new TravelPlanError('request', 'preference.startDate and preference.endDate must use YYYY-MM-DD')
  }
  const dayCount = daysBetween(preference.startDate, preference.endDate)
  if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 14) {
    throw new TravelPlanError('request', 'travel date range must be 1 to 14 days')
  }
  if (!isTimeText(preference.startTime)) {
    throw new TravelPlanError('request', 'preference.startTime must use HH:mm')
  }
  if (!ALLOWED_TRAVEL_PURPOSES.has(preference.purpose)) {
    throw new TravelPlanError('request', 'preference.purpose is not supported')
  }
}

function normalizePostUrl(input) {
  const value = typeof input.postUrl === 'string' ? input.postUrl.trim() : ''
  if (value.length === 0) {
    return ''
  }
  try {
    const url = new URL(value)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      throw new TravelPlanError('request', 'postUrl must be an http or https URL')
    }
    return url.toString()
  } catch (error) {
    if (error instanceof TravelPlanError) {
      throw error
    }
    throw new TravelPlanError('request', 'postUrl is not a valid URL')
  }
}

async function fetchPostText(postUrl, requestId) {
  if (postUrl.length === 0) {
    return ''
  }

  const startedAt = nowMs()
  let upstreamResponse
  try {
    upstreamResponse = await fetch(postUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 WanderSketch travel planner',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      redirect: 'follow',
      signal: AbortSignal.timeout(12000),
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown page fetch error'
    logTravelRequest(requestId, `post fetch failed elapsed=${elapsedMs(startedAt)}ms error=${message}`)
    return ''
  }

  if (!upstreamResponse.ok) {
    logTravelRequest(requestId, `post fetch returned HTTP ${upstreamResponse.status}`)
    return ''
  }

  const contentType = upstreamResponse.headers.get('content-type') || ''
  if (!contentType.includes('text/html') && !contentType.includes('text/plain')) {
    logTravelRequest(requestId, `post fetch skipped content-type=${contentType}`)
    return ''
  }

  const html = await upstreamResponse.text()
  const text = compactText(html, MAX_FETCHED_TEXT_CHARS)
  logTravelRequest(requestId, `post fetched in ${elapsedMs(startedAt)}ms, textChars=${text.length}`)
  return text
}

function buildTravelPlanPrompt(input, fetchedPostText) {
  const preference = normalizeTravelPreference(input)
  const postUrl = normalizePostUrl(input)
  const directPostText = compactText(
    typeof input.postText === 'string' && input.postText.length > 0 ? input.postText : input.sharedPostText,
    MAX_POST_TEXT_CHARS,
  )

  return `你是一个严谨的旅行路线规划数据抽取器和行程编排助手。请只基于用户提供的小红书链接页面文本、用户粘贴文本和截图中可见信息生成路线数据；不要编造没有证据的地点、地址、坐标、营业时间或交通时间。

事实约束：
1. 只抽取明确出现在输入文本或截图中的真实地点；如果截图/文本不清晰，请降低 confidence 并在 warnings 中说明。
2. 经纬度、地址、营业时间可以基于模型已知的公开事实补全，但必须是具体地点的真实信息；不确定时使用空字符串或 0，并写入 warnings，不要猜。
3. 时间线必须遵守用户计划日期段、每日出发时间、人数、出游目的、景点偏好、酒店偏好、营业时间、地点顺序和合理通勤距离。
4. 如果原帖没有顺序，按地理距离、营业时间和用户目的优化；亲子游/家庭游降低强度，特种兵路线可以更紧凑，美食优先应优先安排餐饮时段，拍照打卡应考虑白天光线。
5. 酒店偏好用于选择住宿区域建议和路线收尾逻辑，不要编造具体酒店；除非输入中明确出现酒店名。
6. 后端会用非大模型规则监督你的输出：日期、人数、类别、坐标、时间线、地点是否出现在输入证据中都会被校验。不满足时会被拒绝，所以不要输出没有证据的地点。
7. 输出必须是严格 JSON，不要 Markdown，不要解释文字。

用户偏好：
travelDate=${preference.travelDate || preference.startDate}
startDate=${preference.startDate}
endDate=${preference.endDate}
startTime=${preference.startTime}
peopleCount=${preference.peopleCount}
purpose=${preference.purpose}
attractionPreference=${preference.attractionPreference || '未提供'}
hotelPreference=${preference.hotelPreference || '未提供'}

输入来源：
postUrl=${postUrl || '未提供'}
fetchedPostText=${fetchedPostText || '未抓取到页面正文'}
directPostText=${directPostText || '未提供'}

输出 JSON schema：
{
  "preference": {
    "travelDate": "YYYY-MM-DD",
    "startDate": "YYYY-MM-DD",
    "endDate": "YYYY-MM-DD",
    "startTime": "HH:mm",
    "peopleCount": 1,
    "purpose": "parent_child|family|fast_paced|relaxed|foodie|photo",
    "attractionPreference": "用户景点偏好原文或摘要",
    "hotelPreference": "用户酒店偏好原文或摘要"
  },
  "places": [
    {
      "id": "kebab-case-stable-id",
      "name": "地点中文名",
      "category": "restaurant|landmark|shopping|museum|cafe",
      "address": "真实地址，不确定则空字符串",
      "latitude": 0,
      "longitude": 0,
      "openingHours": "HH:mm-HH:mm、全天开放或空字符串",
      "recommendedDurationMinutes": 60,
      "note": "为什么安排这里，需引用输入中的事实"
    }
  ],
  "timeline": [
    {
      "placeId": "对应 places.id",
      "arriveTime": "HH:mm",
      "leaveTime": "HH:mm",
      "commuteFromPrevious": {
        "fromPlaceId": "上一地点 id，首站为空字符串",
        "toPlaceId": "当前地点 id",
        "distanceKm": 0,
        "durationMinutes": 0,
        "transport": "步行|地铁|公交|打车|步行/打车|"
      },
      "openStatus": "营业中|可能未营业|需确认"
    }
  ],
  "region": {
    "north": 0,
    "south": 0,
    "east": 0,
    "west": 0,
    "centerLat": 0,
    "centerLng": 0,
    "zoom": 12
  },
  "summary": "一句中文概述",
  "source": {
    "postUrl": "原始链接或空字符串",
    "usedScreenshot": true,
    "usedFetchedText": true,
    "usedDirectText": true
  },
  "confidence": 0.0,
  "warnings": ["不确定事项"]
}`
}

function buildTravelMessages(input, prompt) {
  const content = [
    {
      type: 'text',
      text: prompt,
    },
  ]
  const screenshotImage = normalizeOptionalBase64Image(input.screenshotImage)
  if (screenshotImage.length > 0) {
    content.push({
      type: 'image_url',
      image_url: {
        url: screenshotImage,
      },
    })
  }

  return [
    {
      role: 'system',
      content: '你只输出可解析的 JSON。你是基于事实的旅行数据抽取与路线规划模型，必须显式标注不确定性。',
    },
    {
      role: 'user',
      content,
    },
  ]
}

function extractJsonObject(text) {
  const trimmed = text.trim()
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    return trimmed
  }
  const start = trimmed.indexOf('{')
  const end = trimmed.lastIndexOf('}')
  if (start >= 0 && end > start) {
    return trimmed.slice(start, end + 1)
  }
  throw new TravelPlanError('parse', 'Model response did not contain a JSON object')
}

function assertNumber(value, path) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new TravelPlanError('validate', `${path} must be a finite number`)
  }
}

function assertString(value, path) {
  if (typeof value !== 'string') {
    throw new TravelPlanError('validate', `${path} must be a string`)
  }
}

function timeToMinutes(value) {
  if (!isTimeText(value)) {
    return NaN
  }
  const parts = value.split(':')
  return Number(parts[0]) * 60 + Number(parts[1])
}

function buildEvidenceText(input, fetchedPostText) {
  const directPostText = typeof input.postText === 'string' && input.postText.length > 0 ? input.postText : input.sharedPostText
  return compactText(`${fetchedPostText || ''} ${directPostText || ''}`, MAX_FETCHED_TEXT_CHARS + MAX_POST_TEXT_CHARS).toLowerCase()
}

function hasScreenshotInput(input) {
  return typeof input.screenshotImage === 'string' && input.screenshotImage.trim().length > 0
}

function calculateRegionFromPlaces(places) {
  const validPlaces = places.filter(place => {
    return typeof place.latitude === 'number' && typeof place.longitude === 'number' &&
      Number.isFinite(place.latitude) && Number.isFinite(place.longitude) &&
      place.latitude !== 0 && place.longitude !== 0
  })
  if (validPlaces.length === 0) {
    return null
  }

  let north = validPlaces[0].latitude
  let south = validPlaces[0].latitude
  let east = validPlaces[0].longitude
  let west = validPlaces[0].longitude
  for (let i = 1; i < validPlaces.length; i++) {
    const place = validPlaces[i]
    north = Math.max(north, place.latitude)
    south = Math.min(south, place.latitude)
    east = Math.max(east, place.longitude)
    west = Math.min(west, place.longitude)
  }

  const latPadding = Math.max((north - south) * 0.28, 0.006)
  const lngPadding = Math.max((east - west) * 0.28, 0.008)
  return {
    north: north + latPadding,
    south: south - latPadding,
    east: east + lngPadding,
    west: west - lngPadding,
    centerLat: (north + south) / 2,
    centerLng: (east + west) / 2,
    zoom: validPlaces.length > 3 ? 13 : 14,
  }
}

function appendUniqueWarning(warnings, message) {
  if (!warnings.includes(message)) {
    warnings.push(message)
  }
}

function validateTravelPlan(plan) {
  if (!plan || typeof plan !== 'object') {
    throw new TravelPlanError('validate', 'plan must be an object')
  }
  if (!plan.preference || typeof plan.preference !== 'object') {
    throw new TravelPlanError('validate', 'preference must be an object')
  }
  if (!Array.isArray(plan.places) || plan.places.length === 0) {
    throw new TravelPlanError('validate', 'places must contain at least one real place')
  }
  if (!Array.isArray(plan.timeline) || plan.timeline.length === 0) {
    throw new TravelPlanError('validate', 'timeline must contain at least one item')
  }

  assertString(plan.summary, 'summary')
  assertString(plan.preference.travelDate, 'preference.travelDate')
  assertString(plan.preference.startDate, 'preference.startDate')
  assertString(plan.preference.endDate, 'preference.endDate')
  assertString(plan.preference.startTime, 'preference.startTime')
  assertNumber(plan.preference.peopleCount, 'preference.peopleCount')
  assertString(plan.preference.purpose, 'preference.purpose')
  assertString(plan.preference.attractionPreference, 'preference.attractionPreference')
  assertString(plan.preference.hotelPreference, 'preference.hotelPreference')
  for (let i = 0; i < plan.places.length; i++) {
    const place = plan.places[i]
    assertString(place.id, `places[${i}].id`)
    assertString(place.name, `places[${i}].name`)
    assertString(place.category, `places[${i}].category`)
    assertString(place.address, `places[${i}].address`)
    assertNumber(place.latitude, `places[${i}].latitude`)
    assertNumber(place.longitude, `places[${i}].longitude`)
    assertString(place.openingHours, `places[${i}].openingHours`)
    assertNumber(place.recommendedDurationMinutes, `places[${i}].recommendedDurationMinutes`)
    assertString(place.note, `places[${i}].note`)
  }

  if (!plan.region || typeof plan.region !== 'object') {
    throw new TravelPlanError('validate', 'region must be an object')
  }
  assertNumber(plan.region.north, 'region.north')
  assertNumber(plan.region.south, 'region.south')
  assertNumber(plan.region.east, 'region.east')
  assertNumber(plan.region.west, 'region.west')
  assertNumber(plan.region.centerLat, 'region.centerLat')
  assertNumber(plan.region.centerLng, 'region.centerLng')
  assertNumber(plan.region.zoom, 'region.zoom')
}

function superviseTravelPlan(plan, preference, evidenceText, screenshotProvided) {
  validateTravelPlan(plan)

  const warnings = Array.isArray(plan.warnings) ? plan.warnings.filter(item => typeof item === 'string') : []
  const correctedFields = []
  const textualEvidenceAvailable = evidenceText.length >= 20
  const placeIds = new Set()
  let validCoordinateCount = 0

  assertValidPreference(preference)
  plan.preference = {
    travelDate: preference.travelDate || preference.startDate,
    startDate: preference.startDate,
    endDate: preference.endDate,
    startTime: preference.startTime,
    peopleCount: preference.peopleCount,
    purpose: preference.purpose,
    attractionPreference: preference.attractionPreference,
    hotelPreference: preference.hotelPreference,
  }
  correctedFields.push('preference')

  for (let i = 0; i < plan.places.length; i++) {
    const place = plan.places[i]
    if (placeIds.has(place.id)) {
      throw new TravelPlanError('supervision', `duplicate place id: ${place.id}`)
    }
    placeIds.add(place.id)

    if (!ALLOWED_PLACE_CATEGORIES.has(place.category)) {
      throw new TravelPlanError('supervision', `unsupported category for ${place.name}: ${place.category}`)
    }
    if (place.recommendedDurationMinutes < 15 || place.recommendedDurationMinutes > 480) {
      throw new TravelPlanError('supervision', `unreasonable duration for ${place.name}`)
    }
    if (place.latitude < -90 || place.latitude > 90 || place.longitude < -180 || place.longitude > 180) {
      throw new TravelPlanError('supervision', `invalid coordinates for ${place.name}`)
    }
    if (place.latitude !== 0 && place.longitude !== 0) {
      validCoordinateCount += 1
    } else {
      appendUniqueWarning(warnings, `${place.name} 缺少可监督的真实坐标`)
    }
    if (textualEvidenceAvailable && !screenshotProvided && evidenceText.indexOf(place.name.toLowerCase()) < 0) {
      throw new TravelPlanError('supervision', `place is not present in source text: ${place.name}`)
    }
  }

  if (validCoordinateCount === 0) {
    throw new TravelPlanError('supervision', 'no place has usable coordinates')
  }

  for (let i = 0; i < plan.timeline.length; i++) {
    const item = plan.timeline[i]
    assertString(item.placeId, `timeline[${i}].placeId`)
    assertString(item.arriveTime, `timeline[${i}].arriveTime`)
    assertString(item.leaveTime, `timeline[${i}].leaveTime`)
    assertString(item.openStatus, `timeline[${i}].openStatus`)
    if (!placeIds.has(item.placeId)) {
      throw new TravelPlanError('supervision', `timeline references unknown placeId: ${item.placeId}`)
    }
    const arrive = timeToMinutes(item.arriveTime)
    const leave = timeToMinutes(item.leaveTime)
    if (!Number.isFinite(arrive) || !Number.isFinite(leave) || leave <= arrive) {
      throw new TravelPlanError('supervision', `invalid timeline time range for ${item.placeId}`)
    }
    if (leave - arrive > 720) {
      throw new TravelPlanError('supervision', `timeline stay is too long for ${item.placeId}`)
    }
    if (i > 0) {
      if (!item.commuteFromPrevious || typeof item.commuteFromPrevious !== 'object') {
        throw new TravelPlanError('supervision', `timeline[${i}].commuteFromPrevious is required`)
      }
      assertString(item.commuteFromPrevious.fromPlaceId, `timeline[${i}].commuteFromPrevious.fromPlaceId`)
      assertString(item.commuteFromPrevious.toPlaceId, `timeline[${i}].commuteFromPrevious.toPlaceId`)
      assertNumber(item.commuteFromPrevious.distanceKm, `timeline[${i}].commuteFromPrevious.distanceKm`)
      assertNumber(item.commuteFromPrevious.durationMinutes, `timeline[${i}].commuteFromPrevious.durationMinutes`)
      assertString(item.commuteFromPrevious.transport, `timeline[${i}].commuteFromPrevious.transport`)
      if (!placeIds.has(item.commuteFromPrevious.fromPlaceId) || item.commuteFromPrevious.toPlaceId !== item.placeId) {
        throw new TravelPlanError('supervision', `invalid commute link for ${item.placeId}`)
      }
      if (item.commuteFromPrevious.distanceKm < 0 || item.commuteFromPrevious.distanceKm > 300 ||
        item.commuteFromPrevious.durationMinutes < 0 || item.commuteFromPrevious.durationMinutes > 360) {
        throw new TravelPlanError('supervision', `unreasonable commute for ${item.placeId}`)
      }
    }
  }

  const supervisedRegion = calculateRegionFromPlaces(plan.places)
  if (supervisedRegion !== null) {
    plan.region = supervisedRegion
    correctedFields.push('region')
  }

  plan.warnings = warnings
  plan.supervision = {
    passed: true,
    checkedBy: 'deterministic-rules',
    correctedFields,
    warnings,
  }
  return plan
}

async function generateTravelPlan(input, requestId) {
  assertValidXhsInput(input)
  const preference = normalizeTravelPreference(input)

  if (SILICONFLOW_API_KEY.length === 0 || SILICONFLOW_API_KEY === 'replace_with_your_key') {
    throw new TravelPlanError('config', 'SILICONFLOW_API_KEY is not configured')
  }

  const postUrl = normalizePostUrl(input)
  const fetchedPostText = await fetchPostText(postUrl, requestId)
  const prompt = buildTravelPlanPrompt(input, fetchedPostText)
  const payload = {
    model: SILICONFLOW_CHAT_MODEL,
    messages: buildTravelMessages(input, prompt),
    temperature: 0.2,
    top_p: 0.7,
    max_tokens: 4096,
    response_format: {
      type: 'json_object',
    },
  }

  logTravelRequest(requestId, `upstream start model=${SILICONFLOW_CHAT_MODEL}, promptChars=${prompt.length}`)
  let upstreamResponse
  const startedAt = nowMs()
  try {
    upstreamResponse = await fetch(SILICONFLOW_CHAT_ENDPOINT, {
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
    throw new TravelPlanError('upstream', `SiliconFlow chat request timed out or failed after ${elapsedMs(startedAt)}ms: ${message}`)
  }
  logTravelRequest(requestId, `upstream response in ${elapsedMs(startedAt)}ms, status=${upstreamResponse.status}`)

  const responseText = await upstreamResponse.text()
  if (!upstreamResponse.ok) {
    throw new TravelPlanError('upstream', `SiliconFlow chat failed with HTTP ${upstreamResponse.status}: ${responseText}`)
  }

  const data = JSON.parse(responseText)
  const content = data.choices && data.choices.length > 0 && data.choices[0].message ? data.choices[0].message.content : ''
  if (typeof content !== 'string' || content.length === 0) {
    throw new TravelPlanError('upstream', 'SiliconFlow chat response does not contain choices[0].message.content')
  }

  const plan = JSON.parse(extractJsonObject(content))
  const supervisedPlan = superviseTravelPlan(plan, preference, buildEvidenceText(input, fetchedPostText), hasScreenshotInput(input))
  return {
    ...supervisedPlan,
    providerTaskId: data.id || requestId,
    model: SILICONFLOW_CHAT_MODEL,
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

async function handleTravelPlan(request, response) {
  const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
  const startedAt = nowMs()
  try {
    const rawBody = await readBody(request)
    logTravelRequest(requestId, `received request bytes=${Buffer.byteLength(rawBody, 'utf8')}`)
    let input
    try {
      input = JSON.parse(rawBody)
    } catch (parseError) {
      throw new TravelPlanError('request', 'Request body must be valid JSON')
    }
    const result = await generateTravelPlan(input, requestId)
    logTravelRequest(requestId, `completed in ${elapsedMs(startedAt)}ms, places=${result.places.length}`)
    sendJson(response, 200, result)
  } catch (error) {
    const stage = error instanceof TravelPlanError ? error.stage : 'server'
    const message = error instanceof Error ? error.message : 'Unknown server error'
    logTravelRequest(requestId, `failed stage=${stage} elapsed=${elapsedMs(startedAt)}ms error=${message}`)
    sendJson(response, stage === 'request' ? 400 : 500, {
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
      travelPlanModel: SILICONFLOW_CHAT_MODEL,
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

  if (request.method === 'POST' && request.url === '/api/travel-plan') {
    handleTravelPlan(request, response)
    return
  }

  sendJson(response, 404, { error: 'Not found' })
})

server.listen(PORT, '0.0.0.0', () => {
  console.log(`VisMap sketch proxy listening on http://0.0.0.0:${PORT}`)
})

server.requestTimeout = UPSTREAM_TIMEOUT_MS + 60000
server.headersTimeout = UPSTREAM_TIMEOUT_MS + 65000
