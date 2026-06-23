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

export type TripViewMode = 'timeline' | 'real' | 'sketch'

export type TravelPlaceCategory = 'restaurant' | 'landmark' | 'shopping' | 'museum' | 'cafe'

export type TravelPurpose = 'parent_child' | 'family' | 'fast_paced' | 'relaxed' | 'foodie' | 'photo'

export interface TravelPreference {
  travelDate: string
  startDate: string
  endDate: string
  startTime: string
  peopleCount: number
  purpose: TravelPurpose
  travelPace: string
  foodPreference: string
  attractionPreference: string
  hotelPreference: string
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

export interface TravelMeal {
  restaurantName: string
  recommendation: string
  estimatedCost: number
}

export interface TravelDayMealPlan {
  date: string
  breakfast: TravelMeal
  lunch: TravelMeal
  dinner: TravelMeal
  dayBudget: number
}

export interface TravelDayPlan {
  id: string
  date: string
  dateLabel: string
  weekday: string
  title: string
  summary: string
  distanceKm: number
  items: TravelTimelineItem[]
  mealPlan?: TravelDayMealPlan
}

export interface TravelPlan {
  id: string
  title: string
  preference: TravelPreference
  places: TravelPlace[]
  timeline: TravelTimelineItem[]
  days: TravelDayPlan[]
  region: SelectedRegion
  summary: string
  providerTaskId: string
  model: string
  totalBudget?: number
}

export interface TravelPosterPlace {
  id: string
  name: string
  imageUrl: string
  description: string
  attribution: string
}

export type TravelMealPeriod = 'breakfast' | 'lunch' | 'dinner'

export interface TravelPosterMeal {
  id: string
  period: TravelMealPeriod
  label: string
  restaurantName: string
  imageUrl: string
  recommendation: string
  estimatedCost: number
  attribution: string
}

export interface TravelPosterMealDay {
  id: string
  dateLabel: string
  meals: TravelPosterMeal[]
}

export interface TravelPosterDay {
  id: string
  dateLabel: string
  meals: TravelPosterMeal[]
  places: TravelPosterPlace[]
}

export interface WeatherSnapshot {
  locationName: string
  condition: string
  description: string
  temperatureC: number
  humidity: number
  windSpeed: number
  rainMm: number
  fetchedAt: string
  severity: number
}

export interface AppColors {
  PRIMARY: string
  PRIMARY_ACTIVE: string
  ACCENT: string
  ACCENT_SOFT: string
  SUCCESS: string
  SUCCESS_SOFT: string
  WARNING: string
  WARNING_SOFT: string
  DANGER: string
  DANGER_SOFT: string
  INFO: string
  INFO_SOFT: string
  SURFACE: string
  SURFACE_MUTED: string
  SURFACE_SUBTLE: string
  BACKGROUND: string
  CARD: string
  WHITE: string
  TEXT_PRIMARY: string
  TEXT_SECONDARY: string
  TEXT_TERTIARY: string
  TEXT_ON_PRIMARY: string
  TEXT_ON_DARK: string
  BORDER: string
  OVERLAY: string
  DARK_SURFACE: string
  PIN_RED: string
  GENERATING_BG: string
  PARCHMENT: string
  SHADOW_MEDIUM: string
}

export const APP_COLORS: AppColors = {
  PRIMARY: '#176B68',
  PRIMARY_ACTIVE: '#105653',
  ACCENT: '#C98245',
  ACCENT_SOFT: '#DCEFED',
  SUCCESS: '#2F855A',
  SUCCESS_SOFT: '#E0F2E8',
  WARNING: '#B7791F',
  WARNING_SOFT: '#F9ECD8',
  DANGER: '#C85B58',
  DANGER_SOFT: '#F9E4E2',
  INFO: '#477A9D',
  INFO_SOFT: '#E5EFF5',
  SURFACE: '#F7FBFA',
  SURFACE_MUTED: '#EDF4F3',
  SURFACE_SUBTLE: '#E4EFED',
  BACKGROUND: '#DDE9E6',
  CARD: '#FDFEFD',
  WHITE: '#FDFEFD',
  TEXT_PRIMARY: '#183837',
  TEXT_SECONDARY: '#5D7775',
  TEXT_TERTIARY: '#8AA09E',
  TEXT_ON_PRIMARY: '#F9FCFB',
  TEXT_ON_DARK: 'rgba(249,252,251,0.78)',
  BORDER: '#CDDEDA',
  OVERLAY: 'rgba(24,56,55,0.14)',
  DARK_SURFACE: '#183837',
  PIN_RED: '#C85B58',
  GENERATING_BG: '#6E9B97',
  PARCHMENT: '#F4E5D0',
  SHADOW_MEDIUM: 'rgba(24, 56, 55, 0.15)',
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
