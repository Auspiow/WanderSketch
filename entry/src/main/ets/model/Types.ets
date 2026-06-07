export interface MapViewport {
  northLat: number
  southLat: number
  eastLng: number
  westLng: number
  zoomLevel: number
}

export interface SelectedRegion {
  north: number
  south: number
  east: number
  west: number
  centerLat: number
  centerLng: number
  zoom: number
}

export type SketchStyle = 'pencil' | 'watercolor' | 'ink' | 'vintage'

export interface SketchGenerateRequest {
  region: SelectedRegion
  style: SketchStyle
  keepLabels: boolean
  baseMapImage: string
}

export interface SketchGenerateResult {
  imageBase64: string
  mimeType: string
  providerTaskId: string
}

export type TripViewMode = 'timeline' | 'sketch'

export type TravelPlaceCategory = 'restaurant' | 'landmark' | 'shopping' | 'museum' | 'cafe'

export interface TravelPreference {
  travelDate: string
  startTime: string
  peopleCount: number
  sharedPostText: string
}

export interface TravelPlace {
  id: string
  name: string
  category: TravelPlaceCategory
  address: string
  latitude: number
  longitude: number
  openingHours: string
  recommendedDurationMinutes: number
  note: string
}

export interface CommuteInfo {
  fromPlaceId: string
  toPlaceId: string
  distanceKm: number
  durationMinutes: number
  transport: string
}

export interface TravelTimelineItem {
  place: TravelPlace
  arriveTime: string
  leaveTime: string
  commuteFromPrevious?: CommuteInfo
  openStatus: string
}

export interface TravelPlan {
  preference: TravelPreference
  places: TravelPlace[]
  timeline: TravelTimelineItem[]
  region: SelectedRegion
  summary: string
}

export interface AppColors {
  PRIMARY: string
  ACCENT: string
  ACCENT_SOFT: string
  SUCCESS: string
  WARNING: string
  SURFACE: string
  BACKGROUND: string
  CARD: string
  WHITE: string
  TEXT_PRIMARY: string
  TEXT_SECONDARY: string
  TEXT_ON_PRIMARY: string
  TEXT_ON_DARK: string
  PIN_RED: string
  GENERATING_BG: string
  PARCHMENT: string
  SHADOW_MEDIUM: string
}

export const APP_COLORS: AppColors = {
  PRIMARY: '#7A4726',
  ACCENT: '#237C7A',
  ACCENT_SOFT: '#E6F2F1',
  SUCCESS: '#2F855A',
  WARNING: '#B7791F',
  SURFACE: '#FFFFFF',
  BACKGROUND: '#FAF3E8',
  CARD: '#FFFDF7',
  WHITE: '#FFFFFF',
  TEXT_PRIMARY: '#2C1810',
  TEXT_SECONDARY: '#8B7355',
  TEXT_ON_PRIMARY: '#FFFFFF',
  TEXT_ON_DARK: 'rgba(255,255,255,0.78)',
  PIN_RED: '#E74C3C',
  GENERATING_BG: '#A08060',
  PARCHMENT: '#F5E6C8',
  SHADOW_MEDIUM: 'rgba(44, 24, 16, 0.15)',
}

export const DEFAULT_MAP_CENTER: MapViewport = {
  northLat: 39.9234,
  southLat: 39.8850,
  eastLng: 116.4474,
  westLng: 116.3674,
  zoomLevel: 12,
}

export const DEFAULT_SELECTED_REGION: SelectedRegion = {
  north: 39.9186,
  south: 39.8898,
  east: 116.4374,
  west: 116.3774,
  centerLat: 39.9042,
  centerLng: 116.4074,
  zoom: 12,
}
