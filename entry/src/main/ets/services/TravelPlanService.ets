import { http } from '@kit.NetworkKit'
import {
  CommuteInfo,
  SelectedRegion,
  TravelDayPlan,
  TravelDayMealPlan,
  TravelMeal,
  TravelPlace,
  TravelPlaceCategory,
  TravelPlan,
  TravelPreference,
  TravelPurpose,
  TravelTimelineItem,
  WeatherSnapshot,
} from '../model/Types'

const TRAVEL_PLAN_ENDPOINTS: string[] = [
  'http://10.196.35.142:3000/api/travel-plan',
  'http://10.0.2.2:3000/api/travel-plan',
  'http://127.0.0.1:3000/api/travel-plan',
]

const TRAVEL_REPLAN_ENDPOINTS: string[] = [
  'http://10.196.35.142:3000/api/travel-plan/replan',
  'http://10.0.2.2:3000/api/travel-plan/replan',
  'http://127.0.0.1:3000/api/travel-plan/replan',
]

interface TravelPlanGenerateInput {
  destinationName: string
  destinationAddress: string
  startDate: string
  endDate: string
  selectedPreferences: string
  foodPreference: string
  screenshotUri: string
}

interface TravelPlanRequestPreference {
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
}

interface TravelPlanRequestPayload {
  destinationName: string
  destinationAddress: string
  postUrl: string
  postText: string
  screenshotImage: string
  preference: TravelPlanRequestPreference
}

interface ApiTravelPlace {
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

interface ApiCommuteInfo {
  fromPlaceId: string
  toPlaceId: string
  distanceKm: number
  durationMinutes: number
  transport: string
}

interface ApiTimelineItem {
  placeId: string
  arriveTime: string
  leaveTime: string
  commuteFromPrevious?: ApiCommuteInfo
  openStatus: string
}

interface ApiTravelPreference {
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
}

interface ApiTravelPlanResponse {
  preference: ApiTravelPreference
  places: ApiTravelPlace[]
  timeline: ApiTimelineItem[]
  region: SelectedRegion
  summary: string
  dailyMeals?: ApiDayMealPlan[]
  totalBudget?: number
  providerTaskId?: string
  model?: string
}

interface ApiTravelMeal {
  restaurantName: string
  recommendation: string
  estimatedCost: number
}

interface ApiDayMealPlan {
  date: string
  breakfast: ApiTravelMeal
  lunch: ApiTravelMeal
  dinner: ApiTravelMeal
  dayBudget: number
}

interface TravelReplanLocation {
  latitude: number
  longitude: number
}

interface TravelReplanPayload {
  plan: TravelPlan
  currentTime: string
  currentLocation: TravelReplanLocation
  weather: WeatherSnapshot
  reason: string
}

export class TravelPlanService {
  static async generatePlan(input: TravelPlanGenerateInput): Promise<TravelPlan> {
    const preference: TravelPlanRequestPreference = {
      travelDate: input.startDate,
      startDate: input.startDate,
      endDate: input.endDate,
      startTime: '09:30',
      peopleCount: 2,
      purpose: TravelPlanService.resolvePurpose(input.selectedPreferences),
      travelPace: input.selectedPreferences.length > 0 ? input.selectedPreferences : '轻松慢游',
      foodPreference: input.foodPreference.length > 0 ? input.foodPreference : '当地特色',
      attractionPreference: input.selectedPreferences.length > 0 ? input.selectedPreferences : '轻松慢游',
      hotelPreference: `${TravelPlanService.resolveDestinationName(input)}市中心或地铁附近，不频繁换酒店`,
    }
    const payload: TravelPlanRequestPayload = {
      destinationName: TravelPlanService.resolveDestinationName(input),
      destinationAddress: input.destinationAddress,
      postUrl: '',
      postText: TravelPlanService.buildSeedPostText(input),
      screenshotImage: '',
      preference,
    }
    const requestBody: string = JSON.stringify(payload)

    const errors: string[] = []
    for (let i = 0; i < TRAVEL_PLAN_ENDPOINTS.length; i++) {
      const endpoint: string = TRAVEL_PLAN_ENDPOINTS[i]
      try {
        const apiPlan: ApiTravelPlanResponse = await TravelPlanService.requestPlan(endpoint, requestBody)
        return TravelPlanService.normalizeApiPlan(apiPlan, input)
      } catch (e) {
        const err = e as Error
        errors.push(`${endpoint}: ${err.message}`)
        console.error(`Travel plan endpoint failed: ${endpoint}, ${err.message}`)
      }
    }
    throw new Error(`所有大模型服务地址都连接失败：${errors.join('；')}`)
  }

