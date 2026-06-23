import http from 'node:http'
import { spawn } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
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
      if (process.env[key] === undefined) {
        process.env[key] = value
      }
    }
  }
}

const PORT = Number(process.env.PORT || '3000')
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || ''
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash'
const GEMINI_API_BASE = (process.env.GEMINI_API_BASE || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, '')
const UPSTREAM_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS || '180000')
const MAX_BODY_BYTES = 25 * 1024 * 1024
const MAX_TEXT_CHARS = 16000
const ALLOWED_PURPOSES = new Set(['parent_child', 'family', 'fast_paced', 'relaxed', 'foodie', 'photo'])
const ALLOWED_CATEGORIES = new Set(['restaurant', 'landmark', 'shopping', 'museum', 'cafe'])
const collaborationSessions = new Map()

class AppError extends Error {
  constructor(stage, message, statusCode = 500) {
    super(message)
    this.name = 'AppError'
    this.stage = stage
    this.statusCode = statusCode
  }
}

function nowMs() {
  return Date.now()
}

function elapsedMs(startedAt) {
  return Date.now() - startedAt
}

function logRequest(kind, requestId, message) {
  console.log(`[${kind}:${requestId}] ${message}`)
}

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  })
  response.end(JSON.stringify(body))
}

// Collaboration sessions intentionally stay in memory: they are shared by every connected client during development,
// while keeping the sample backend free of database and account-management requirements.
function collaborationCode(planId) {
  const value = typeof planId === 'string' ? planId.trim().toUpperCase() : ''
  if (value.length < 4) {
    throw new AppError('collaboration', 'plan.id must contain at least 4 characters', 400)
  }
  return value.length > 8 ? value.slice(-8) : value
}

function normalizeCollaborationCode(value) {
  const code = typeof value === 'string' ? value.trim().toUpperCase() : ''
  if (!/^[A-Z0-9-]{4,64}$/.test(code)) {
    throw new AppError('collaboration', 'Invalid collaboration code', 400)
  }
  return code
}

function normalizeMemberName(value) {
  const name = compactText(value, 40)
  if (name.length === 0) {
    throw new AppError('collaboration', 'Member name is required', 400)
  }
  return name
}

function collaborationResponse(session) {
  return {
    code: session.code,
    revision: session.revision,
    updatedAt: session.updatedAt,
    plan: session.plan,
    members: session.members,
  }
}

function createOrLoadCollaborationSession(input) {
  if (!input || typeof input.plan !== 'object' || input.plan === null) {
    throw new AppError('collaboration', 'plan is required', 400)
  }
  const code = collaborationCode(input.plan.id)
  const existing = collaborationSessions.get(code)
  if (existing) {
    return collaborationResponse(existing)
  }
  const ownerName = normalizeMemberName(input.ownerName || '我')
  const session = {
    code,
    revision: 1,
    updatedAt: new Date().toISOString(),
    plan: input.plan,
    members: [{ id: 'owner', name: ownerName, permission: 'edit', status: '在线' }],
  }
  collaborationSessions.set(code, session)
  return collaborationResponse(session)
}

function loadCollaborationSession(code) {
  const session = collaborationSessions.get(normalizeCollaborationCode(code))
  if (!session) {
    throw new AppError('collaboration', 'Collaboration session was not found', 404)
  }
  return session
}

function addCollaborationMember(code, input) {
  const session = loadCollaborationSession(code)
  const name = normalizeMemberName(input && input.name)
  const permission = input && input.permission === 'view' ? 'view' : 'edit'
  let member = null
  for (const item of session.members) {
    if (item.name === name) {
      member = item
      break
    }
  }
  if (member) {
    member.status = '在线'
  } else {
    member = {
      id: `member-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`,
      name,
      permission,
      status: '在线',
    }
    session.members.push(member)
  }
  session.updatedAt = new Date().toISOString()
  return collaborationResponse(session)
}

