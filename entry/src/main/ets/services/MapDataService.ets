import { SelectedRegion } from '../model/Types'

export interface StaticMapImageRequest {
  region: SelectedRegion
  width: number
  height: number
  scale: number
}

export class MapDataService {
  static buildStaticMapUrl(endpoint: string, request: StaticMapImageRequest): string {
    const region: SelectedRegion = request.region
    const bbox: string = `${region.west},${region.south},${region.east},${region.north}`
    return `${endpoint}?bbox=${bbox}&width=${request.width}&height=${request.height}&scale=${request.scale}`
  }

  static buildVectorDataRoute(region: SelectedRegion): string {
    return `/map/vector?west=${region.west}&south=${region.south}&east=${region.east}&north=${region.north}&zoom=${region.zoom}`
  }
}
