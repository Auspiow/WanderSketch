import {
  CommuteInfo,
  DEFAULT_SELECTED_REGION,
  SelectedRegion,
  TravelPlace,
  TravelPlan,
  TravelPreference,
  TravelTimelineItem,
} from '../model/Types'

interface PlaceHit {
  place: TravelPlace
  index: number
}

const KNOWN_PLACES: TravelPlace[] = [
  {
    id: 'forbidden-city',
    name: '故宫博物院',
    category: 'museum',
    address: '北京市东城区景山前街4号',
    latitude: 39.9163,
    longitude: 116.3972,
    openingHours: '08:30-17:00',
    recommendedDurationMinutes: 150,
    note: '适合安排在上午，参观动线较长。',
  },
  {
    id: 'jingshan',
    name: '景山公园',
    category: 'landmark',
    address: '北京市西城区景山西街44号',
    latitude: 39.9251,
    longitude: 116.3965,
    openingHours: '06:30-21:00',
    recommendedDurationMinutes: 60,
    note: '可以俯瞰中轴线，适合作为故宫后的短停留。',
  },
  {
    id: 'nanluoguxiang',
    name: '南锣鼓巷',
    category: 'shopping',
    address: '北京市东城区南锣鼓巷',
    latitude: 39.9372,
    longitude: 116.4037,
    openingHours: '10:00-22:00',
    recommendedDurationMinutes: 90,
    note: '街区店铺密集，适合下午慢逛。',
  },
  {
    id: 'siji-minfu',
    name: '四季民福烤鸭店',
    category: 'restaurant',
    address: '北京市东城区灯市口西街32号',
    latitude: 39.9168,
    longitude: 116.4112,
    openingHours: '10:30-21:30',
    recommendedDurationMinutes: 90,
    note: '热门餐厅建议提前取号或预订。',
  },
  {
    id: 'page-one',
    name: 'PAGEONE书店',
    category: 'cafe',
    address: '北京市前门北京坊东区E11号楼',
    latitude: 39.8996,
    longitude: 116.3978,
    openingHours: '10:00-22:00',
    recommendedDurationMinutes: 60,
    note: '适合补充咖啡和拍照，临近前门商圈。',
  },
  {
    id: 'qianmen',
    name: '前门大街',
    category: 'landmark',
    address: '北京市东城区前门大街',
    latitude: 39.8993,
    longitude: 116.3970,
    openingHours: '全天开放',
    recommendedDurationMinutes: 75,
    note: '街区开放时间灵活，适合作为收尾。',
  },
]

export class TravelPlanService {
  static buildPlan(preference: TravelPreference): TravelPlan {
    const places: TravelPlace[] = TravelPlanService.extractPlaces(preference.sharedPostText)
    const region: SelectedRegion = TravelPlanService.calculateRegion(places)
    const timeline: TravelTimelineItem[] = TravelPlanService.buildTimeline(places, preference.startTime)
    const summary: string = `${preference.travelDate} · ${preference.peopleCount}人 · ${places.length}个地点`
    const plan: TravelPlan = {
      preference: preference,
      places: places,
      timeline: timeline,
      region: region,
      summary: summary,
    }
    return plan
  }

  private static extractPlaces(postText: string): TravelPlace[] {
    const normalized: string = postText.toLowerCase()
    let hits: PlaceHit[] = []
    for (let i = 0; i < KNOWN_PLACES.length; i++) {
      const place: TravelPlace = KNOWN_PLACES[i]
      const nameIndex: number = normalized.indexOf(place.name.toLowerCase())
      const noteIndex: number = normalized.indexOf(place.note.toLowerCase())
      let hitIndex: number = nameIndex
      if (hitIndex < 0 && noteIndex >= 0) {
        hitIndex = noteIndex
      }
      if (hitIndex >= 0) {
        hits.push({
          place: place,
          index: hitIndex,
        })
      }
    }

    if (hits.length < 2) {
      hits = [
        { place: KNOWN_PLACES[0], index: 0 },
        { place: KNOWN_PLACES[3], index: 1 },
        { place: KNOWN_PLACES[2], index: 2 },
        { place: KNOWN_PLACES[5], index: 3 },
      ]
    }

    hits.sort((a: PlaceHit, b: PlaceHit): number => {
      return a.index - b.index
    })

    let places: TravelPlace[] = []
    for (let i = 0; i < hits.length; i++) {
      places.push(hits[i].place)
    }
    return places
  }

