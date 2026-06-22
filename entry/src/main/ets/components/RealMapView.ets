import { webview } from '@kit.ArkWeb'
import { DEFAULT_SELECTED_REGION, MapViewport, SelectedRegion, TravelDayPlan, TravelTimelineItem } from '../model/Types'
import { GoogleMapService, GoogleStaticMapRequest } from '../services/GoogleMapService'

class PlaceSelectionBridge {
  private callback: (placeId: string) => void = () => {}

  setCallback(callback: (placeId: string) => void): void {
    this.callback = callback
  }

  selectPlace(placeId: string): void {
    this.callback(placeId)
  }
}

@Component
export struct RealMapView {
  @Prop initialRegion: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []
  @Prop dayItems: TravelDayPlan[] = []
  @Prop showRoute: boolean = false
  onViewportChanged: (viewport: MapViewport) => void = () => {}
  onSnapshotReady: (captureFn: () => Promise<string>) => void = () => {}
  onPlaceSelected: (placeId: string) => void = () => {}

  private webController: webview.WebviewController = new webview.WebviewController()
  private placeSelectionBridge: PlaceSelectionBridge = new PlaceSelectionBridge()

  aboutToAppear() {
    this.placeSelectionBridge.setCallback((placeId: string) => {
      this.onPlaceSelected(placeId)
    })
    this.onSnapshotReady(() => {
      return this.captureSnapshot()
    })
    this.reportViewport()
  }

  private reportViewport() {
    this.onViewportChanged(GoogleMapService.regionToViewport(this.initialRegion))
  }

  private async captureSnapshot(): Promise<string> {
    const request: GoogleStaticMapRequest = {
      region: this.initialRegion,
      width: 640,
      height: 420,
      scale: 2,
      items: this.items,
    }
    return GoogleMapService.fetchStaticMapBase64(request)
  }

  private mapSource(): string {
    if (this.showRoute) {
      if (this.dayItems.length > 0) {
        return GoogleMapService.buildInteractiveDayMapUrl(this.initialRegion, this.dayItems)
      }
      return GoogleMapService.buildInteractiveMapUrl(this.initialRegion, this.items)
    }
    return GoogleMapService.buildExplorePoiMapUrl(this.initialRegion)
  }

  build() {
    Web({
      src: this.mapSource(),
      controller: this.webController,
    })
      .javaScriptAccess(true)
      .javaScriptProxy({
        object: this.placeSelectionBridge,
        name: 'WanderSketchMap',
        methodList: ['selectPlace'],
        controller: this.webController,
      })
      .domStorageAccess(true)
      .zoomAccess(true)
      .onPageEnd(() => {
        this.reportViewport()
      })
      .width('100%')
      .height('100%')
  }
}
