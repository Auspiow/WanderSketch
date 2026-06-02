/**
 * AI Fantasy Cartographer - Data Models & Constants
 *
 * ArkTS rule: arkts-no-untyped-obj-literals
 * Every object literal must correspond to an explicitly declared class or interface.
 */

// ============ Data Models ============

/** Point of Interest on the map (geographic coordinates) */
export interface POI {
  id: string
  name: string
  latitude: number    // Geographic latitude
  longitude: number   // Geographic longitude
  color: string       // Pin color
}

/** Geographic bounding box */
export interface BBox {
  north: number
  south: number
  east: number
  west: number
}

/** Current map viewport bounds */
export interface MapViewport {
  northLat: number
  southLat: number
  eastLng: number
  westLng: number
  zoomLevel: number
}

/** Theme color configuration */
export interface ThemeColors {
  primary: string
  secondary: string
  accent: string
  bg: string
  pin: string
}

/** API generate request payload (Phase 3) */
export interface GenerateRequest {
  base_image: string   // Base64 of the map screenshot with POI overlays
  theme: string        // Selected art style
  pois: POI[]          // Landmarks array
  bbox: BBox           // Map bounding box
}

// ============ Lineart Constants ============

/** Lineart color constants for B&W overlay markers */
export interface LineartColors {
  BG: string
  STROKE: string
}

export const LINEART_COLORS: LineartColors = {
  BG: '#FFFFFF',
  STROKE: '#000000',
}

// ============ App Color Palette ============

/** Application color palette — all color constants in one typed object */
export interface AppColors {
  // Primary palette
  PRIMARY: string
  PRIMARY_DARK: string
  PRIMARY_LIGHT: string

  // Surface
  SURFACE: string
  BACKGROUND: string
  CARD: string
  WHITE: string

  // Text
  TEXT_PRIMARY: string
  TEXT_SECONDARY: string
  TEXT_HINT: string
  TEXT_ON_PRIMARY: string
  TEXT_ON_DARK: string

  // Borders & dividers
  BORDER: string
  DIVIDER: string

  // Status
  PIN_RED: string
  PIN_BLUE: string
  PIN_GREEN: string
  PIN_GOLD: string
  PIN_PURPLE: string

  // Interactive
  DELETE_BG: string
  GENERATING_BG: string
  ICON_BG_DARK: string

  // Map elements
  WATER: string
  WATER_DARK: string
  GREEN: string
  ROAD: string
  ROAD_CENTER: string
  GRID: string
  PARCHMENT: string
  PARCHMENT_DARK: string

  // Shadows
  SHADOW_LIGHT: string
  SHADOW_MEDIUM: string
  SHADOW_STRONG: string
  SHADOW_PRIMARY: string
}

export const APP_COLORS: AppColors = {
  // Primary palette
  PRIMARY: '#6B4226',
  PRIMARY_DARK: '#4A2E1A',
  PRIMARY_LIGHT: '#8B6914',

  // Surface
  SURFACE: '#FFFFFF',
  BACKGROUND: '#FAF3E8',
  CARD: '#FFFDF7',
  WHITE: '#FFFFFF',

  // Text
  TEXT_PRIMARY: '#2C1810',
  TEXT_SECONDARY: '#8B7355',
  TEXT_HINT: '#B8A090',
  TEXT_ON_PRIMARY: '#FFFFFF',
  TEXT_ON_DARK: 'rgba(255,255,255,0.7)',

  // Borders & dividers
  BORDER: '#E0D5C8',
  DIVIDER: '#EDE5D8',

  // Status
  PIN_RED: '#E74C3C',
  PIN_BLUE: '#3498DB',
  PIN_GREEN: '#27AE60',
  PIN_GOLD: '#F39C12',
  PIN_PURPLE: '#9B59B6',

  // Interactive
  DELETE_BG: '#FDE8E8',
  GENERATING_BG: '#A08060',
  ICON_BG_DARK: 'rgba(255,255,255,0.15)',

  // Map elements
  WATER: '#7CB9D9',
  WATER_DARK: '#5A9BBF',
  GREEN: '#9CC084',
  ROAD: '#B8A090',
  ROAD_CENTER: '#D4C5B0',
  GRID: '#E8D5B8',
  PARCHMENT: '#F5E6C8',
  PARCHMENT_DARK: '#E8D5B8',

  // Shadows
  SHADOW_LIGHT: 'rgba(44, 24, 16, 0.08)',
  SHADOW_MEDIUM: 'rgba(44, 24, 16, 0.15)',
  SHADOW_STRONG: 'rgba(44, 24, 16, 0.25)',
  SHADOW_PRIMARY: 'rgba(107, 66, 38, 0.38)',
}

// ============ Theme Definitions ============

export const THEMES: string[] = ['Parchment', 'Watercolor', 'Cyberpunk']

export function getThemeColors(theme: string): ThemeColors {
  if (theme === 'Watercolor') {
    const colors: ThemeColors = {
      primary: '#2E5984',
      secondary: '#7BA3CC',
      accent: '#4A90D9',
      bg: '#E8F0F8',
      pin: '#3498DB'
    }
    return colors
  }
  if (theme === 'Cyberpunk') {
    const colors: ThemeColors = {
      primary: '#FF00FF',
      secondary: '#00FFFF',
      accent: '#FF0080',
      bg: '#1A0033',
      pin: '#00FFFF'
    }
    return colors
  }
  // Default: Parchment
  const colors: ThemeColors = {
    primary: '#6B4226',
    secondary: '#D4A574',
    accent: '#B8860B',
    bg: '#F5E6C8',
    pin: '#E74C3C'
  }
  return colors
}

// ============ Pin Colors Cycle ============

export const PIN_COLORS: string[] = [
  '#E74C3C',  // Red
  '#3498DB',  // Blue
  '#27AE60',  // Green
  '#F39C12',  // Gold
  '#9B59B6',  // Purple
  '#E67E22',  // Orange
  '#1ABC9C',  // Teal
  '#E91E63',  // Pink
]

// ============ Default Map Config ============

/** Default map center — Beijing Tiananmen */
export const DEFAULT_MAP_CENTER: MapViewport = {
  northLat: 39.9234,
  southLat: 39.8850,
  eastLng: 116.4474,
  westLng: 116.3674,
  zoomLevel: 12,
}