function updateCollaborationPlan(code, input) {
  const session = loadCollaborationSession(code)
  if (!input || typeof input.plan !== 'object' || input.plan === null) {
    throw new AppError('collaboration', 'plan is required', 400)
  }
  const clientRevision = Number(input.revision)
  if (!Number.isInteger(clientRevision) || clientRevision !== session.revision) {
    throw new AppError('collaboration', 'This plan changed on another device. Refresh before saving again.', 409)
  }
  const editorName = compactText(input.editorName, 40)
  let editor = null
  for (const member of session.members) {
    if (member.name === editorName) {
      editor = member
      break
    }
  }
  if (!editor || editor.permission !== 'edit') {
    throw new AppError('collaboration', 'This member does not have edit permission', 403)
  }
  session.plan = input.plan
  session.revision += 1
  session.updatedAt = new Date().toISOString()
  editor.status = '刚刚更新行程'
  return collaborationResponse(session)
}

function updateCollaborationMemberPermission(code, memberId, input) {
  const session = loadCollaborationSession(code)
  if (!input || (input.permission !== 'edit' && input.permission !== 'view')) {
    throw new AppError('collaboration', 'permission must be edit or view', 400)
  }
  for (const member of session.members) {
    if (member.id === memberId) {
      if (member.id === 'owner') {
        throw new AppError('collaboration', 'Owner permission cannot be changed', 400)
      }
      member.permission = input.permission
      session.updatedAt = new Date().toISOString()
      return collaborationResponse(session)
    }
  }
  throw new AppError('collaboration', 'Member was not found', 404)
}

function readBody(request) {
  return new Promise((resolveBody, rejectBody) => {
    let body = ''
    let size = 0
    request.on('data', chunk => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        request.destroy()
        rejectBody(new AppError('request', 'Request body is too large', 413))
        return
      }
      body += chunk.toString('utf8')
    })
    request.on('end', () => resolveBody(body))
    request.on('error', error => rejectBody(error))
  })
}

function compactText(value, maxChars = MAX_TEXT_CHARS) {
  if (typeof value !== 'string') {
    return ''
  }
  const compacted = value.replace(/\s+/g, ' ').trim()
  if (compacted.length <= maxChars) {
    return compacted
  }
  return compacted.slice(0, maxChars)
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

function normalizePreference(input) {
  const raw = input && typeof input.preference === 'object' && input.preference !== null ? input.preference : {}
  const startDate = typeof raw.startDate === 'string' ? raw.startDate : ''
  const endDate = typeof raw.endDate === 'string' ? raw.endDate : ''
  const travelDate = typeof raw.travelDate === 'string' && raw.travelDate.length > 0 ? raw.travelDate : startDate
  const peopleCount = Number(raw.peopleCount)
  return {
    travelDate,
    startDate,
    endDate,
    startTime: typeof raw.startTime === 'string' && raw.startTime.length > 0 ? raw.startTime : '09:30',
    peopleCount: Number.isFinite(peopleCount) ? Math.round(peopleCount) : 2,
    purpose: typeof raw.purpose === 'string' ? raw.purpose : 'relaxed',
    travelPace: compactText(raw.travelPace || raw.attractionPreference || '', 200),
    foodPreference: compactText(raw.foodPreference || '', 600),
    attractionPreference: compactText(raw.attractionPreference || '', 1200),
    hotelPreference: compactText(raw.hotelPreference || '', 1200),
  }
}

function assertValidPreference(preference) {
  if (!isDateText(preference.startDate) || !isDateText(preference.endDate)) {
    throw new AppError('request', 'preference.startDate and preference.endDate must use YYYY-MM-DD', 400)
  }
  const dayCount = daysBetween(preference.startDate, preference.endDate)
  if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 14) {
    throw new AppError('request', 'travel date range must be 1 to 14 days', 400)
  }
  if (!isTimeText(preference.startTime)) {
    throw new AppError('request', 'preference.startTime must use HH:mm', 400)
  }
  if (!Number.isFinite(preference.peopleCount) || preference.peopleCount < 1 || preference.peopleCount > 20) {
    throw new AppError('request', 'preference.peopleCount must be a number from 1 to 20', 400)
  }
  if (!ALLOWED_PURPOSES.has(preference.purpose)) {
    throw new AppError('request', 'preference.purpose is not supported', 400)
  }
}

function parseImageData(image) {
  if (typeof image !== 'string' || image.trim().length === 0) {
    return null
  }
  const trimmed = image.trim()
  const match = trimmed.match(/^data:([^;]+);base64,(.+)$/)
  if (match) {
    return {
      mimeType: match[1],
      data: match[2],
    }
  }
  return {
    mimeType: 'image/png',
    data: trimmed,
  }
}

