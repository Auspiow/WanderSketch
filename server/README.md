# VisMap Sketch Proxy

This local backend keeps the SiliconFlow API key out of the HarmonyOS client.

## Run

```powershell
Copy-Item server\.env.example server\.env
# Edit server\.env and set SILICONFLOW_API_KEY
node server\src\index.js
```

Health check:

```powershell
curl.exe http://127.0.0.1:3000/health
```

HarmonyOS client endpoint:

```text
http://<your-computer-lan-ip>:3000/api/sketch-map
```

Use your computer LAN IP when testing on a physical phone. `127.0.0.1` on the phone points to the phone itself, not this backend.

## Travel plan endpoint

`/api/travel-plan` accepts a Xiaohongshu link, pasted post text, or a screenshot
base64 image and returns a structured travel plan. It uses the same
`SILICONFLOW_API_KEY` as sketch generation, but calls the chat/completions API
with a factual vision-language model:

```text
SILICONFLOW_CHAT_MODEL=Qwen/Qwen2.5-VL-72B-Instruct
SILICONFLOW_CHAT_ENDPOINT=https://api.siliconflow.cn/v1/chat/completions
```

Example:

```powershell
$body = @{
  postUrl = "https://www.xiaohongshu.com/explore/..."
  postText = "上午去故宫，午餐四季民福，下午南锣鼓巷，晚上前门"
  screenshotImage = ""
  preference = @{
    travelDate = "2026-06-10"
    startDate = "2026-06-10"
    endDate = "2026-06-12"
    startTime = "09:30"
    peopleCount = 2
    purpose = "parent_child"
    attractionPreference = "历史文化、轻松步行、适合拍照"
    hotelPreference = "地铁附近，不频繁换酒店"
  }
} | ConvertTo-Json -Depth 6

curl.exe -X POST http://127.0.0.1:3000/api/travel-plan `
  -H "Content-Type: application/json" `
  -d $body
```

The backend prompt requires strict JSON and forbids fabricating unsupported
places. If a link cannot be fetched because Xiaohongshu blocks anonymous access,
the model still uses the pasted text and screenshot. When only an inaccessible
link is provided, the response should contain low confidence and warnings rather
than invented itinerary data.

The backend also applies deterministic supervision after the model response. It
does not rely on the model to self-check the final data. The rule layer validates
date range, start time, people count, supported purpose values, place categories,
coordinates, timeline place IDs, time ranges, commute ranges, and source-text
evidence when textual evidence is available. It overwrites returned preference
fields with the request values and recalculates the map region from supervised
coordinates.

## Sketch timeout tuning

`/health` only verifies that the local proxy is alive. Image generation can still
timeout while waiting for SiliconFlow or while downloading the generated image.

The proxy logs each `/api/sketch-map` request with these stages:

```text
[sketch:<id>] received request bytes=...
[sketch:<id>] upstream start ...
[sketch:<id>] upstream response ...
[sketch:<id>] downloaded generated image ...
```

If generation is still too slow, lower these values in `server/.env`:

```text
SKETCH_IMAGE_SIZE=768x768
SKETCH_INFERENCE_STEPS=18
SKETCH_GUIDANCE_SCALE=7
UPSTREAM_TIMEOUT_MS=360000
```

The HarmonyOS client read timeout is set to 420 seconds, so keep
`UPSTREAM_TIMEOUT_MS` below that unless the client timeout is also raised.