  static async replanPlan(plan: TravelPlan, weather: WeatherSnapshot, reason: string): Promise<TravelPlan> {
    const payload: TravelReplanPayload = {
      plan,
      currentTime: new Date().toISOString(),
      currentLocation: {
        latitude: plan.region.centerLat,
        longitude: plan.region.centerLng,
      },
      weather,
      reason,
    }
    const requestBody: string = JSON.stringify(payload)
    const errors: string[] = []
    for (let i = 0; i < TRAVEL_REPLAN_ENDPOINTS.length; i++) {
      const endpoint: string = TRAVEL_REPLAN_ENDPOINTS[i]
      try {
        const apiPlan: ApiTravelPlanResponse = await TravelPlanService.requestPlan(endpoint, requestBody)
        const normalized: TravelPlan = TravelPlanService.normalizeApiPlan(apiPlan, {
          destinationName: plan.title,
          destinationAddress: '',
          startDate: plan.preference.startDate,
          endDate: plan.preference.endDate,
          selectedPreferences: plan.preference.travelPace,
          foodPreference: plan.preference.foodPreference,
          screenshotUri: '',
        })
        return {
          id: plan.id,
          title: plan.title,
          preference: normalized.preference,
          places: normalized.places,
          timeline: normalized.timeline,
          days: normalized.days,
          region: normalized.region,
          summary: normalized.summary,
          providerTaskId: normalized.providerTaskId,
          model: normalized.model,
          totalBudget: normalized.totalBudget,
        }
      } catch (e) {
        const err = e as Error
        errors.push(`${endpoint}: ${err.message}`)
        console.error(`Travel replan endpoint failed: ${endpoint}, ${err.message}`)
      }
    }
    throw new Error(`AI 实时调整失败：${errors.join('；')}`)
  }

