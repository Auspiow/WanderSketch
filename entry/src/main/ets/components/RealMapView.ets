/**
 * AI Fantasy Cartographer - RealMapView Component
 *
 * Wraps HarmonyOS Map Kit MapComponent to display a real interactive map
 * with POI markers, tap-to-pin, and screenshot capture for AI processing.
 *
 * Requires:
 *   - agconnect-services.json in AppScope/ (Map Kit auto-reads API key)
 *   - Permissions: INTERNET, APPROXIMATELY_LOCATION, LOCATION
 */

import { MapComponent, mapCommon, map } from '@kit.MapKit'
import { image } from '@kit.ImageKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  POI,
  MapViewport,
  APP_COLORS,
  PIN_COLORS,
  DEFAULT_MAP_CENTER,
} from '../model/Types'

@Component
export struct RealMapView {
  // POIs to render as markers on the map
  @Watch('onPoisChanged')
  @Prop pois: POI[] = []

  // Callback when user taps the map to add a new POI
  onMapTap: (latitude: number, longitude: number) => void = () => {}

  // Callback when viewport changes (camera idle)
  onViewportChanged: (viewport: MapViewport) => void = () => {}

  // Callback: parent stores this to trigger screenshot later
  onSnapshotReady: (captureFn: () => Promise<string>) => void = () => {}

  // Map controller — set by MapComponent callback
  private mapController?: map.MapComponentController
  // Track Marker objects so we can remove/update them via marker.remove()
  private markers: map.Marker[] = []
  // Whether the map has finished loading
  @State private mapLoaded: boolean = false

  // ============ POI Marker Sync ============

  onPoisChanged() {
    if (!this.mapLoaded || !this.mapController) {
      return
    }
    this.syncMarkers()
  }

  /** Remove all existing markers and re-add current POIs */
  private async syncMarkers() {
    if (!this.mapController) return

    // Remove all existing markers using Marker.remove()
    for (const marker of this.markers) {
      try {
        marker.remove()
      } catch (_e) {
        // Marker might already be removed
      }
    }
    this.markers = []

    // Add markers for each POI
    for (let i = 0; i < this.pois.length; i++) {
      const poi: POI = this.pois[i]
      try {
        const markerOptions: mapCommon.MarkerOptions = {
          position: {
            latitude: poi.latitude,
            longitude: poi.longitude,
          },
          title: poi.name,
          anchorU: 0.5,
          anchorV: 1.0,
        }
        const marker: map.Marker = await this.mapController.addMarker(markerOptions)
        this.markers.push(marker)
      } catch (e) {
        const err = e as BusinessError
        console.warn(`Failed to add marker for POI ${poi.id}: ${err.message}`)
      }
    }
  }

  // ============ Map Callbacks ============

  private onMapLoaded(err: BusinessError, controller: map.MapComponentController) {
    if (err) {
      console.error(`Map load error: ${err.message}`)
      return
    }
    this.mapController = controller
    this.mapLoaded = true

    // Register the snapshot function with the parent
    this.onSnapshotReady(() => {
      return this.captureSnapshot()
    })

    // Set up map click listener for adding POIs
    try {
      this.mapController.on('mapClick', (latLng: mapCommon.LatLng) => {
        this.onMapTap(latLng.latitude, latLng.longitude)
      })
    } catch (e) {
      const err = e as BusinessError
      console.warn(`Failed to register mapClick: ${err.message}`)
    }

    // Set up camera idle listener for viewport tracking
    try {
      this.mapController.on('cameraIdle', () => {
        this.reportViewport()
      })
    } catch (e) {
      const err = e as BusinessError
      console.warn(`Failed to register cameraIdle: ${err.message}`)
    }

    // Sync any POIs that were added before map loaded
    this.syncMarkers()

    // Report initial viewport
    this.reportViewport()
  }

  /** Report the current viewport to the parent */
  private reportViewport() {
    if (!this.mapController) return
    try {
      const cameraPos: mapCommon.CameraPosition = this.mapController.getCameraPosition()
      const projection: map.Projection = this.mapController.getProjection()
      const visibleRegion: mapCommon.VisibleRegion = projection.getVisibleRegion()
      const viewport: MapViewport = {
        northLat: visibleRegion.bounds.northeast.latitude,
        southLat: visibleRegion.bounds.southwest.latitude,
        eastLng: visibleRegion.bounds.northeast.longitude,
        westLng: visibleRegion.bounds.southwest.longitude,
        zoomLevel: cameraPos.zoom,
      }
      this.onViewportChanged(viewport)
    } catch (e) {
      const err = e as BusinessError
      console.warn(`Failed to get viewport: ${err.message}`)
    }
  }

  // ============ Public API ============

  /**
   * Capture the current map viewport as a Base64 PNG string.
   * Registered with parent via onSnapshotReady callback.
   *
   * Flow: Map Kit snapshot() → PixelMap → ImagePacker → ArrayBuffer → Base64
   */
  private async captureSnapshot(): Promise<string> {
    if (!this.mapController || !this.mapLoaded) {
      return ''
    }
    try {
      // 1. Take snapshot — returns Promise<PixelMap>
      const pixelMap: image.PixelMap = await this.mapController.snapshot()

      // 2. Create ImagePacker and pack PixelMap → PNG ArrayBuffer
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpts: image.PackingOption = {
        format: 'image/png',
        quality: 100,
      }
      const buffer: ArrayBuffer = await packer.packToData(pixelMap, packOpts)

      // 3. Convert ArrayBuffer → Base64 string
      const helper: util.Base64Helper = new util.Base64Helper()
      const bytes: Uint8Array = new Uint8Array(buffer)
      const base64: string = helper.encodeToStringSync(bytes)

      // 4. Release resources
      packer.release()
      pixelMap.release()

      return base64
    } catch (e) {
      const err = e as BusinessError
      console.error(`Snapshot failed: ${err.message}`)
      return ''
    }
  }

  /** Get the current viewport bounds */
  getViewport(): MapViewport {
    if (!this.mapController) {
      return DEFAULT_MAP_CENTER
    }
    try {
      const cameraPos: mapCommon.CameraPosition = this.mapController.getCameraPosition()
      const projection: map.Projection = this.mapController.getProjection()
      const visibleRegion: mapCommon.VisibleRegion = projection.getVisibleRegion()
      const viewport: MapViewport = {
        northLat: visibleRegion.bounds.northeast.latitude,
        southLat: visibleRegion.bounds.southwest.latitude,
        eastLng: visibleRegion.bounds.northeast.longitude,
        westLng: visibleRegion.bounds.southwest.longitude,
        zoomLevel: cameraPos.zoom,
      }
      return viewport
    } catch (_e) {
      return DEFAULT_MAP_CENTER
    }
  }

  // ============ Build ============

  build() {
    Stack() {
      // Map Kit component — center on Beijing by default
      MapComponent({
        mapOptions: {
          position: {
            target: {
              latitude: 39.9042,
              longitude: 116.4074,
            },
            zoom: 12,
          },
          mapType: mapCommon.MapType.STANDARD,
        } as mapCommon.MapOptions,
        mapCallback: (err: BusinessError, controller: map.MapComponentController) => {
          this.onMapLoaded(err, controller)
        }
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
