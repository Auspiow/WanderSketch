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