  private static async requestPlan(endpoint: string, requestBody: string): Promise<ApiTravelPlanResponse> {
    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(endpoint, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
        },
        extraData: requestBody,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 420000,
      })
      const body: string = response.result as string
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}: ${body}`)
      }
      return JSON.parse(body) as ApiTravelPlanResponse
    } finally {
      httpRequest.destroy()
    }
  }

  static buildMockPlan(input: TravelPlanGenerateInput): TravelPlan {
    const destinationName: string = TravelPlanService.resolveDestinationName(input)
    const preference: TravelPreference = {
      travelDate: input.startDate,
      startDate: input.startDate,
      endDate: input.endDate,
      startTime: '09:30',
      peopleCount: 2,
      purpose: TravelPlanService.resolvePurpose(input.selectedPreferences),
      travelPace: input.selectedPreferences.length > 0 ? input.selectedPreferences : '轻松慢游',
      foodPreference: input.foodPreference.length > 0 ? input.foodPreference : '当地特色',
      attractionPreference: input.selectedPreferences.length > 0 ? input.selectedPreferences : '轻松慢游',
      hotelPreference: `${destinationName}市中心或地铁附近`,
      sharedPostText: TravelPlanService.buildSeedPostText(input),
    }
    const places: TravelPlace[] = TravelPlanService.buildMockPlaces()
    const rawDays: TravelDayPlan[] = TravelPlanService.buildMockDays(input, places)
    const days: TravelDayPlan[] = TravelPlanService.attachMealPlans(rawDays, TravelPlanService.buildMockMealPlans(input))
    const timeline: TravelTimelineItem[] = TravelPlanService.flattenDays(days)
    return {
      id: `plan-${Date.now()}`,
      title: `${destinationName}吃喝漫游${TravelPlanService.getDayCount(input.startDate, input.endDate)}天行程`,
      preference,
      places,
      timeline,
      days,
      region: {
        north: 30.3180,
        south: 30.2050,
        east: 120.2450,
        west: 120.0700,
        centerLat: 30.2570,
        centerLng: 120.1551,
        zoom: 12,
      },
      summary: '围绕西湖、湖滨、胜利河和钱江新城安排的轻松美食路线。',
      providerTaskId: 'mock-local',
      model: 'mock-data',
      totalBudget: TravelPlanService.sumMealBudgets(days),
    }
  }

  private static normalizeApiPlan(apiPlan: ApiTravelPlanResponse, input: TravelPlanGenerateInput): TravelPlan {
    const places: TravelPlace[] = []
    for (let i = 0; i < apiPlan.places.length; i++) {
      const place: ApiTravelPlace = apiPlan.places[i]
      places.push({
        id: place.id,
        name: place.name,
        category: place.category,
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
        openingHours: place.openingHours,
        recommendedDurationMinutes: place.recommendedDurationMinutes,
        note: place.note,
      })
    }

    const timeline: TravelTimelineItem[] = []
    for (let i = 0; i < apiPlan.timeline.length; i++) {
      const item: ApiTimelineItem = apiPlan.timeline[i]
      const place: TravelPlace | null = TravelPlanService.findPlace(places, item.placeId)
      if (place === null) {
        continue
      }
      let commute: CommuteInfo | undefined = undefined
      const apiCommute: ApiCommuteInfo | undefined = item.commuteFromPrevious
      if (apiCommute !== undefined) {
        commute = {
          fromPlaceId: apiCommute.fromPlaceId,
          toPlaceId: apiCommute.toPlaceId,
          distanceKm: apiCommute.distanceKm,
          durationMinutes: apiCommute.durationMinutes,
          transport: apiCommute.transport,
        }
      }
      timeline.push({
        place,
        arriveTime: item.arriveTime,
        leaveTime: item.leaveTime,
        commuteFromPrevious: commute,
        openStatus: item.openStatus,
      })
    }

    const preference: TravelPreference = {
      travelDate: apiPlan.preference.travelDate,
      startDate: apiPlan.preference.startDate,
      endDate: apiPlan.preference.endDate,
      startTime: apiPlan.preference.startTime,
      peopleCount: apiPlan.preference.peopleCount,
      purpose: apiPlan.preference.purpose,
      travelPace: apiPlan.preference.travelPace,
      foodPreference: apiPlan.preference.foodPreference,
      attractionPreference: apiPlan.preference.attractionPreference,
      hotelPreference: apiPlan.preference.hotelPreference,
      sharedPostText: TravelPlanService.buildSeedPostText(input),
    }
    const rawDays: TravelDayPlan[] = TravelPlanService.splitTimelineByDate(preference.startDate, preference.endDate, timeline)
    const days: TravelDayPlan[] = TravelPlanService.attachMealPlans(rawDays, apiPlan.dailyMeals)
    const destinationName: string = TravelPlanService.resolveDestinationName(input)
    return {
      id: `plan-${Date.now()}`,
      title: `${destinationName}智能旅行规划`,
      preference,
      places,
      timeline,
      days,
      region: apiPlan.region,
      summary: apiPlan.summary,
      providerTaskId: apiPlan.providerTaskId === undefined ? '' : apiPlan.providerTaskId,
      model: apiPlan.model === undefined ? '' : apiPlan.model,
      totalBudget: apiPlan.totalBudget === undefined ? TravelPlanService.sumMealBudgets(days) : apiPlan.totalBudget,
    }
  }

  private static attachMealPlans(days: TravelDayPlan[], apiMeals?: ApiDayMealPlan[]): TravelDayPlan[] {
    const result: TravelDayPlan[] = []
    const meals: ApiDayMealPlan[] = apiMeals === undefined ? [] : apiMeals
    for (let index: number = 0; index < days.length; index++) {
      const day: TravelDayPlan = days[index]
      let matched: ApiDayMealPlan | undefined = undefined
      for (let mealIndex: number = 0; mealIndex < meals.length; mealIndex++) {
        if (meals[mealIndex].date === day.date) {
          matched = meals[mealIndex]
          break
        }
      }
      if (matched === undefined) {
        result.push(day)
        continue
      }
      const mealPlan: TravelDayMealPlan = {
        date: matched.date,
        breakfast: TravelPlanService.toMeal(matched.breakfast),
        lunch: TravelPlanService.toMeal(matched.lunch),
        dinner: TravelPlanService.toMeal(matched.dinner),
        dayBudget: matched.dayBudget,
      }
      result.push({
        id: day.id,
        date: day.date,
        dateLabel: day.dateLabel,
        weekday: day.weekday,
        title: day.title,
        summary: day.summary,
        distanceKm: day.distanceKm,
        items: day.items,
        mealPlan,
      })
    }
    return result
  }

  private static toMeal(source: ApiTravelMeal): TravelMeal {
    return {
      restaurantName: source.restaurantName,
      recommendation: source.recommendation,
      estimatedCost: source.estimatedCost,
    }
  }

  private static sumMealBudgets(days: TravelDayPlan[]): number {
    let total: number = 0
    for (let index: number = 0; index < days.length; index++) {
      if (days[index].mealPlan !== undefined) {
        total += days[index].mealPlan!.dayBudget
      }
    }
    return total
  }

  private static buildSeedPostText(input: TravelPlanGenerateInput): string {
    const destinationName: string = TravelPlanService.resolveDestinationName(input)
    const addressText: string = input.destinationAddress.length > 0 ? `，地址/范围：${input.destinationAddress}` : ''
    const paceText: string = input.selectedPreferences.length > 0 ? input.selectedPreferences : '轻松慢游'
    const foodText: string = input.foodPreference.length > 0 ? input.foodPreference : '当地特色'
    return `用户想去${destinationName}${addressText}旅行。请只围绕${destinationName}本地真实地点规划，不要使用其他城市的地点。旅游节奏：${paceText}。饮食偏好：${foodText}`
  }

  private static buildMockPlaces(): TravelPlace[] {
    return [
      TravelPlanService.place('west-lake', '西湖风景名胜区', 'landmark', '杭州市西湖区龙井路1号', 30.2429, 120.1504, '全天开放', 90, '第一天先用西湖打开城市印象。'),
      TravelPlanService.place('zhejiang-art-museum', '浙江美术馆', 'museum', '杭州市南山路138号', 30.2385, 120.1549, '09:00-17:00', 75, '靠近西湖，适合安排在上午到中午。'),
      TravelPlanService.place('maojiabu', '茅家埠', 'landmark', '杭州市西湖区杨公堤附近', 30.2457, 120.1240, '全天开放', 70, '湖边步行更安静，适合拍照和休息。'),
      TravelPlanService.place('louwailou', '楼外楼', 'restaurant', '杭州市孤山路30号', 30.2534, 120.1478, '10:30-20:30', 75, '经典杭帮菜，作为西湖日午餐。'),
      TravelPlanService.place('leifeng-pagoda', '雷峰塔景区', 'landmark', '杭州市西湖南岸南山路15号', 30.2319, 120.1486, '08:00-20:00', 80, '傍晚登塔视野更好。'),
      TravelPlanService.place('hubin-in77', '杭州湖滨in77', 'shopping', '杭州市上城区延安路', 30.2567, 120.1645, '10:00-22:00', 80, '晚间餐饮和购物集中。'),
      TravelPlanService.place('zhiweiguan', '知味观湖滨总店', 'restaurant', '杭州市上城区仁和路83号', 30.2565, 120.1663, '07:00-21:30', 45, '补充杭州小吃。'),
      TravelPlanService.place('wulin-night-market', '武林夜市', 'shopping', '杭州市拱墅区龙游路', 30.2686, 120.1634, '18:00-23:00', 70, '夜间收尾，吃喝和小摊集中。'),
      TravelPlanService.place('shengli-river-food', '胜利河美食街', 'restaurant', '杭州市拱墅区霞湾巷', 30.3070, 120.1536, '10:00-23:00', 80, '第二天主打美食街。'),
      TravelPlanService.place('xiaohe-street', '小河直街', 'landmark', '杭州市拱墅区小河直街', 30.3090, 120.1408, '全天开放', 70, '运河边街巷，适合慢逛。'),
      TravelPlanService.place('qiaoxi', '桥西历史文化街区', 'landmark', '杭州市拱墅区桥弄街', 30.3137, 120.1418, '全天开放', 60, '与小河直街顺路。'),
      TravelPlanService.place('canal-museum', '京杭大运河博物馆', 'museum', '杭州市拱墅区金华路34号', 30.3148, 120.1430, '09:00-16:30', 75, '补充运河文化。'),
      TravelPlanService.place('hangzhou-tower-501', '杭州大厦501城市广场', 'shopping', '杭州市拱墅区环城北路', 30.2763, 120.1658, '10:00-22:00', 65, '晚餐前后可逛。'),
      TravelPlanService.place('xianghu', '杭州湘湖', 'landmark', '杭州市萧山区湘湖路', 30.1549, 120.2276, '全天开放', 100, '第三天换到湘湖，节奏更舒展。'),
      TravelPlanService.place('hangzhou-paradise', '杭州乐园', 'landmark', '杭州市萧山区风情大道2555号', 30.1564, 120.2555, '10:00-17:00', 180, '适合留出较完整游玩时间。'),
      TravelPlanService.place('polar-ocean', '杭州极地海洋公园', 'landmark', '杭州市萧山区湘湖路777号', 30.1610, 120.2401, '09:00-17:00', 120, '亲友同行时更稳妥。'),
      TravelPlanService.place('qianjiang-light', '钱江新城灯光秀', 'landmark', '杭州市上城区城市阳台', 30.2427, 120.2122, '夜间开放', 45, '晚上看江景灯光。'),
      TravelPlanService.place('city-balcony', '城市阳台', 'landmark', '杭州市上城区之江路', 30.2418, 120.2139, '全天开放', 60, '与灯光秀同区域。'),
      TravelPlanService.place('raffles', '杭州来福士中心', 'shopping', '杭州市上城区新业路228号', 30.2465, 120.2130, '10:00-22:00', 60, '钱江新城晚餐和休息点。'),
      TravelPlanService.place('hangzhou-museum', '杭州博物馆', 'museum', '杭州市上城区粮道山18号', 30.2442, 120.1738, '09:00-16:30', 80, '最后一天从城市历史开始。'),
      TravelPlanService.place('southern-song-street', '南宋御街', 'landmark', '杭州市上城区中山中路', 30.2486, 120.1749, '全天开放', 70, '街区步行顺路。'),
      TravelPlanService.place('hefang-street', '河坊街', 'shopping', '杭州市上城区河坊街', 30.2446, 120.1762, '09:00-22:00', 75, '伴手礼和小吃集中。'),
    ]
  }

  private static buildMockMealPlans(input: TravelPlanGenerateInput): ApiDayMealPlan[] {
    return [
      {
        date: TravelPlanService.addDays(input.startDate, 0),
        breakfast: { restaurantName: '新丰小吃（河坊街店）', recommendation: '虾肉小笼与牛肉粉丝，适合作为西湖行程前的轻早餐。', estimatedCost: 24 },
        lunch: { restaurantName: '楼外楼（孤山路店）', recommendation: '西湖醋鱼、龙井虾仁；建议提前预约临湖座位。', estimatedCost: 128 },
        dinner: { restaurantName: '知味观（湖滨总店）', recommendation: '猫耳朵、幸福双与杭州小吃拼盘，步行可达湖滨夜景。', estimatedCost: 58 },
        dayBudget: 210,
      },
      {
        date: TravelPlanService.addDays(input.startDate, 1),
        breakfast: { restaurantName: '游埠豆浆（中山北路店）', recommendation: '咸豆浆、葱油饼，出发去运河前快速用餐。', estimatedCost: 22 },
        lunch: { restaurantName: '胜利河美食街·文记面馆', recommendation: '片儿川与油爆虾，按当天人流可改为街区内同类店铺。', estimatedCost: 48 },
        dinner: { restaurantName: '小河直街·杭州酒家', recommendation: '杭帮家常菜，适合逛完运河后的两人晚餐。', estimatedCost: 96 },
        dayBudget: 166,
      },
      {
        date: TravelPlanService.addDays(input.startDate, 2),
        breakfast: { restaurantName: '方老大面（萧山店）', recommendation: '拌川或片儿川，靠近湘湖方向，方便上午衔接。', estimatedCost: 26 },
        lunch: { restaurantName: '弄堂里（湘湖店）', recommendation: '本地家常菜，适合游玩杭州乐园后的正餐补给。', estimatedCost: 78 },
        dinner: { restaurantName: '外婆家（来福士店）', recommendation: '茶香鸡、麻婆豆腐等江南口味，晚餐后可步行至钱江新城。', estimatedCost: 88 },
        dayBudget: 192,
      },
      {
        date: TravelPlanService.addDays(input.startDate, 3),
        breakfast: { restaurantName: '高银街·游埠豆浆', recommendation: '豆浆与烧饼，适合返程日轻量用餐。', estimatedCost: 20 },
        lunch: { restaurantName: '奎元馆（解放路店）', recommendation: '虾爆鳝面，南宋御街步行范围内的本地代表餐食。', estimatedCost: 72 },
        dinner: { restaurantName: '知味观（杭州站店）', recommendation: '返程前简餐，可按车次提前或取消。', estimatedCost: 46 },
        dayBudget: 138,
      },
    ]
  }

  private static buildMockDays(input: TravelPlanGenerateInput, places: TravelPlace[]): TravelDayPlan[] {
    return [
      TravelPlanService.day('day-1', input.startDate, 0, '西湖晨光与湖滨夜色', '西湖、博物馆和湖滨商圈串联，步行强度适中。', 21.4, [
        TravelPlanService.item(places[0], '09:30', '11:00', undefined, '营业中'),
        TravelPlanService.item(places[1], '11:15', '12:30', TravelPlanService.commute('west-lake', 'zhejiang-art-museum', 1.2, 12, '步行'), '营业中'),
        TravelPlanService.item(places[3], '12:50', '14:05', TravelPlanService.commute('zhejiang-art-museum', 'louwailou', 2.1, 18, '打车'), '营业中'),
        TravelPlanService.item(places[2], '14:35', '15:45', TravelPlanService.commute('louwailou', 'maojiabu', 4.0, 18, '打车'), '营业中'),
        TravelPlanService.item(places[4], '16:20', '17:40', TravelPlanService.commute('maojiabu', 'leifeng-pagoda', 4.4, 22, '打车'), '营业中'),
        TravelPlanService.item(places[5], '18:15', '19:35', TravelPlanService.commute('leifeng-pagoda', 'hubin-in77', 4.8, 20, '打车'), '营业中'),
        TravelPlanService.item(places[6], '19:45', '20:30', TravelPlanService.commute('hubin-in77', 'zhiweiguan', 0.4, 6, '步行'), '营业中'),
        TravelPlanService.item(places[7], '20:50', '22:00', TravelPlanService.commute('zhiweiguan', 'wulin-night-market', 1.8, 12, '步行/打车'), '营业中'),
      ]),
      TravelPlanService.day('day-2', input.startDate, 1, '运河街巷与胜利河烟火气', '围绕拱墅运河片区慢逛，把美食安排在午晚餐时段。', 18.6, [
        TravelPlanService.item(places[8], '10:00', '11:20', undefined, '营业中'),
        TravelPlanService.item(places[9], '11:35', '12:45', TravelPlanService.commute('shengli-river-food', 'xiaohe-street', 2.3, 14, '打车'), '营业中'),
        TravelPlanService.item(places[10], '13:05', '14:05', TravelPlanService.commute('xiaohe-street', 'qiaoxi', 0.8, 10, '步行'), '营业中'),
        TravelPlanService.item(places[11], '14:15', '15:30', TravelPlanService.commute('qiaoxi', 'canal-museum', 0.3, 5, '步行'), '营业中'),
        TravelPlanService.item(places[12], '17:30', '19:10', TravelPlanService.commute('canal-museum', 'hangzhou-tower-501', 8.4, 26, '打车'), '营业中'),
      ]),
      TravelPlanService.day('day-3', input.startDate, 2, '湘湖轻度游玩与钱江夜景', '白天去湘湖和游乐目的地，晚上回钱江新城看夜景。', 32.8, [
        TravelPlanService.item(places[13], '09:40', '11:20', undefined, '营业中'),
        TravelPlanService.item(places[14], '11:40', '14:40', TravelPlanService.commute('xianghu', 'hangzhou-paradise', 3.2, 12, '打车'), '营业中'),
        TravelPlanService.item(places[15], '15:00', '17:00', TravelPlanService.commute('hangzhou-paradise', 'polar-ocean', 2.1, 10, '打车'), '营业中'),
        TravelPlanService.item(places[17], '18:30', '19:30', TravelPlanService.commute('polar-ocean', 'city-balcony', 22.0, 38, '打车'), '营业中'),
        TravelPlanService.item(places[16], '19:35', '20:20', TravelPlanService.commute('city-balcony', 'qianjiang-light', 0.2, 4, '步行'), '营业中'),
        TravelPlanService.item(places[18], '20:35', '21:35', TravelPlanService.commute('qianjiang-light', 'raffles', 0.7, 9, '步行'), '营业中'),
      ]),
      TravelPlanService.day('day-4', input.startDate, 3, '南宋街区与返程伴手礼', '把最后一天留给上城区老街区，方便控制返程时间。', 9.2, [
        TravelPlanService.item(places[19], '09:40', '11:00', undefined, '营业中'),
        TravelPlanService.item(places[20], '11:15', '12:25', TravelPlanService.commute('hangzhou-museum', 'southern-song-street', 0.7, 10, '步行'), '营业中'),
        TravelPlanService.item(places[21], '12:35', '13:50', TravelPlanService.commute('southern-song-street', 'hefang-street', 0.5, 8, '步行'), '营业中'),
      ]),
    ]
  }

  private static place(id: string, name: string, category: TravelPlaceCategory, address: string, latitude: number, longitude: number,
    openingHours: string, recommendedDurationMinutes: number, note: string): TravelPlace {
    return {
      id,
      name,
      category,
      address,
      latitude,
      longitude,
      openingHours,
      recommendedDurationMinutes,
      note,
    }
  }

  private static item(place: TravelPlace, arriveTime: string, leaveTime: string, commuteFromPrevious: CommuteInfo | undefined,
    openStatus: string): TravelTimelineItem {
    return {
      place,
      arriveTime,
      leaveTime,
      commuteFromPrevious,
      openStatus,
    }
  }

  private static commute(fromPlaceId: string, toPlaceId: string, distanceKm: number, durationMinutes: number, transport: string): CommuteInfo {
    return {
      fromPlaceId,
      toPlaceId,
      distanceKm,
      durationMinutes,
      transport,
    }
  }

  private static day(id: string, startDate: string, offset: number, title: string, summary: string, distanceKm: number,
    items: TravelTimelineItem[]): TravelDayPlan {
    const date: string = TravelPlanService.addDays(startDate, offset)
    return {
      id,
      date,
      dateLabel: TravelPlanService.formatShortDate(date),
      weekday: TravelPlanService.weekday(date),
      title,
      summary,
      distanceKm,
      items,
    }
  }

  private static flattenDays(days: TravelDayPlan[]): TravelTimelineItem[] {
    const items: TravelTimelineItem[] = []
    for (let i = 0; i < days.length; i++) {
      const day: TravelDayPlan = days[i]
      for (let j = 0; j < day.items.length; j++) {
        items.push(day.items[j])
      }
    }
    return items
  }

  private static splitTimelineByDate(startDate: string, endDate: string, timeline: TravelTimelineItem[]): TravelDayPlan[] {
    const dayCount: number = TravelPlanService.getDayCount(startDate, endDate)
    const days: TravelDayPlan[] = []
    const chunkSize: number = Math.max(1, Math.ceil(timeline.length / dayCount))
    for (let i = 0; i < dayCount; i++) {
      const items: TravelTimelineItem[] = []
      const startIndex: number = i * chunkSize
      const endIndex: number = Math.min(timeline.length, startIndex + chunkSize)
      for (let j = startIndex; j < endIndex; j++) {
        items.push(timeline[j])
      }
      const date: string = TravelPlanService.addDays(startDate, i)
      days.push({
        id: `day-${i + 1}`,
        date,
        dateLabel: TravelPlanService.formatShortDate(date),
        weekday: TravelPlanService.weekday(date),
        title: `${TravelPlanService.formatShortDate(date)} 行程`,
        summary: items.length > 0 ? `${items[0].place.name} 等 ${items.length} 个地点` : '当天暂无地点',
        distanceKm: TravelPlanService.sumDistance(items),
        items,
      })
    }
    return days
  }

  private static sumDistance(items: TravelTimelineItem[]): number {
    let total: number = 0
    for (let i = 0; i < items.length; i++) {
      const commute: CommuteInfo | undefined = items[i].commuteFromPrevious
      if (commute !== undefined) {
        total += commute.distanceKm
      }
    }
    return Math.round(total * 10) / 10
  }

  private static findPlace(places: TravelPlace[], placeId: string): TravelPlace | null {
    for (let i = 0; i < places.length; i++) {
      if (places[i].id === placeId) {
        return places[i]
      }
    }
    return null
  }

  private static resolveDestinationName(input: TravelPlanGenerateInput): string {
    if (input.destinationName.length > 0) {
      return input.destinationName
    }
    return '杭州'
  }

  private static resolvePurpose(travelPace: string): TravelPurpose {
    if (travelPace.indexOf('紧凑') >= 0) {
      return 'fast_paced'
    }
    return 'relaxed'
  }

  static getDayCount(startDate: string, endDate: string): number {
    const start: Date = TravelPlanService.parseDate(startDate)
    const end: Date = TravelPlanService.parseDate(endDate)
    const diff: number = Math.round((end.getTime() - start.getTime()) / 86400000) + 1
    if (diff < 1) {
      return 1
    }
    return diff
  }

  static formatShortDate(date: string): string {
    if (date.length >= 10) {
      return `${date.substring(5, 7)}.${date.substring(8, 10)}`
    }
    return date
  }

  static weekday(date: string): string {
    const value: number = TravelPlanService.parseDate(date).getDay()
    const labels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return labels[value]
  }

  private static addDays(date: string, offset: number): string {
    const value: Date = TravelPlanService.parseDate(date)
    value.setDate(value.getDate() + offset)
    const year: number = value.getFullYear()
    const month: number = value.getMonth() + 1
    const day: number = value.getDate()
    const monthText: string = month < 10 ? `0${month}` : `${month}`
    const dayText: string = day < 10 ? `0${day}` : `${day}`
    return `${year}-${monthText}-${dayText}`
  }

  private static parseDate(value: string): Date {
    const parts: string[] = value.split('-')
    if (parts.length < 3) {
      return new Date()
    }
    const year: number = Number(parts[0])
    const month: number = Number(parts[1])
    const day: number = Number(parts[2])
    if (year !== year || month !== month || day !== day) {
      return new Date()
    }
    return new Date(year, month - 1, day)
  }
}
