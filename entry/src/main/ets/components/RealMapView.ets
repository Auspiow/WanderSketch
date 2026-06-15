import { MapComponent, mapCommon, map } from '@kit.MapKit'
import { image } from '@kit.ImageKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { DEFAULT_MAP_CENTER, MapViewport } from '../model/Types'

@Component
export struct RealMapView {
  onViewportChanged: (viewport: MapViewport) => void = () => {}
  onSnapshotReady: (captureFn: () => Promise<string>) => void = () => {}

  private mapController?: map.MapComponentController
  @State private mapLoaded: boolean = false

  private onMapLoaded(err: BusinessError, controller: map.MapComponentController) {
    if (err) {
      console.error(`Map load error: ${err.message}`)
      return
    }

    this.mapController = controller
    this.mapLoaded = true
    this.onSnapshotReady(() => {
      return this.captureSnapshot()
    })

    try {
      controller.on('cameraIdle', () => {
        this.reportViewport()
      })
    } catch (e) {
      const error = e as BusinessError
      console.warn(`Failed to register cameraIdle: ${error.message}`)
    }

    this.reportViewport()
  }

  private reportViewport() {
    const controller: map.MapComponentController | undefined = this.mapController
    if (!controller) {
      return
    }

    try {
      const cameraPos: mapCommon.CameraPosition = controller.getCameraPosition()
      const projection: map.Projection = controller.getProjection()
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
      const error = e as BusinessError
      console.warn(`Failed to get viewport: ${error.message}`)
    }
  }

  private async captureSnapshot(): Promise<string> {
    const controller: map.MapComponentController | undefined = this.mapController
    if (!controller || !this.mapLoaded) {
      return ''
    }

    try {
      const pixelMap: image.PixelMap = await controller.snapshot()
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpts: image.PackingOption = {
        format: 'image/png',
        quality: 100,
      }
      const buffer: ArrayBuffer = await packer.packToData(pixelMap, packOpts)
      const helper: util.Base64Helper = new util.Base64Helper()
      const base64: string = helper.encodeToStringSync(new Uint8Array(buffer))

      packer.release()
      pixelMap.release()
      return base64
    } catch (e) {
      const error = e as BusinessError
      console.error(`Snapshot failed: ${error.message}`)
      return ''
    }
  }

  build() {
    MapComponent({
      mapOptions: {
        position: {
          target: {
            latitude: (DEFAULT_MAP_CENTER.northLat + DEFAULT_MAP_CENTER.southLat) / 2,
            longitude: (DEFAULT_MAP_CENTER.eastLng + DEFAULT_MAP_CENTER.westLng) / 2,
          },
          zoom: DEFAULT_MAP_CENTER.zoomLevel,
        },
        mapType: mapCommon.MapType.STANDARD,
      } as mapCommon.MapOptions,
      mapCallback: (err: BusinessError, controller: map.MapComponentController) => {
        this.onMapLoaded(err, controller)
      },
    })
      .width('100%')
      .height('100%')
  }
}
