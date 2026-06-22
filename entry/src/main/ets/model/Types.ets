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