function buildInitialPlanPrompt(input, preference) {
  const destinationName = compactText(input.destinationName || input.destination || '', 120)
  const destinationAddress = compactText(input.destinationAddress || '', 240)
  const postText = compactText(input.postText || input.sharedPostText || '', MAX_TEXT_CHARS)
  const postUrl = compactText(input.postUrl || '', 1000)
  return `你是 WanderSketch 的旅行路线规划引擎。请根据用户目的地、出行日期、偏好和帖子截图/文字，规划真实可执行的旅行地点和路线。

必须只输出严格 JSON，不要 Markdown，不要解释文字。

规划原则：
1. 地点必须围绕目的地，不要跨城市乱跳。
2. 优先使用截图/帖子里出现的地点；不足时可以补充目的地内常见真实地点，但 warnings 必须说明补充原因。
3. 每天从 startTime 开始，按空间顺路安排，避免来回折返。
4. 对每个地点判断 indoor、rainFriendly、weatherSensitive，方便后续雨天重规划。
5. 坐标必须尽量给出真实经纬度；不确定时给 0 并写入 warnings。
6. timeline 是整个行程的扁平列表，按时间顺序排列。
7. category 只能是 restaurant、landmark、shopping、museum、cafe。
8. 每段 commuteFromPrevious 必须给出具体交通方案：步行、公交、地铁或打车；公交/地铁要写线路名、上车站、下车站、换乘和预计总时间；步行要写大致路径和时间；不确定时在 transport 末尾写“需用 Google Maps 复核”。
9. 必须为每一天提供早餐、午餐、晚餐：优先给出目的地内具体、真实且符合饮食偏好的餐厅；每餐给出推荐菜/理由与人均预估金额（人民币），并汇总每天预算和全程总预算。

用户输入：
destinationName=${destinationName || '未提供'}
destinationAddress=${destinationAddress || '未提供'}
postUrl=${postUrl || '未提供'}
postText=${postText || '未提供'}
startDate=${preference.startDate}
endDate=${preference.endDate}
startTime=${preference.startTime}
peopleCount=${preference.peopleCount}
purpose=${preference.purpose}
travelPace=${preference.travelPace || '未提供'}
foodPreference=${preference.foodPreference || '未提供'}
attractionPreference=${preference.attractionPreference || '未提供'}
hotelPreference=${preference.hotelPreference || '未提供'}

输出 JSON schema：
{
  "preference": {
    "travelDate": "YYYY-MM-DD",
    "startDate": "YYYY-MM-DD",
    "endDate": "YYYY-MM-DD",
    "startTime": "HH:mm",
    "peopleCount": 2,
    "purpose": "relaxed",
    "travelPace": "string",
    "foodPreference": "string",
    "attractionPreference": "string",
    "hotelPreference": "string"
  },
  "places": [
    {
      "id": "stable-kebab-case-id",
      "name": "地点名称",
      "category": "restaurant|landmark|shopping|museum|cafe",
      "address": "地址或空字符串",
      "latitude": 0,
      "longitude": 0,
      "openingHours": "营业时间或需确认",
      "recommendedDurationMinutes": 90,
      "note": "安排原因",
      "indoor": true,
      "rainFriendly": true,
      "weatherSensitive": false,
      "backupPlaceIds": []
    }
  ],
  "timeline": [
    {
      "placeId": "places.id",
      "arriveTime": "HH:mm",
      "leaveTime": "HH:mm",
      "commuteFromPrevious": {
        "fromPlaceId": "上一地点 id，第一项为空字符串",
        "toPlaceId": "当前地点 id",
        "distanceKm": 0,
        "durationMinutes": 0,
        "transport": "具体交通说明，例如：步行约8分钟，经五马街；公交4路 五马街站->江心码头站约18分钟，步行6分钟；地铁S1线 某站->某站约25分钟；打车约20分钟"
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
  "summary": "一句话行程概述",
  "dailyMeals": [{
    "date": "YYYY-MM-DD",
    "breakfast": { "restaurantName": "具体餐厅名", "recommendation": "推荐菜或原因", "estimatedCost": 35 },
    "lunch": { "restaurantName": "具体餐厅名", "recommendation": "推荐菜或原因", "estimatedCost": 80 },
    "dinner": { "restaurantName": "具体餐厅名", "recommendation": "推荐菜或原因", "estimatedCost": 120 },
    "dayBudget": 235
  }],
  "totalBudget": 940,
  "confidence": 0.8,
  "warnings": []
}`
}

