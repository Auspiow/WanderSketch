# WanderSketch Travel Planner Backend

This backend exposes Gemini-powered travel planning APIs for the HarmonyOS app.

## Run

```powershell
Copy-Item server\.env.example server\.env
# Edit server\.env and set GEMINI_API_KEY. The mobile client keys are configured
# separately in the repository-root `.env`; run `node scripts/generate-api-config.mjs`
# before building the HarmonyOS app.
node server\src\index.js
```

Health check:

```powershell
curl.exe http://127.0.0.1:3000/health
```

## Endpoints

### `POST /api/travel-plan`

Generates an initial itinerary from destination, date range, preferences, post text,
and an optional base64 screenshot.

Request shape:

```json
{
  "destinationName": "杭州",
  "destinationAddress": "浙江省杭州市",
  "postUrl": "",
  "postText": "帖子文字或 OCR 结果",
  "screenshotImage": "data:image/png;base64,...",
  "preference": {
    "travelDate": "2026-06-17",
    "startDate": "2026-06-17",
    "endDate": "2026-06-20",
    "startTime": "09:30",
    "peopleCount": 2,
    "purpose": "relaxed",
    "attractionPreference": "吃吃喝喝|经典必玩",
    "hotelPreference": "市中心或地铁附近"
  }
}
```

### `POST /api/travel-plan/replan`

Locally replans the remaining trip based on weather, current time, and location.
This is intended for cases such as sudden rain, heat, wind, or other weather changes.

Request shape:

```json
{
  "plan": { "preference": {}, "places": [], "timeline": [] },
  "currentTime": "2026-06-17T14:20:00+08:00",
  "currentLocation": {
    "latitude": 30.25,
    "longitude": 120.16
  },
  "weather": {
    "condition": "rain",
    "rainProbability": 0.82,
    "nextHours": 4
  },
  "reason": "rain"
}
```

Both endpoints return the existing app-compatible travel plan shape:

```json
{
  "preference": {},
  "places": [],
  "timeline": [],
  "region": {},
  "summary": "",
  "providerTaskId": "",
  "model": "gemini-2.5-flash"
}
```

The backend validates dates, people count, supported categories, place IDs,
coordinates, and timeline references before returning data to the app.

## Collaboration endpoints

The mobile client uses these endpoints to share a plan between devices while this
server process is running:

- `POST /api/collaboration/sessions` creates or loads a session from `{ plan, ownerName }`.
- `GET /api/collaboration/sessions/:code` loads the latest plan and members.
- `POST /api/collaboration/sessions/:code/members` joins or adds a member.
- `PUT /api/collaboration/sessions/:code/plan` saves `{ plan, revision, editorName }`.
- `PUT /api/collaboration/sessions/:code/members/:memberId` changes a member's `edit` or `view` permission.

Sessions are intentionally in-memory for local development. Plan saves require the
latest revision; stale updates receive HTTP 409 rather than overwriting newer work.
