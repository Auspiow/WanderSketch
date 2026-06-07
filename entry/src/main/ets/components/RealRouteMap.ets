import { DEFAULT_SELECTED_REGION, MapViewport, SelectedRegion, TravelTimelineItem } from '../model/Types'
import { RealMapView } from './RealMapView'
import { RouteOverlay } from './RouteOverlay'

@Component
export struct RealRouteMap {
  @Prop initialRegion: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []
  @State viewportRegion: SelectedRegion = DEFAULT_SELECTED_REGION

  aboutToAppear() {
    this.viewportRegion = this.initialRegion
  }

  private viewportToRegion(viewport: MapViewport): SelectedRegion {
    const region: SelectedRegion = {
      north: viewport.northLat,
      south: viewport.southLat,
      east: viewport.eastLng,
      west: viewport.westLng,
      centerLat: (viewport.northLat + viewport.southLat) / 2,
      centerLng: (viewport.eastLng + viewport.westLng) / 2,
      zoom: viewport.zoomLevel,
    }
    return region
  }

  build() {
    Stack() {
      RealMapView({
        initialRegion: this.initialRegion,
        onViewportChanged: (viewport: MapViewport) => {
          this.viewportRegion = this.viewportToRegion(viewport)
        },
      })

      RouteOverlay({
        region: this.viewportRegion,
        items: this.items,
      })
    }
    .width('100%')
    .height(420)
    .clip(true)
    .borderRadius(22)
  }
}