function buildReplanPrompt(input) {
  const currentPlan = JSON.stringify(input.plan || {})
  const weather = JSON.stringify(input.weather || {})
  const currentLocation = JSON.stringify(input.currentLocation || {})
  const reason = compactText(input.reason || 'weather_change', 120)
  const currentTime = compactText(input.currentTime || '', 80)
  return `你是 WanderSketch 的实时行程重规划引擎。请基于当前完整行程、当前位置、当前时间和天气，局部重规划当前时间之后的路线。

必须只输出严格 JSON，不要 Markdown，不要解释文字。

重规划原则：
1. 已经发生或当前时间之前的行程不要改。
2. 如果下雨、强风、酷热、雷暴，优先替换为 indoor=true 或 rainFriendly=true 的地点。
3. 保留酒店、预约、餐厅等强约束，除非天气严重影响。
4. 输出完整 TravelPlan 结构，不只输出差异。
5. 在 summary 和 warnings 中说明替换原因。
6. 同步重算每段 commuteFromPrevious，transport 要包含具体线路/站点/换乘/步行段和预计总时间；不确定时写“需用 Google Maps 复核”。
7. 保留并输出 dailyMeals 与 totalBudget；每一天必须有早餐、午餐、晚餐、具体餐厅、推荐内容和人民币预算。若调整了当天地点，同步调整附近餐厅与当天预算。

reason=${reason}
currentTime=${currentTime || '未提供'}
currentLocation=${currentLocation}
weather=${weather}
currentPlan=${currentPlan}

输出 JSON schema 与 /api/travel-plan 完全一致。`
}

function buildGeminiParts(prompt, image) {
  const parts = [{ text: prompt }]
  const parsedImage = parseImageData(image)
  if (parsedImage !== null) {
    parts.push({
      inlineData: {
        mimeType: parsedImage.mimeType,
        data: parsedImage.data,
      },
    })
  }
  return parts
}

async function callGemini(prompt, image, requestId, kind) {
  if (GEMINI_API_KEY.length === 0 || GEMINI_API_KEY === 'replace_with_your_key') {
    throw new AppError('config', 'GEMINI_API_KEY is not configured')
  }

  const url = `${GEMINI_API_BASE}/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent`
  const body = {
    contents: [
      {
        role: 'user',
        parts: buildGeminiParts(prompt, image),
      },
    ],
    generationConfig: {
      temperature: 0.35,
      topP: 0.8,
      responseMimeType: 'application/json',
    },
  }

  const startedAt = nowMs()
  logRequest(kind, requestId, `gemini start model=${GEMINI_MODEL}, promptChars=${prompt.length}`)
  try {
    return await callGeminiWithCurl(url, body, requestId, kind, startedAt)
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown upstream error'
    logRequest(kind, requestId, `gemini curl failed, trying fetch fallback: ${message}`)
  }

  let upstreamResponse
  try {
    upstreamResponse = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown upstream error'
    throw new AppError('upstream', `Gemini curl and fetch both failed: ${message}`)
  }

  const responseText = await upstreamResponse.text()
  logRequest(kind, requestId, `gemini fetch response status=${upstreamResponse.status}, elapsed=${elapsedMs(startedAt)}ms`)
  if (!upstreamResponse.ok) {
    throw new AppError('upstream', `Gemini failed with HTTP ${upstreamResponse.status}: ${responseText}`)
  }

  const data = JSON.parse(responseText)
  const candidate = Array.isArray(data.candidates) && data.candidates.length > 0 ? data.candidates[0] : null
  const parts = candidate && candidate.content && Array.isArray(candidate.content.parts) ? candidate.content.parts : []
  const text = parts.map(part => typeof part.text === 'string' ? part.text : '').join('').trim()
  if (text.length === 0) {
    throw new AppError('upstream', 'Gemini response did not contain text')
  }
  return {
    data,
    text,
  }
}

