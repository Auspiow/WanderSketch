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
