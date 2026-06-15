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

export interface AppColors {
  PRIMARY: string
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
