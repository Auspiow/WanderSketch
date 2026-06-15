import { MapViewport, SelectedRegion } from '../model/Types'

export interface RegionSelectorRatio {
  widthRatio: number
  heightRatio: number
  centerYOffsetRatio: number
}

export class MapRegionService {
  static viewportToSelectedRegion(viewport: MapViewport, ratio: RegionSelectorRatio): SelectedRegion {
    const latSpan: number = viewport.northLat - viewport.southLat
    const lngSpan: number = viewport.eastLng - viewport.westLng
    const selectedLatSpan: number = latSpan * ratio.heightRatio
    const selectedLngSpan: number = lngSpan * ratio.widthRatio
    const centerLat: number = (viewport.northLat + viewport.southLat) / 2 - latSpan * ratio.centerYOffsetRatio
    const centerLng: number = (viewport.eastLng + viewport.westLng) / 2

    const region: SelectedRegion = {
      north: centerLat + selectedLatSpan / 2,
      south: centerLat - selectedLatSpan / 2,
      east: centerLng + selectedLngSpan / 2,
      west: centerLng - selectedLngSpan / 2,
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: viewport.zoomLevel,
    }
    return region
  }
}