  private static buildTimeline(places: TravelPlace[], startTime: string): TravelTimelineItem[] {
    let items: TravelTimelineItem[] = []
    let cursorMinutes: number = TravelPlanService.timeToMinutes(startTime)

    for (let i = 0; i < places.length; i++) {
      const place: TravelPlace = places[i]
      let commute: CommuteInfo | undefined = undefined
      if (i > 0) {
        commute = TravelPlanService.calculateCommute(places[i - 1], place)
        cursorMinutes += commute.durationMinutes
      }

      const arriveTime: string = TravelPlanService.minutesToTime(cursorMinutes)
      cursorMinutes += place.recommendedDurationMinutes
      const leaveTime: string = TravelPlanService.minutesToTime(cursorMinutes)
      const item: TravelTimelineItem = {
        place: place,
        arriveTime: arriveTime,
        leaveTime: leaveTime,
        commuteFromPrevious: commute,
        openStatus: TravelPlanService.getOpenStatus(place.openingHours, arriveTime),
      }
      items.push(item)
    }
    return items
  }

  private static calculateCommute(from: TravelPlace, to: TravelPlace): CommuteInfo {
    const distanceKm: number = TravelPlanService.distanceKm(from.latitude, from.longitude, to.latitude, to.longitude)
    const durationMinutes: number = Math.max(8, Math.round(distanceKm / 18 * 60) + 6)
    const commute: CommuteInfo = {
      fromPlaceId: from.id,
      toPlaceId: to.id,
      distanceKm: Math.round(distanceKm * 10) / 10,
      durationMinutes: durationMinutes,
      transport: distanceKm < 1.2 ? '步行' : '打车/公交',
    }
    return commute
  }

  private static calculateRegion(places: TravelPlace[]): SelectedRegion {
    if (places.length === 0) {
      return DEFAULT_SELECTED_REGION
    }

    let north: number = places[0].latitude
    let south: number = places[0].latitude
    let east: number = places[0].longitude
    let west: number = places[0].longitude
    for (let i = 1; i < places.length; i++) {
      const place: TravelPlace = places[i]
      north = Math.max(north, place.latitude)
      south = Math.min(south, place.latitude)
      east = Math.max(east, place.longitude)
      west = Math.min(west, place.longitude)
    }

    const latPadding: number = Math.max((north - south) * 0.28, 0.006)
    const lngPadding: number = Math.max((east - west) * 0.28, 0.008)
    const region: SelectedRegion = {
      north: north + latPadding,
      south: south - latPadding,
      east: east + lngPadding,
      west: west - lngPadding,
      centerLat: (north + south) / 2,
      centerLng: (east + west) / 2,
      zoom: places.length > 3 ? 13 : 14,
    }
    return region
  }

  private static distanceKm(fromLat: number, fromLng: number, toLat: number, toLng: number): number {
    const radiusKm: number = 6371
    const dLat: number = TravelPlanService.toRadians(toLat - fromLat)
    const dLng: number = TravelPlanService.toRadians(toLng - fromLng)
    const lat1: number = TravelPlanService.toRadians(fromLat)
    const lat2: number = TravelPlanService.toRadians(toLat)
    const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
    const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return radiusKm * c
  }

  private static toRadians(degrees: number): number {
    return degrees * Math.PI / 180
  }

  private static timeToMinutes(value: string): number {
    const parts: string[] = value.split(':')
    if (parts.length < 2) {
      return 9 * 60
    }
    const hour: number = Number(parts[0])
    const minute: number = Number(parts[1])
    if (TravelPlanService.isInvalidNumber(hour) || TravelPlanService.isInvalidNumber(minute)) {
      return 9 * 60
    }
    return hour * 60 + minute
  }

  private static isInvalidNumber(value: number): boolean {
    return value !== value
  }

  private static minutesToTime(value: number): string {
    const minutesInDay: number = 24 * 60
    const normalized: number = ((value % minutesInDay) + minutesInDay) % minutesInDay
    const hour: number = Math.floor(normalized / 60)
    const minute: number = normalized % 60
    const hourText: string = hour < 10 ? `0${hour}` : `${hour}`
    const minuteText: string = minute < 10 ? `0${minute}` : `${minute}`
    return `${hourText}:${minuteText}`
  }

  private static getOpenStatus(openingHours: string, arriveTime: string): string {
    if (openingHours === '全天开放') {
      return '营业中'
    }
    const range: string[] = openingHours.split('-')
    if (range.length < 2) {
      return '需确认'
    }
    const arrive: number = TravelPlanService.timeToMinutes(arriveTime)
    const open: number = TravelPlanService.timeToMinutes(range[0])
    const close: number = TravelPlanService.timeToMinutes(range[1])
    if (arrive >= open && arrive <= close) {
      return '营业中'
    }
    return '可能未营业'
  }
}