function callGeminiWithCurl(url, body, requestId, kind, startedAt) {
  return new Promise((resolveCall, rejectCall) => {
    const child = spawn('curl.exe', [
      '-sS',
      '-X', 'POST',
      url,
      '-H', 'Content-Type: application/json',
      '-H', `x-goog-api-key: ${GEMINI_API_KEY}`,
      '--data-binary', '@-',
      '-w', '\n__HTTP_STATUS__:%{http_code}',
    ], {
      windowsHide: true,
    })

    let stdout = ''
    let stderr = ''
    const timer = setTimeout(() => {
      child.kill()
      rejectCall(new AppError('upstream', `Gemini curl timed out after ${elapsedMs(startedAt)}ms`))
    }, UPSTREAM_TIMEOUT_MS)

    child.stdout.on('data', chunk => {
      stdout += chunk.toString('utf8')
    })
    child.stderr.on('data', chunk => {
      stderr += chunk.toString('utf8')
    })
    child.on('error', error => {
      clearTimeout(timer)
      rejectCall(new AppError('upstream', `Gemini curl could not start: ${error.message}`))
    })
    child.on('close', code => {
      clearTimeout(timer)
      if (code !== 0) {
        rejectCall(new AppError('upstream', `Gemini curl failed with exit ${code}: ${stderr}`))
        return
      }
      const marker = '\n__HTTP_STATUS__:'
      const markerIndex = stdout.lastIndexOf(marker)
      if (markerIndex < 0) {
        rejectCall(new AppError('upstream', `Gemini curl response missed HTTP status: ${stdout}`))
        return
      }
      const responseText = stdout.slice(0, markerIndex)
      const status = Number(stdout.slice(markerIndex + marker.length).trim())
      logRequest(kind, requestId, `gemini curl response status=${status}, elapsed=${elapsedMs(startedAt)}ms`)
      if (!Number.isFinite(status) || status < 200 || status >= 300) {
        rejectCall(new AppError('upstream', `Gemini failed with HTTP ${status}: ${responseText}`))
        return
      }
      try {
        const data = JSON.parse(responseText)
        const candidate = Array.isArray(data.candidates) && data.candidates.length > 0 ? data.candidates[0] : null
        const parts = candidate && candidate.content && Array.isArray(candidate.content.parts) ? candidate.content.parts : []
        const text = parts.map(part => typeof part.text === 'string' ? part.text : '').join('').trim()
        if (text.length === 0) {
          rejectCall(new AppError('upstream', 'Gemini curl response did not contain text'))
          return
        }
        resolveCall({ data, text })
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown parse error'
        rejectCall(new AppError('parse', `Failed to parse Gemini curl response: ${message}`))
      }
    })

    child.stdin.write(JSON.stringify(body))
    child.stdin.end()
  })
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
  throw new AppError('parse', 'Model response did not contain a JSON object')
}

function assertString(value, path) {
  if (typeof value !== 'string') {
    throw new AppError('validate', `${path} must be a string`)
  }
}

function assertNumber(value, path) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new AppError('validate', `${path} must be a finite number`)
  }
}

function normalizeId(value, fallback) {
  const raw = typeof value === 'string' ? value : fallback
  const normalized = raw.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-').replace(/^-+|-+$/g, '')
  return normalized.length > 0 ? normalized : fallback
}

function resolveTimelinePlaceId(item, index, placeIds, placeNameToId) {
  if (typeof item.placeId === 'string') {
    const normalized = normalizeId(item.placeId, item.placeId)
    if (placeIds.has(normalized)) {
      return normalized
    }
    if (placeNameToId.has(item.placeId)) {
      return placeNameToId.get(item.placeId)
    }
    return item.placeId
  }
  if (item.place && typeof item.place === 'object') {
    if (typeof item.place.id === 'string') {
      const normalized = normalizeId(item.place.id, item.place.id)
      if (placeIds.has(normalized)) {
        return normalized
      }
      if (placeNameToId.has(item.place.id)) {
        return placeNameToId.get(item.place.id)
      }
    }
    if (typeof item.place.name === 'string' && placeNameToId.has(item.place.name)) {
      return placeNameToId.get(item.place.name)
    }
  }
  if (typeof item.id === 'string') {
    const normalized = normalizeId(item.id, item.id)
    if (placeIds.has(normalized)) {
      return normalized
    }
    if (placeNameToId.has(item.id)) {
      return placeNameToId.get(item.id)
    }
  }
  throw new AppError('validate', `timeline[${index}].placeId must be a string`)
}

function calculateRegionFromPlaces(places) {
  const validPlaces = places.filter(place => {
    return Number.isFinite(place.latitude) && Number.isFinite(place.longitude) && place.latitude !== 0 && place.longitude !== 0
  })
  if (validPlaces.length === 0) {
    return {
      north: 30.318,
      south: 30.205,
      east: 120.245,
      west: 120.07,
      centerLat: 30.257,
      centerLng: 120.1551,
      zoom: 12,
    }
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

function addDays(dateText, offset) {
  const date = new Date(`${dateText}T00:00:00Z`)
  date.setUTCDate(date.getUTCDate() + offset)
  return date.toISOString().slice(0, 10)
}

function normalizeMeal(raw, label) {
  const source = raw && typeof raw === 'object' ? raw : {}
  const estimatedCost = Number(source.estimatedCost)
  return {
    restaurantName: compactText(source.restaurantName || `${label}待推荐`, 160),
    recommendation: compactText(source.recommendation || '请结合当天行程与饮食偏好选择。', 300),
    estimatedCost: Number.isFinite(estimatedCost) ? Math.max(0, Math.round(estimatedCost)) : 0,
  }
}

function normalizeDailyMeals(rawMeals, preference) {
  const values = Array.isArray(rawMeals) ? rawMeals : []
  const dayCount = daysBetween(preference.startDate, preference.endDate)
  const result = []
  for (let offset = 0; offset < dayCount; offset += 1) {
    const date = addDays(preference.startDate, offset)
    let source = null
    for (let index = 0; index < values.length; index += 1) {
      if (values[index] && values[index].date === date) {
        source = values[index]
        break
      }
    }
    const breakfast = normalizeMeal(source && source.breakfast, '早餐')
    const lunch = normalizeMeal(source && source.lunch, '午餐')
    const dinner = normalizeMeal(source && source.dinner, '晚餐')
    const requestedBudget = Number(source && source.dayBudget)
    const calculatedBudget = breakfast.estimatedCost + lunch.estimatedCost + dinner.estimatedCost
    result.push({
      date,
      breakfast,
      lunch,
      dinner,
      dayBudget: Number.isFinite(requestedBudget) ? Math.max(0, Math.round(requestedBudget)) : calculatedBudget,
    })
  }
  return result
}

function validateAndNormalizePlan(plan, preference) {
  if (!plan || typeof plan !== 'object') {
    throw new AppError('validate', 'plan must be an object')
  }
  if (!Array.isArray(plan.places) || plan.places.length === 0) {
    throw new AppError('validate', 'places must contain at least one place')
  }
  if (!Array.isArray(plan.timeline) || plan.timeline.length === 0) {
    throw new AppError('validate', 'timeline must contain at least one item')
  }

  const warnings = Array.isArray(plan.warnings) ? plan.warnings.filter(item => typeof item === 'string') : []
  const places = []
  const placeIds = new Set()
  const placeNameToId = new Map()
  for (let i = 0; i < plan.places.length; i++) {
    const place = plan.places[i]
    assertString(place.name, `places[${i}].name`)
    const id = normalizeId(place.id, `place-${i + 1}`)
    const category = ALLOWED_CATEGORIES.has(place.category) ? place.category : 'landmark'
    const normalizedPlace = {
      id,
      name: place.name,
      category,
      address: typeof place.address === 'string' ? place.address : '',
      latitude: Number(place.latitude || 0),
      longitude: Number(place.longitude || 0),
      openingHours: typeof place.openingHours === 'string' ? place.openingHours : '需确认',
      recommendedDurationMinutes: Number.isFinite(Number(place.recommendedDurationMinutes)) ? Math.max(15, Math.min(480, Math.round(Number(place.recommendedDurationMinutes)))) : 90,
      note: typeof place.note === 'string' ? place.note : '',
      indoor: Boolean(place.indoor),
      rainFriendly: Boolean(place.rainFriendly),
      weatherSensitive: Boolean(place.weatherSensitive),
      backupPlaceIds: Array.isArray(place.backupPlaceIds) ? place.backupPlaceIds.filter(item => typeof item === 'string') : [],
    }
    if (placeIds.has(id)) {
      throw new AppError('validate', `duplicate place id: ${id}`)
    }
    placeIds.add(id)
    if (!Number.isFinite(normalizedPlace.latitude) || !Number.isFinite(normalizedPlace.longitude)) {
      normalizedPlace.latitude = 0
      normalizedPlace.longitude = 0
      warnings.push(`${normalizedPlace.name} 缺少可用坐标`)
    }
    places.push(normalizedPlace)
    placeNameToId.set(normalizedPlace.name, normalizedPlace.id)
    if (typeof place.id === 'string') {
      placeNameToId.set(place.id, normalizedPlace.id)
    }
  }

  const timeline = []
  for (let i = 0; i < plan.timeline.length; i++) {
    const item = plan.timeline[i]
    const placeId = resolveTimelinePlaceId(item, i, placeIds, placeNameToId)
    assertString(item.arriveTime, `timeline[${i}].arriveTime`)
    assertString(item.leaveTime, `timeline[${i}].leaveTime`)
    if (!placeIds.has(placeId)) {
      throw new AppError('validate', `timeline references unknown placeId: ${placeId}`)
    }
    const commute = item.commuteFromPrevious && typeof item.commuteFromPrevious === 'object' ? item.commuteFromPrevious : null
    const normalizedItem = {
      placeId,
      arriveTime: item.arriveTime,
      leaveTime: item.leaveTime,
      openStatus: typeof item.openStatus === 'string' ? item.openStatus : '需确认',
    }
    if (commute !== null && i > 0) {
      normalizedItem.commuteFromPrevious = {
        fromPlaceId: typeof commute.fromPlaceId === 'string' ? commute.fromPlaceId : timeline[i - 1].placeId,
        toPlaceId: placeId,
        distanceKm: Number.isFinite(Number(commute.distanceKm)) ? Number(commute.distanceKm) : 0,
        durationMinutes: Number.isFinite(Number(commute.durationMinutes)) ? Math.round(Number(commute.durationMinutes)) : 0,
        transport: typeof commute.transport === 'string' ? commute.transport : '打车',
      }
    }
    timeline.push(normalizedItem)
  }

  assertString(plan.summary, 'summary')
  const dailyMeals = normalizeDailyMeals(plan.dailyMeals, preference)
  const calculatedBudget = dailyMeals.reduce((total, day) => total + day.dayBudget, 0)
  return {
    preference: {
      travelDate: preference.travelDate || preference.startDate,
      startDate: preference.startDate,
      endDate: preference.endDate,
      startTime: preference.startTime,
      peopleCount: preference.peopleCount,
      purpose: preference.purpose,
      travelPace: preference.travelPace,
      foodPreference: preference.foodPreference,
      attractionPreference: preference.attractionPreference,
      hotelPreference: preference.hotelPreference,
    },
    places,
    timeline,
    region: calculateRegionFromPlaces(places),
    summary: plan.summary,
    dailyMeals,
    totalBudget: Number.isFinite(Number(plan.totalBudget)) ? Math.max(0, Math.round(Number(plan.totalBudget))) : calculatedBudget,
    confidence: typeof plan.confidence === 'number' ? plan.confidence : 0.7,
    warnings,
  }
}

async function generateInitialPlan(input, requestId) {
  if (!input || typeof input !== 'object') {
    throw new AppError('request', 'JSON body is required', 400)
  }
  const preference = normalizePreference(input)
  assertValidPreference(preference)
  const prompt = buildInitialPlanPrompt(input, preference)
  const result = await callGemini(prompt, input.screenshotImage, requestId, 'travel-plan')
  const rawPlan = JSON.parse(extractJsonObject(result.text))
  return {
    ...validateAndNormalizePlan(rawPlan, preference),
    providerTaskId: result.data.responseId || requestId,
    model: GEMINI_MODEL,
  }
}

async function replanTravel(input, requestId) {
  if (!input || typeof input !== 'object') {
    throw new AppError('request', 'JSON body is required', 400)
  }
  const preference = normalizePreference(input.plan || input)
  assertValidPreference(preference)
  const prompt = buildReplanPrompt(input)
  const result = await callGemini(prompt, '', requestId, 'travel-replan')
  const rawPlan = JSON.parse(extractJsonObject(result.text))
  return {
    ...validateAndNormalizePlan(rawPlan, preference),
    providerTaskId: result.data.responseId || requestId,
    model: GEMINI_MODEL,
  }
}

async function handleJsonEndpoint(request, response, kind, handler) {
  const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
  const startedAt = nowMs()
  try {
    const rawBody = await readBody(request)
    logRequest(kind, requestId, `received bytes=${Buffer.byteLength(rawBody, 'utf8')}`)
    let input
    try {
      input = rawBody.length > 0 ? JSON.parse(rawBody) : {}
    } catch (error) {
      throw new AppError('request', 'Request body must be valid JSON', 400)
    }
    const result = await handler(input, requestId)
    logRequest(kind, requestId, `completed elapsed=${elapsedMs(startedAt)}ms`)
    sendJson(response, 200, result)
  } catch (error) {
    const appError = error instanceof AppError ? error : new AppError('server', error instanceof Error ? error.message : 'Unknown server error')
    logRequest(kind, requestId, `failed stage=${appError.stage} elapsed=${elapsedMs(startedAt)}ms error=${appError.message}`)
    sendJson(response, appError.statusCode || 500, {
      error: appError.message,
      stage: appError.stage,
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
      model: GEMINI_MODEL,
      provider: 'gemini',
      upstreamTimeoutMs: UPSTREAM_TIMEOUT_MS,
      hasApiKey: GEMINI_API_KEY.length > 0 && GEMINI_API_KEY !== 'replace_with_your_key',
      endpoints: ['/api/travel-plan', '/api/travel-plan/replan', '/api/collaboration/sessions'],
    })
    return
  }

  if (request.method === 'POST' && request.url === '/api/travel-plan') {
    handleJsonEndpoint(request, response, 'travel-plan', generateInitialPlan)
    return
  }

  if (request.method === 'POST' && request.url === '/api/travel-plan/replan') {
    handleJsonEndpoint(request, response, 'travel-replan', replanTravel)
    return
  }

  const path = new URL(request.url || '/', 'http://localhost').pathname
  const collaborationMatch = path.match(/^\/api\/collaboration\/sessions\/([^/]+)(?:\/(plan|members)(?:\/([^/]+))?)?$/)
  if (request.method === 'POST' && path === '/api/collaboration/sessions') {
    handleJsonEndpoint(request, response, 'collaboration-create', createOrLoadCollaborationSession)
    return
  }
  if (collaborationMatch) {
    const code = decodeURIComponent(collaborationMatch[1])
    const resource = collaborationMatch[2]
    const memberId = collaborationMatch[3] === undefined ? '' : decodeURIComponent(collaborationMatch[3])
    if (request.method === 'GET' && resource === undefined) {
      handleJsonEndpoint(request, response, 'collaboration-load', async () => collaborationResponse(loadCollaborationSession(code)))
      return
    }
    if (request.method === 'POST' && resource === 'members' && memberId.length === 0) {
      handleJsonEndpoint(request, response, 'collaboration-member-add', input => addCollaborationMember(code, input))
      return
    }
    if (request.method === 'PUT' && resource === 'plan') {
      handleJsonEndpoint(request, response, 'collaboration-plan-save', input => updateCollaborationPlan(code, input))
      return
    }
    if (request.method === 'PUT' && resource === 'members' && memberId.length > 0) {
      handleJsonEndpoint(request, response, 'collaboration-member-update', input => updateCollaborationMemberPermission(code, memberId, input))
      return
    }
  }

  sendJson(response, 404, { error: 'Not found' })
})

server.listen(PORT, '0.0.0.0', () => {
  console.log(`WanderSketch travel planner listening on http://0.0.0.0:${PORT}`)
})

server.requestTimeout = UPSTREAM_TIMEOUT_MS + 60000
server.headersTimeout = UPSTREAM_TIMEOUT_MS + 65000
