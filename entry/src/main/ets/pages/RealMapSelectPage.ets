import {
  CommuteInfo,
  SelectedRegion,
  TravelDayPlan,
  TravelDayMealPlan,
  TravelMeal,
  TravelPlace,
  TravelPlan,
  TravelPosterDay,
  TravelPosterMeal,
  TravelPosterPlace,
  TravelTimelineItem,
  WeatherSnapshot,
  APP_COLORS,
} from '../model/Types'
import { RealMapView } from '../components/RealMapView'
import { GoogleMapService, GooglePlaceDetail, GooglePlaceSuggestion } from '../services/GoogleMapService'
import { NotificationService } from '../services/NotificationService'
import { TravelPlanService } from '../services/TravelPlanService'
import { TravelPhotoService } from '../services/TravelPhotoService'
import { TravelPosterService } from '../services/TravelPosterService'
import { WeatherService } from '../services/WeatherService'
import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { pasteboard } from '@kit.BasicServicesKit'

type HomeTab = 'plans' | 'create' | 'explore' | 'detail'
type PlanFilterMode = 'all' | 'place' | 'days'

interface TripCardModel {
  id: string
  title: string
  countdownLabel: string
  dateRangeText: string
  durationText: string
  placeCountText: string
  summaryText: string
  plan: TravelPlan
}

interface PreferenceOption {
  icon: string
  label: string
}

type CollaborationPermission = '可编辑' | '仅查看'

interface CollaborationMember {
  id: string
  name: string
  permission: CollaborationPermission
  status: string
  color: string
}

const HANGZHOU_REGION: SelectedRegion = {
  north: 30.3180,
  south: 30.2050,
  east: 120.2450,
  west: 120.0700,
  centerLat: 30.2570,
  centerLng: 120.1551,
  zoom: 12,
}

const PLAN_BACKGROUND_IMAGES: string[] = [
  'https://commons.wikimedia.org/wiki/Special:FilePath/Westlake%20Hangzhou%20China.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/West%20Lake%20-%20Hangzhou,%20China.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Sanya%20Bay%20-%2002.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Sanya%20bay%20sea%20beach.JPG',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Milford%20Sound.%20New%20Zealand.%20%288171073678%29.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/MoraineLake.jpg',
  'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1483347756197-71ef80e95f73?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1511497584788-876760111969?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1433086966358-54859d0ed716?auto=format&fit=crop&w=1600&q=80',
]

function buildDefaultDate(offset: number): string {
  const now: Date = new Date()
  const date: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset)
  const month: number = date.getMonth() + 1
  const day: number = date.getDate()
  const monthText: string = month < 10 ? `0${month}` : `${month}`
  const dayText: string = day < 10 ? `0${day}` : `${day}`
  return `${date.getFullYear()}-${monthText}-${dayText}`
}

function buildDefaultCountdown(dateText: string): string {
  const values: string[] = dateText.split('-')
  const target: Date = new Date(Number(values[0]), Number(values[1]) - 1, Number(values[2]))
  const now: Date = new Date()
  const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const dayDiff: number = Math.round((target.getTime() - today.getTime()) / 86400000)
  if (dayDiff === 0) {
    return '今天出发'
  }
  if (dayDiff === 1) {
    return '明天出发'
  }
  if (dayDiff > 1) {
    return `${dayDiff}天后出发`
  }
  return '已出发'
}

const DEFAULT_START_DATE: string = buildDefaultDate(1)
const DEFAULT_END_DATE: string = buildDefaultDate(4)

const DEFAULT_TRIP_PLAN: TravelPlan = TravelPlanService.buildMockPlan({
  destinationName: '杭州',
  destinationAddress: '浙江省杭州市',
  startDate: DEFAULT_START_DATE,
  endDate: DEFAULT_END_DATE,
  selectedPreferences: '轻松慢游',
  foodPreference: '当地特色',
  screenshotUri: '',
})

const DEFAULT_TRIP_CARD: TripCardModel = {
  id: DEFAULT_TRIP_PLAN.id,
  title: DEFAULT_TRIP_PLAN.title,
  countdownLabel: buildDefaultCountdown(DEFAULT_START_DATE),
  dateRangeText: `${TravelPlanService.formatShortDate(DEFAULT_START_DATE)}至${TravelPlanService.formatShortDate(DEFAULT_END_DATE)}`,
  durationText: `${TravelPlanService.getDayCount(DEFAULT_START_DATE, DEFAULT_END_DATE)}天${TravelPlanService.getDayCount(DEFAULT_START_DATE, DEFAULT_END_DATE) - 1}晚`,
  placeCountText: `${DEFAULT_TRIP_PLAN.places.length}个地点`,
  summaryText: DEFAULT_TRIP_PLAN.summary,
  plan: DEFAULT_TRIP_PLAN,
}

@Entry
@Component
struct RealMapSelectPage {
  @State showLaunchAnimation: boolean = true
  @State launchLogoScale: number = 0.78
  @State launchLogoOpacity: number = 0
  @State launchOverlayOpacity: number = 1
  @State currentTab: HomeTab = 'plans'
  @State planBackgroundIndex: number = 0
  @State destinationQuery: string = ''
  @State startDate: string = DEFAULT_START_DATE
  @State endDate: string = DEFAULT_END_DATE
  @State hasSelectedDate: boolean = false
  @State selectedPreferences: string = '轻松慢游'
  @State foodPreferences: string = '当地特色'
  @State savedPlans: TripCardModel[] = [DEFAULT_TRIP_CARD]
  @State destinationSuggestions: GooglePlaceSuggestion[] = []
  @State isSearchingDestination: boolean = false
  @State selectedDestinationName: string = ''
  @State selectedDestinationAddress: string = ''
  @State selectedDestinationPlaceId: string = ''
  @State destinationSearchSeq: number = 0
  @State screenshotUri: string = ''
  @State isGeneratingPlan: boolean = false
  @State planGenerationError: string = ''
  @State selectedPlanId: string = DEFAULT_TRIP_CARD.id
  @State selectedDayId: string = 'overview'
  @State focusedPlaceId: string = ''
  @State detailPlacePhotos: TravelPosterPlace[] = []
  @State detailPlacePhotoLoadingId: string = ''
  @State showPlanSearch: boolean = false
  @State planSearchQuery: string = ''
  @State planFilterMode: PlanFilterMode = 'all'
  @State exploreSelectedPlace: TravelPlace | null = null
  @State explorePlaceImageUrl: string = ''
  @State explorePlaceImageAttribution: string = ''
  @State isExplorePlaceLoading: boolean = false
  @State selectedPlaceFilter: string = '全部'
  @State selectedDurationFilter: string = '全部'
  @State activePlanActionId: string = ''
  @State renamingPlanId: string = ''
  @State renamePlanTitle: string = ''
  @State activePlaceActionId: string = ''
  @State editingPlaceId: string = ''
  @State editingPlaceQuery: string = ''
  @State editingPlaceSuggestions: GooglePlaceSuggestion[] = []
  @State isSearchingEditPlace: boolean = false
  @State editPlaceSearchSeq: number = 0
  @State replacingPlaceId: string = ''
  @State draggingPlaceId: string = ''
  @State dragTargetPlaceId: string = ''
  @State placeDragOffsetY: number = 0
  @State detailSheetLevel: number = 1
  @State detailSheetDragOffset: number = 0
  @State showAiPlanner: boolean = false
  @State aiPlannerInput: string = ''
  @State aiPlannerReply: string = '我会结合当前天气和行程顺序，帮你实时调整路线。'
  @State isAiReplanning: boolean = false
  @State currentWeather: WeatherSnapshot | null = null
  @State baselineWeather: WeatherSnapshot | null = null
  @State weatherAlertText: string = ''
  @State isWeatherRefreshing: boolean = false
  @State showPoster: boolean = false
  @State isPosterLoading: boolean = false
  @State posterTitle: string = ''
  @State posterSubtitle: string = ''
  @State posterDays: TravelPosterDay[] = []
  @State posterError: string = ''
  @State showCollaborationPanel: boolean = false
  @State collaborationInvitee: string = ''
  @State collaborationPermission: CollaborationPermission = '可编辑'
  @State collaborationFeedback: string = ''
  @State collaborationMembers: CollaborationMember[] = [
    { id: 'owner', name: '我', permission: '可编辑', status: '在线', color: APP_COLORS.PRIMARY },
    { id: 'friend-lin', name: '林一', permission: '可编辑', status: '正在查看第 2 天', color: APP_COLORS.INFO },
  ]

  private posterLoadId: number = 0

  private detailPhotoLoadId: number = 0

  private explorePlaceLoadId: number = 0

  private weatherRefreshTimer: number = -1

  private launchAnimationSequence: number = 0

  private preferenceOptions: PreferenceOption[] = [
    { icon: '🌿', label: '轻松慢游' },
    { icon: '🚶', label: '适中游玩' },
    { icon: '⚡', label: '紧凑打卡' },
  ]

  private foodPreferenceOptions: PreferenceOption[] = [
    { icon: '🥢', label: '当地特色' },
    { icon: '🍜', label: '街头小吃' },
    { icon: '☕', label: '咖啡甜品' },
    { icon: '🥬', label: '素食友好' },
    { icon: '🌶️', label: '无辣偏好' },
    { icon: '🍽️', label: '餐厅优先' },
  ]

  private parseDate(value: string): Date {
    const parts: string[] = value.split('-')
    if (parts.length < 3) {
      return new Date()
    }
    const year: number = Number(parts[0])
    const month: number = Number(parts[1])
    const day: number = Number(parts[2])
    if (this.isInvalidNumber(year) || this.isInvalidNumber(month) || this.isInvalidNumber(day)) {
      return new Date()
    }
    return new Date(year, month - 1, day)
  }

  private isInvalidNumber(value: number): boolean {
    return value !== value
  }

  private formatDateResult(value: DatePickerResult, fallback: string): string {
    const fallbackDate: Date = this.parseDate(fallback)
    const year: number = value.year === undefined ? fallbackDate.getFullYear() : value.year
    const monthValue: number = value.month === undefined ? fallbackDate.getMonth() : value.month
    const day: number = value.day === undefined ? fallbackDate.getDate() : value.day
    const month: number = monthValue + 1
    const monthText: string = month < 10 ? `0${month}` : `${month}`
    const dayText: string = day < 10 ? `0${day}` : `${day}`
    return `${year}-${monthText}-${dayText}`
  }

  private showStartDatePicker() {
    DatePickerDialog.show({
      start: new Date(),
      end: new Date(new Date().getFullYear() + 1, 11, 31),
      selected: this.parseDate(this.startDate),
      onAccept: (value: DatePickerResult) => {
        this.startDate = this.formatDateResult(value, this.startDate)
        if (this.endDate < this.startDate) {
          this.endDate = this.startDate
        }
        this.hasSelectedDate = true
      },
    })
  }

  private showEndDatePicker() {
    DatePickerDialog.show({
      start: new Date(),
      end: new Date(new Date().getFullYear() + 1, 11, 31),
      selected: this.parseDate(this.endDate),
      onAccept: (value: DatePickerResult) => {
        this.endDate = this.formatDateResult(value, this.endDate)
        if (this.endDate < this.startDate) {
          this.startDate = this.endDate
        }
        this.hasSelectedDate = true
      },
    })
  }

  private async handleDestinationInput(value: string) {
    this.destinationQuery = value
    this.selectedDestinationPlaceId = ''
    if (value.trim().length < 2) {
      this.destinationSuggestions = []
      this.isSearchingDestination = false
      return
    }

    this.destinationSearchSeq += 1
    const currentSeq: number = this.destinationSearchSeq
    this.isSearchingDestination = true
    const suggestions: GooglePlaceSuggestion[] = await GoogleMapService.searchPlaceSuggestions(value)
    if (currentSeq !== this.destinationSearchSeq) {
      return
    }
    this.destinationSuggestions = suggestions
    this.isSearchingDestination = false
  }

  private chooseDestination(suggestion: GooglePlaceSuggestion) {
    this.selectedDestinationName = suggestion.title
    this.selectedDestinationAddress = suggestion.subtitle
    this.selectedDestinationPlaceId = suggestion.placeId
    this.destinationQuery = ''
    this.destinationSuggestions = []
  }

  private clearDestination() {
    this.selectedDestinationName = ''
    this.selectedDestinationAddress = ''
    this.selectedDestinationPlaceId = ''
  }

  private async pickScreenshot() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      photoSelectOptions.maxSelectNumber = 1
      const photoPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoPicker.select(photoSelectOptions)
      if (result.photoUris.length > 0) {
        this.screenshotUri = result.photoUris[0]
      }
    } catch (e) {
      const err = e as Error
      console.error(`Pick screenshot failed: ${err.message}`)
    }
  }

  private hasPreference(label: string): boolean {
    return this.selectedPreferences === label
  }

  private hasFoodPreference(label: string): boolean {
    const source: string = `|${this.foodPreferences}|`
    return source.indexOf(`|${label}|`) >= 0
  }

  private togglePreference(label: string) {
    this.selectedPreferences = label
  }

  private toggleFoodPreference(label: string) {
    const values: string[] = this.foodPreferences.split('|')
    let next: string = ''
    let removed: boolean = false
    for (let i = 0; i < values.length; i++) {
      const item: string = values[i]
      if (item.length === 0) {
        continue
      }
      if (item === label) {
        removed = true
        continue
      }
      next = next.length === 0 ? item : `${next}|${item}`
    }
    if (!removed) {
      next = next.length === 0 ? label : `${next}|${label}`
    }
    this.foodPreferences = next
  }

  private async handleSmartPlan() {
    if (this.isGeneratingPlan) {
      return
    }
    this.isGeneratingPlan = true
    this.planGenerationError = ''
    try {
      const typedDestination: string = this.destinationQuery.trim()
      const destinationName: string = this.selectedDestinationName.length > 0 ? this.selectedDestinationName : (typedDestination.length > 0 ? typedDestination : '杭州')
      const plan: TravelPlan = await TravelPlanService.generatePlan({
        destinationName,
        destinationAddress: this.selectedDestinationAddress,
        startDate: this.startDate,
        endDate: this.endDate,
        selectedPreferences: this.selectedPreferences,
        foodPreference: this.foodPreferences,
        screenshotUri: this.screenshotUri,
      })
      const card: TripCardModel = this.buildTripCard(plan)
      const updated: TripCardModel[] = []
      for (let i = 0; i < this.savedPlans.length; i++) {
        if (this.savedPlans[i].id === DEFAULT_TRIP_CARD.id) {
          updated.push(this.savedPlans[i])
        }
      }
      for (let i = 0; i < this.savedPlans.length; i++) {
        if (this.savedPlans[i].id !== DEFAULT_TRIP_CARD.id && this.savedPlans[i].id !== card.id) {
          updated.push(this.savedPlans[i])
        }
      }
      updated.push(card)
      this.savedPlans = updated
      this.selectedPlanId = card.id
      this.selectedDayId = 'overview'
      this.focusedPlaceId = ''
      this.stopDetailWeatherWatch()
      this.currentTab = 'plans'
    } catch (e) {
      const err = e as Error
      console.error(`Smart plan failed: ${err.message}`)
      this.planGenerationError = `大模型规划失败：${err.message}`
    } finally {
      this.isGeneratingPlan = false
    }
  }

  private buildTripCard(plan: TravelPlan): TripCardModel {
    const dayCount: number = TravelPlanService.getDayCount(plan.preference.startDate, plan.preference.endDate)
    const nights: number = Math.max(0, dayCount - 1)
    return {
      id: plan.id,
      title: plan.title,
      countdownLabel: this.countdownLabel(plan.preference.startDate),
      dateRangeText: `${TravelPlanService.formatShortDate(plan.preference.startDate)}至${TravelPlanService.formatShortDate(plan.preference.endDate)}`,
      durationText: `${dayCount}天${nights}晚`,
      placeCountText: `${plan.places.length}个地点`,
      summaryText: plan.summary,
      plan,
    }
  }

  private countdownLabel(date: string): string {
    const target: Date = this.parseDate(date)
    const now: Date = new Date()
    const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const diff: number = Math.round((target.getTime() - today.getTime()) / 86400000)
    if (diff === 0) {
      return '今天出发'
    }
    if (diff === 1) {
      return '明天出发'
    }
    if (diff > 1) {
      return `${diff}天后出发`
    }
    return '已出发'
  }

  private openPlan(plan: TripCardModel) {
    this.selectedPlanId = plan.id
    this.selectedDayId = 'overview'
    this.focusedPlaceId = ''
    this.activePlanActionId = ''
    this.activePlaceActionId = ''
    this.detailSheetLevel = 1
    this.showAiPlanner = false
    this.showCollaborationPanel = false
    this.currentWeather = null
    this.baselineWeather = null
    this.weatherAlertText = ''
    this.currentTab = 'detail'
    this.startDetailWeatherWatch()
    this.ensureWeatherNotificationEnabled()
  }

  private async openPoster(plan: TripCardModel) {
    this.posterLoadId += 1
    const loadId: number = this.posterLoadId
    this.posterTitle = plan.title
    this.posterSubtitle = `${plan.dateRangeText} · ${plan.placeCountText}`
    this.posterDays = []
    this.posterError = ''
    this.isPosterLoading = true
    this.showPoster = true
    try {
      const days: TravelPosterDay[] = await TravelPosterService.buildPosterDays(plan.plan)
      if (loadId !== this.posterLoadId) {
        return
      }
      this.posterDays = days
    } catch (e) {
      if (loadId !== this.posterLoadId) {
        return
      }
      const err = e as Error
      this.posterError = `海报图片获取失败：${err.message}`
    } finally {
      if (loadId === this.posterLoadId) {
        this.isPosterLoading = false
      }
    }
  }

  private closePoster() {
    this.posterLoadId += 1
    this.showPoster = false
    this.isPosterLoading = false
  }

  aboutToDisappear() {
    this.stopDetailWeatherWatch()
  }

  aboutToAppear() {
    this.rotatePlanBackground()
    this.playLaunchAnimation()
  }

  onPageShow() {
    this.rotatePlanBackground()
    if (!this.showLaunchAnimation) {
      this.playLaunchAnimation()
    }
  }

  private rotatePlanBackground(): void {
    const seconds: number = Math.floor(new Date().getTime() / 1000)
    this.planBackgroundIndex = seconds % PLAN_BACKGROUND_IMAGES.length
  }

  private playLaunchAnimation() {
    this.launchAnimationSequence += 1
    const sequence: number = this.launchAnimationSequence
    this.showLaunchAnimation = true
    this.launchLogoScale = 0.78
    this.launchLogoOpacity = 0
    this.launchOverlayOpacity = 1

    setTimeout(() => {
      if (sequence !== this.launchAnimationSequence) {
        return
      }
      animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
        this.launchLogoScale = 1
        this.launchLogoOpacity = 1
      })
    }, 80)

    setTimeout(() => {
      if (sequence !== this.launchAnimationSequence) {
        return
      }
      animateTo({ duration: 360, curve: Curve.EaseIn }, () => {
        this.launchLogoScale = 1.08
        this.launchLogoOpacity = 0
        this.launchOverlayOpacity = 0
      })
    }, 1050)

    setTimeout(() => {
      if (sequence === this.launchAnimationSequence) {
        this.showLaunchAnimation = false
      }
    }, 1450)
  }

  private startDetailWeatherWatch() {
    this.stopDetailWeatherWatch()
    this.refreshDetailWeather(true)
    this.weatherRefreshTimer = setInterval(() => {
      if (this.currentTab === 'detail') {
        this.refreshDetailWeather(false)
      } else {
        this.stopDetailWeatherWatch()
      }
    }, 180000)
  }

  private async ensureWeatherNotificationEnabled(): Promise<boolean> {
    const context = getContext(this) as common.UIAbilityContext
    return NotificationService.ensureEnabled(context)
  }

  private async publishWeatherSystemAdvice(title: string, text: string) {
    const enabled: boolean = await this.ensureWeatherNotificationEnabled()
    if (!enabled) {
      this.aiPlannerReply = `${text}\n系统通知未开启，请在系统设置里允许 WanderSketch 通知。`
      return
    }
    const published: boolean = await NotificationService.publishWeatherAdvice(title, text)
    if (published) {
      this.aiPlannerReply = `${text}\n已发送系统通知。`
    } else {
      this.aiPlannerReply = `${text}\n系统通知发送失败，请检查通知权限和通知类别设置。`
    }
  }

  private async openSystemNotificationSettings() {
    const context = getContext(this) as common.UIAbilityContext
    await NotificationService.openSettings(context)
  }

  private scheduleBackgroundNotificationTest() {
    this.aiPlannerReply = '5 秒后发送系统通知。现在按 Home 回到桌面，测试后台横幅是否出现。'
    setTimeout(() => {
      NotificationService.publishWeatherAdvice('天气测试提醒', '这是后台横幅测试：天气变化时建议修改旅行计划。')
    }, 5000)
  }

  private stopDetailWeatherWatch() {
    if (this.weatherRefreshTimer >= 0) {
      clearInterval(this.weatherRefreshTimer)
      this.weatherRefreshTimer = -1
    }
  }

  private async refreshDetailWeather(resetBaseline: boolean) {
    if (this.isWeatherRefreshing || this.currentTab !== 'detail') {
      return
    }
    this.isWeatherRefreshing = true
    try {
      const weather: WeatherSnapshot = await WeatherService.fetchCurrent(this.currentPlan().region)
      const previousBaseline: WeatherSnapshot | null = this.baselineWeather
      this.currentWeather = weather
      if (resetBaseline || previousBaseline === null) {
        this.baselineWeather = weather
        this.weatherAlertText = ''
      } else {
        const baseWeather: WeatherSnapshot = previousBaseline!
        if (WeatherService.isLargeChange(baseWeather, weather)) {
          this.weatherAlertText = WeatherService.alertText(baseWeather, weather)
          this.aiPlannerReply = this.weatherAlertText
          this.showAiPlanner = true
          this.publishWeatherSystemAdvice('天气变化，建议调整行程', this.weatherAlertText)
        } else if (WeatherService.isGoodChange(baseWeather, weather)) {
          this.weatherAlertText = WeatherService.betterText(baseWeather, weather)
          this.aiPlannerReply = this.weatherAlertText
          this.showAiPlanner = true
          this.publishWeatherSystemAdvice('天气转好，可以优化计划', this.weatherAlertText)
        }
      }
    } catch (e) {
      const err = e as Error
      console.error(`Refresh detail weather failed: ${err.message}`)
    } finally {
      this.isWeatherRefreshing = false
    }
  }

  private revealPlanActions(planId: string) {
    this.activePlanActionId = planId
    this.renamingPlanId = ''
  }

  private resetPlanActions() {
    this.activePlanActionId = ''
    this.renamingPlanId = ''
  }

  private handlePlanCardPanEnd(planId: string, event: GestureEvent) {
    if (event.offsetX < -18) {
      this.revealPlanActions(planId)
    } else if (event.offsetX > 18 && this.activePlanActionId === planId) {
      this.resetPlanActions()
    }
  }

  private beginRenamePlan(plan: TripCardModel) {
    this.renamingPlanId = plan.id
    this.renamePlanTitle = plan.title
  }

  private applyRenamePlan() {
    const nextTitle: string = this.renamePlanTitle.trim()
    if (nextTitle.length === 0 || this.renamingPlanId.length === 0) {
      this.renamingPlanId = ''
      return
    }
    const updated: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      const current: TripCardModel = this.savedPlans[i]
      if (current.id === this.renamingPlanId) {
        const plan: TravelPlan = current.plan
        plan.title = nextTitle
        const renamed: TripCardModel = {
          id: current.id,
          title: nextTitle,
          countdownLabel: current.countdownLabel,
          dateRangeText: current.dateRangeText,
          durationText: current.durationText,
          placeCountText: current.placeCountText,
          summaryText: current.summaryText,
          plan,
        }
        updated.push(renamed)
      } else {
        updated.push(current)
      }
    }
    this.savedPlans = updated
    this.renamingPlanId = ''
    this.activePlanActionId = ''
  }

  private deletePlan(planId: string) {
    const updated: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      if (this.savedPlans[i].id !== planId) {
        updated.push(this.savedPlans[i])
      }
    }
    this.savedPlans = updated
    if (this.selectedPlanId === planId) {
      this.selectedPlanId = updated.length > 0 ? updated[0].id : ''
      this.selectedDayId = 'overview'
      this.focusedPlaceId = ''
      this.stopDetailWeatherWatch()
      if (updated.length === 0 || this.currentTab === 'detail') {
        this.currentTab = 'plans'
      }
    }
    this.activePlanActionId = ''
    this.renamingPlanId = ''
  }

  private currentPlan(): TravelPlan {
    for (let i = 0; i < this.savedPlans.length; i++) {
      if (this.savedPlans[i].id === this.selectedPlanId) {
        return this.savedPlans[i].plan
      }
    }
    if (this.savedPlans.length > 0) {
      return this.savedPlans[0].plan
    }
    return DEFAULT_TRIP_PLAN
  }

  private buildCollaborationInviteText(plan: TravelPlan): string {
    const dayCount: number = TravelPlanService.getDayCount(plan.preference.startDate, plan.preference.endDate)
    const nights: number = Math.max(0, dayCount - 1)
    const inviteCode: string = plan.id.length > 8 ? plan.id.substring(plan.id.length - 8).toUpperCase() : plan.id.toUpperCase()
    const lines: string[] = []
    lines.push('WanderSketch 共同编辑邀请')
    lines.push(`邀请码：${inviteCode}`)
    lines.push('加入后可一起调整景点、时间、餐饮和预算。')
    lines.push('')
    lines.push(`WanderSketch｜${plan.title}`)
    lines.push(`${plan.preference.startDate} 至 ${plan.preference.endDate}｜${dayCount}天${nights}晚｜${plan.places.length}个地点`)
    if (plan.summary.length > 0) {
      lines.push(plan.summary)
    }
    for (let i = 0; i < plan.days.length; i++) {
      const day: TravelDayPlan = plan.days[i]
      lines.push('')
      lines.push(`${day.dateLabel} ${day.weekday}｜${day.title}`)
      if (day.summary.length > 0) {
        lines.push(day.summary)
      }
      for (let j = 0; j < day.items.length; j++) {
        const item: TravelTimelineItem = day.items[j]
        let row: string = `${item.arriveTime}-${item.leaveTime} ${item.place.name}`
        if (item.commuteFromPrevious !== undefined) {
          row = `${row}｜交通：${item.commuteFromPrevious.transport}，约${item.commuteFromPrevious.durationMinutes}分钟，${item.commuteFromPrevious.distanceKm}公里`
        }
        lines.push(row)
      }
    }
    return lines.join('\n')
  }

  private async inviteCollaborators() {
    const shareText: string = this.buildCollaborationInviteText(this.currentPlan())
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareText)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteData)
      AlertDialog.show({
        title: '共同编辑邀请已复制',
        message: '把邀请发送给同行人；协作成员可以一起调整景点、时间、餐饮和预算。',
        autoCancel: true,
        primaryButton: {
          value: '知道了',
          action: () => {
          },
        },
      })
    } catch (error) {
      AlertDialog.show({
        title: '共同编辑邀请',
        message: shareText,
        autoCancel: true,
        primaryButton: {
          value: '知道了',
          action: () => {
          },
        },
      })
    }
  }

  private openCollaborationPanel() {
    this.collaborationFeedback = ''
    this.showCollaborationPanel = true
  }

  private collaborationInviteCode(): string {
    const planId: string = this.currentPlan().id
    if (planId.length > 8) {
      return planId.substring(planId.length - 8).toUpperCase()
    }
    return planId.toUpperCase()
  }

  private async copyCollaborationInvite() {
    const inviteText: string = `WanderSketch 共同编辑邀请\n邀请码：${this.collaborationInviteCode()}\n权限：${this.collaborationPermission}`
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, inviteText)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteData)
      this.collaborationFeedback = '邀请码已复制，发送给同行人即可。'
    } catch (error) {
      this.collaborationFeedback = '复制失败，请记下邀请码后手动发送。'
    }
  }

  private addCollaborationMember() {
    const name: string = this.collaborationInvitee.trim()
    if (name.length === 0) {
      this.collaborationFeedback = '请先输入同行人昵称。'
      return
    }
    const next: CollaborationMember[] = []
    for (let index: number = 0; index < this.collaborationMembers.length; index++) {
      next.push(this.collaborationMembers[index])
    }
    next.push({
      id: `invite-${Date.now()}`,
      name,
      permission: this.collaborationPermission,
      status: '邀请已发送',
      color: APP_COLORS.INFO,
    })
    this.collaborationMembers = next
    this.collaborationInvitee = ''
    this.collaborationFeedback = `已向 ${name} 发送${this.collaborationPermission}邀请。`
  }

  private toggleCollaborationPermission(memberId: string) {
    const next: CollaborationMember[] = []
    for (let index: number = 0; index < this.collaborationMembers.length; index++) {
      const member: CollaborationMember = this.collaborationMembers[index]
      if (member.id === memberId) {
        const permission: CollaborationPermission = member.permission === '可编辑' ? '仅查看' : '可编辑'
        next.push({ id: member.id, name: member.name, permission, status: member.status, color: member.color })
      } else {
        next.push(member)
      }
    }
    this.collaborationMembers = next
  }

  private selectDay(dayId: string) {
    this.selectedDayId = dayId
    this.focusedPlaceId = ''
  }

  private selectPlaceFromMap(placeId: string) {
    const plan: TravelPlan = this.currentPlan()
    for (let i = 0; i < plan.days.length; i++) {
      const day: TravelDayPlan = plan.days[i]
      for (let j = 0; j < day.items.length; j++) {
        if (day.items[j].place.id === placeId) {
          this.selectedDayId = day.id
          this.focusedPlaceId = placeId
          this.loadDetailPlacePhoto(day.items[j])
          this.detailSheetLevel = 1
          this.activePlaceActionId = ''
          return
        }
      }
    }
    this.focusedPlaceId = placeId
    this.detailSheetLevel = 1
  }

  private openPlaceDetail(item: TravelTimelineItem) {
    this.focusedPlaceId = item.place.id
    this.loadDetailPlacePhoto(item)
  }

  private detailPlacePhotoUrl(placeId: string): string {
    for (let index: number = 0; index < this.detailPlacePhotos.length; index++) {
      if (this.detailPlacePhotos[index].id === placeId) {
        return this.detailPlacePhotos[index].imageUrl
      }
    }
    return ''
  }

  private detailPlacePhotoAttribution(placeId: string): string {
    for (let index: number = 0; index < this.detailPlacePhotos.length; index++) {
      if (this.detailPlacePhotos[index].id === placeId) {
        return this.detailPlacePhotos[index].attribution
      }
    }
    return ''
  }

  private hasDetailPlacePhoto(placeId: string): boolean {
    for (let index: number = 0; index < this.detailPlacePhotos.length; index++) {
      if (this.detailPlacePhotos[index].id === placeId) {
        return true
      }
    }
    return false
  }

  private async loadDetailPlacePhoto(item: TravelTimelineItem) {
    const placeId: string = item.place.id
    if (this.hasDetailPlacePhoto(placeId) || this.detailPlacePhotoLoadingId === placeId) {
      return
    }
    this.detailPhotoLoadId += 1
    const loadId: number = this.detailPhotoLoadId
    this.detailPlacePhotoLoadingId = placeId
    try {
      const query: string = `${item.place.name} ${item.place.address}`
      let photo = await GoogleMapService.fetchPlacePhoto(query)
      if (photo === null) {
        photo = await GoogleMapService.fetchPlacePhoto(item.place.name)
      }
      const imageUrl: string = photo === null ? GoogleMapService.buildPlaceMapCoverUrl(item.place.latitude, item.place.longitude) : photo.imageUrl
      const attribution: string = photo === null ? '路线坐标图 · Google Maps' : photo.attribution
      if (loadId !== this.detailPhotoLoadId) {
        return
      }
      const nextPhotos: TravelPosterPlace[] = []
      for (let index: number = 0; index < this.detailPlacePhotos.length; index++) {
        if (this.detailPlacePhotos[index].id !== placeId) {
          nextPhotos.push(this.detailPlacePhotos[index])
        }
      }
      nextPhotos.push({
        id: placeId,
        name: item.place.name,
        imageUrl,
        description: item.place.note,
        attribution,
      })
      this.detailPlacePhotos = nextPhotos
    } catch (e) {
      const err = e as Error
      console.error(`Detail place photo load failed: ${err.message}`)
    } finally {
      if (loadId === this.detailPhotoLoadId) {
        this.detailPlacePhotoLoadingId = ''
      }
    }
  }

  private async selectExplorePlace(placeId: string) {
    const normalizedId: string = placeId.trim()
    if (normalizedId.length === 0) {
      return
    }
    this.explorePlaceLoadId += 1
    const loadId: number = this.explorePlaceLoadId
    this.isExplorePlaceLoading = true
    this.exploreSelectedPlace = null
    this.explorePlaceImageUrl = ''
    this.explorePlaceImageAttribution = ''
    try {
      const detail: GooglePlaceDetail | null = await GoogleMapService.fetchPlaceDetail(normalizedId)
      if (detail === null || detail.title.length === 0) {
        return
      }
      const place: TravelPlace = {
        id: detail.placeId,
        name: detail.title,
        category: detail.category,
        address: detail.address,
        latitude: detail.latitude,
        longitude: detail.longitude,
        openingHours: detail.openingHours,
        recommendedDurationMinutes: 60,
        note: detail.summary.length > 0 ? detail.summary :
          `${this.categoryLabel(detail.category)} · 位于${detail.address.length > 0 ? detail.address : '当前探索区域'}。`,
      }
      if (loadId !== this.explorePlaceLoadId) {
        return
      }
      this.exploreSelectedPlace = place
      let photo = await GoogleMapService.fetchPlacePhoto(`${place.name} ${place.address}`)
      if (photo === null) {
        photo = await GoogleMapService.fetchPlacePhoto(place.name)
      }
      if (loadId !== this.explorePlaceLoadId) {
        return
      }
      this.explorePlaceImageUrl = photo === null ? GoogleMapService.buildPlaceMapCoverUrl(place.latitude, place.longitude) : photo.imageUrl
      this.explorePlaceImageAttribution = photo === null ? '路线坐标图 · Google Maps' : photo.attribution
    } catch (e) {
      const err = e as Error
      console.error(`Explore place load failed: ${err.message}`)
    } finally {
      if (loadId === this.explorePlaceLoadId) {
        this.isExplorePlaceLoading = false
      }
    }
  }

  private closeExplorePlacePanel() {
    this.explorePlaceLoadId += 1
    this.isExplorePlaceLoading = false
    this.exploreSelectedPlace = null
    this.explorePlaceImageUrl = ''
    this.explorePlaceImageAttribution = ''
  }

  private mapDays(plan: TravelPlan): TravelDayPlan[] {
    if (this.selectedDayId === 'overview') {
      return plan.days
    }
    const days: TravelDayPlan[] = []
    for (let i = 0; i < plan.days.length; i++) {
      if (plan.days[i].id === this.selectedDayId) {
        days.push(plan.days[i])
      }
    }
    return days
  }

  private currentTimeline(plan: TravelPlan): TravelTimelineItem[] {
    if (this.selectedDayId === 'overview') {
      return plan.timeline
    }
    for (let i = 0; i < plan.days.length; i++) {
      if (plan.days[i].id === this.selectedDayId) {
        return plan.days[i].items
      }
    }
    return plan.timeline
  }

  private currentDayTitle(plan: TravelPlan): string {
    if (this.selectedDayId === 'overview') {
      return '行程概览'
    }
    for (let i = 0; i < plan.days.length; i++) {
      if (plan.days[i].id === this.selectedDayId) {
        return `${plan.days[i].dateLabel} ${plan.days[i].weekday} ${plan.days[i].title}`
      }
    }
    return '行程概览'
  }

  private currentDaySummary(plan: TravelPlan): string {
    if (this.selectedDayId === 'overview') {
      return plan.summary
    }
    for (let i = 0; i < plan.days.length; i++) {
      if (plan.days[i].id === this.selectedDayId) {
        return plan.days[i].summary
      }
    }
    return plan.summary
  }

  private categoryLabel(category: string): string {
    if (category === 'restaurant') {
      return '餐饮'
    }
    if (category === 'museum') {
      return '展馆'
    }
    if (category === 'shopping') {
      return '购物'
    }
    if (category === 'cafe') {
      return '咖啡'
    }
    return '景点'
  }

  private renderedCommuteItem(item: TravelTimelineItem, itemIndex: number): TravelTimelineItem {
    const timeline: TravelTimelineItem[] = this.currentTimeline(this.currentPlan())
    let commute: CommuteInfo | undefined = undefined
    if (itemIndex > 0 && itemIndex < timeline.length) {
      commute = this.buildCommuteInfo(timeline[itemIndex - 1].place, item.place)
    }
    return {
      place: item.place,
      arriveTime: item.arriveTime,
      leaveTime: item.leaveTime,
      commuteFromPrevious: commute,
      openStatus: item.openStatus,
    }
  }

  private commuteText(item: TravelTimelineItem): string {
    const commute = item.commuteFromPrevious
    if (commute === undefined) {
      return ''
    }
    if (commute.transport.indexOf('分钟') >= 0 || commute.transport.indexOf('小时') >= 0) {
      return `${commute.transport} · ${commute.distanceKm}公里`
    }
    return `${commute.transport} · ${commute.durationMinutes}分钟 · ${commute.distanceKm}公里`
  }

  private commuteKind(item: TravelTimelineItem): string {
    const commute = item.commuteFromPrevious
    if (commute === undefined) {
      return 'other'
    }
    const transport: string = commute.transport
    if (transport.indexOf('地铁') >= 0 || transport.indexOf('轻轨') >= 0 || transport.indexOf('S1') >= 0 ||
      transport.indexOf('metro') >= 0 || transport.indexOf('subway') >= 0) {
      return 'metro'
    }
    if (transport.indexOf('公交') >= 0 || transport.indexOf('巴士') >= 0 || transport.indexOf('bus') >= 0) {
      return 'bus'
    }
    if (transport.indexOf('打车') >= 0 || transport.indexOf('出租') >= 0 || transport.indexOf('网约') >= 0 ||
      transport.indexOf('驾车') >= 0 || transport.indexOf('taxi') >= 0 || transport.indexOf('drive') >= 0) {
      return 'taxi'
    }
    if (transport.indexOf('步行') >= 0 || transport.indexOf('walk') >= 0) {
      return 'walk'
    }
    return 'other'
  }

  private commuteIcon(item: TravelTimelineItem): string {
    const kind: string = this.commuteKind(item)
    if (kind === 'walk') {
      return '🚶'
    }
    if (kind === 'bus') {
      return '🚌'
    }
    if (kind === 'metro') {
      return 'M'
    }
    if (kind === 'taxi') {
      return '🚕'
    }
    return '→'
  }

  private commuteIconColor(item: TravelTimelineItem): string {
    const kind: string = this.commuteKind(item)
    if (kind === 'walk') {
      return APP_COLORS.SUCCESS
    }
    if (kind === 'bus') {
      return APP_COLORS.INFO
    }
    if (kind === 'metro') {
      return APP_COLORS.INFO
    }
    if (kind === 'taxi') {
      return APP_COLORS.ACCENT
    }
    return APP_COLORS.PRIMARY
  }

  private commuteIconBg(item: TravelTimelineItem): string {
    const kind: string = this.commuteKind(item)
    if (kind === 'walk') {
      return APP_COLORS.SUCCESS_SOFT
    }
    if (kind === 'bus') {
      return APP_COLORS.INFO_SOFT
    }
    if (kind === 'metro') {
      return APP_COLORS.INFO_SOFT
    }
    if (kind === 'taxi') {
      return APP_COLORS.WARNING_SOFT
    }
    return APP_COLORS.ACCENT_SOFT
  }

  private showCommuteDetail(item: TravelTimelineItem) {
    const message: string = this.commuteText(item)
    if (message.length === 0) {
      return
    }
    AlertDialog.show({
      title: '交通详情',
      message: message,
      autoCancel: true,
      primaryButton: {
        value: '知道了',
        action: () => {
        },
      },
    })
  }

  private revealPlaceActions(placeId: string) {
    this.activePlaceActionId = placeId
  }

  private resetPlaceActions() {
    this.activePlaceActionId = ''
  }

  private handlePlaceCardPanEnd(placeId: string, event: GestureEvent) {
    if (event.offsetX < -18) {
      this.revealPlaceActions(placeId)
    } else if (event.offsetX > 18 && this.activePlaceActionId === placeId) {
      this.resetPlaceActions()
    }
  }

  private startPlaceDrag(placeId: string) {
    if (this.selectedDayId === 'overview') {
      return
    }
    this.draggingPlaceId = placeId
    this.dragTargetPlaceId = placeId
    this.placeDragOffsetY = 0
    this.activePlaceActionId = ''
  }

  private updatePlaceDrag(placeId: string, event: GestureEvent) {
    if (this.draggingPlaceId.length === 0) {
      this.startPlaceDrag(placeId)
    }
    if (this.draggingPlaceId !== placeId) {
      return
    }
    const items: TravelTimelineItem[] = this.currentTimeline(this.currentPlan())
    const sourceIndex: number = this.timelineItemIndex(items, placeId)
    if (sourceIndex < 0) {
      return
    }
    const step: number = Math.round(event.offsetY / 154)
    let targetIndex: number = sourceIndex + step
    if (targetIndex < 0) {
      targetIndex = 0
    }
    if (targetIndex >= items.length) {
      targetIndex = items.length - 1
    }
    this.dragTargetPlaceId = items[targetIndex].place.id
    if (event.offsetY < -140) {
      this.placeDragOffsetY = -140
    } else if (event.offsetY > 140) {
      this.placeDragOffsetY = 140
    } else {
      this.placeDragOffsetY = event.offsetY
    }
  }

  private finishPlaceDrag(placeId: string) {
    if (this.draggingPlaceId !== placeId) {
      return
    }
    const targetPlaceId: string = this.dragTargetPlaceId
    this.draggingPlaceId = ''
    this.dragTargetPlaceId = ''
    this.placeDragOffsetY = 0
    if (targetPlaceId.length === 0 || targetPlaceId === placeId || this.selectedDayId === 'overview') {
      return
    }
    const plan: TravelPlan = this.currentPlan()
    const nextPlan: TravelPlan = this.movePlaceInDay(plan, this.selectedDayId, placeId, targetPlaceId)
    this.updateCurrentPlanKeepingSelection(nextPlan, placeId)
  }

  private cancelPlaceDrag() {
    this.draggingPlaceId = ''
    this.dragTargetPlaceId = ''
    this.placeDragOffsetY = 0
  }

  private timelineItemIndex(items: TravelTimelineItem[], placeId: string): number {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].place.id === placeId) {
        return index
      }
    }
    return -1
  }

  private isPlaceDragTarget(placeId: string): boolean {
    return this.draggingPlaceId.length > 0 && this.dragTargetPlaceId === placeId && this.draggingPlaceId !== placeId
  }

  private placeCardDragOffset(placeId: string): number {
    return this.draggingPlaceId === placeId ? this.placeDragOffsetY : 0
  }

  private beginEditPlace(item: TravelTimelineItem) {
    this.editingPlaceId = item.place.id
    this.editingPlaceQuery = item.place.name
    this.editingPlaceSuggestions = []
    this.isSearchingEditPlace = false
    this.replacingPlaceId = ''
    this.activePlaceActionId = ''
    this.handleEditPlaceInput(item.place.name)
  }

  private closeEditPlacePanel() {
    this.editPlaceSearchSeq += 1
    this.editingPlaceId = ''
    this.editingPlaceQuery = ''
    this.editingPlaceSuggestions = []
    this.isSearchingEditPlace = false
    this.replacingPlaceId = ''
  }

  private async handleEditPlaceInput(value: string) {
    this.editingPlaceQuery = value
    const seq: number = this.editPlaceSearchSeq + 1
    this.editPlaceSearchSeq = seq
    const query: string = value.trim()
    if (query.length < 2) {
      this.editingPlaceSuggestions = []
      this.isSearchingEditPlace = false
      return
    }
    this.isSearchingEditPlace = true
    const suggestions: GooglePlaceSuggestion[] = await GoogleMapService.searchPlaceSuggestions(query)
    if (seq === this.editPlaceSearchSeq) {
      this.editingPlaceSuggestions = suggestions
      this.isSearchingEditPlace = false
    }
  }

  private async chooseEditPlaceSuggestion(suggestion: GooglePlaceSuggestion) {
    if (this.replacingPlaceId.length > 0) {
      return
    }
    const oldPlaceId: string = this.editingPlaceId
    this.replacingPlaceId = suggestion.placeId
    try {
      const detail: GooglePlaceDetail | null = await GoogleMapService.fetchPlaceDetail(suggestion.placeId)
      if (detail === null || detail.title.length === 0) {
        AlertDialog.show({
          title: '无法替换地点',
          message: '没有获取到这个地点的真实坐标，请换一个搜索结果。',
          autoCancel: true,
          primaryButton: {
            value: '知道了',
            action: () => {
            },
          },
        })
        return
      }
      const plan: TravelPlan = this.currentPlan()
      const oldPlace: TravelPlace | null = this.findPlaceById(plan, oldPlaceId)
      if (oldPlace === null) {
        return
      }
      const nextPlace: TravelPlace = this.buildReplacementPlace(plan, oldPlace, detail)
      const nextPlan: TravelPlan = this.replacePlaceInPlan(plan, oldPlaceId, nextPlace)
      this.updateCurrentPlanKeepingSelection(nextPlan, nextPlace.id)
      this.closeEditPlacePanel()
    } catch (e) {
      const err = e as Error
      AlertDialog.show({
        title: '替换失败',
        message: err.message,
        autoCancel: true,
        primaryButton: {
          value: '知道了',
          action: () => {
          },
        },
      })
    } finally {
      this.replacingPlaceId = ''
    }
  }

  private deletePlace(placeId: string) {
    const updatedCards: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      const current: TripCardModel = this.savedPlans[i]
      if (current.id === this.selectedPlanId) {
        const nextPlan: TravelPlan = this.removePlaceFromPlan(current.plan, placeId)
        updatedCards.push(this.buildTripCard(nextPlan))
      } else {
        updatedCards.push(current)
      }
    }
    this.savedPlans = updatedCards
    this.activePlaceActionId = ''
    if (this.focusedPlaceId === placeId) {
      this.focusedPlaceId = ''
    }
  }

  private updateCurrentPlanKeepingSelection(plan: TravelPlan, focusedPlaceId: string) {
    const updatedCards: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      if (this.savedPlans[i].id === this.selectedPlanId) {
        updatedCards.push(this.buildTripCard(plan))
      } else {
        updatedCards.push(this.savedPlans[i])
      }
    }
    this.savedPlans = updatedCards
    this.selectedPlanId = plan.id
    this.focusedPlaceId = focusedPlaceId
    this.activePlaceActionId = ''
  }

  private replaceCurrentPlan(plan: TravelPlan) {
    const updatedCards: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      if (this.savedPlans[i].id === this.selectedPlanId) {
        updatedCards.push(this.buildTripCard(plan))
      } else {
        updatedCards.push(this.savedPlans[i])
      }
    }
    this.savedPlans = updatedCards
    this.selectedPlanId = plan.id
    this.selectedDayId = 'overview'
    this.focusedPlaceId = ''
    this.activePlaceActionId = ''
  }

  private async handleAiPlannerSend() {
    if (this.isAiReplanning) {
      return
    }
    const userText: string = this.aiPlannerInput.trim()
    const alertText: string = this.weatherAlertText.trim()
    if (userText.length === 0 && alertText.length === 0) {
      this.aiPlannerReply = '告诉我想调整什么，比如“下雨了，把下午户外景点换成室内”。'
      return
    }

    this.isAiReplanning = true
    this.aiPlannerReply = '正在读取天气并调整行程...'
    try {
      let weather: WeatherSnapshot | null = this.currentWeather
      if (weather === null) {
        weather = await WeatherService.fetchCurrent(this.currentPlan().region)
        this.currentWeather = weather
      }
      const actualWeather: WeatherSnapshot = weather!
      const reason: string = userText.length > 0 ? userText : alertText
      const nextPlan: TravelPlan = await TravelPlanService.replanPlan(this.currentPlan(), actualWeather, `${reason}。当前天气：${WeatherService.summary(actualWeather)}`)
      this.replaceCurrentPlan(nextPlan)
      this.baselineWeather = actualWeather
      this.weatherAlertText = ''
      this.aiPlannerInput = ''
      this.aiPlannerReply = this.buildAiReplanReply(nextPlan)
    } catch (e) {
      const err = e as Error
      this.aiPlannerReply = `调整失败：${err.message}`
    } finally {
      this.isAiReplanning = false
    }
  }

  private buildAiReplanReply(plan: TravelPlan): string {
    const totalBudgetText: string = plan.totalBudget === undefined ? '总预算待确认' : `总预算 ¥${plan.totalBudget}`
    let mealDay: TravelDayPlan | null = null
    if (this.selectedDayId !== 'overview') {
      for (let index: number = 0; index < plan.days.length; index++) {
        if (plan.days[index].id === this.selectedDayId) {
          mealDay = plan.days[index]
          break
        }
      }
    }
    if (mealDay === null && plan.days.length > 0) {
      mealDay = plan.days[0]
    }
    if (mealDay === null || mealDay.mealPlan === undefined) {
      return `已更新路线与交通连接，${totalBudgetText}。三餐安排请在每日行程中查看。`
    }
    const meals: TravelDayMealPlan = mealDay.mealPlan
    return `已更新路线与交通连接。\n${mealDay.dateLabel} 三餐：早 ${meals.breakfast.restaurantName}；午 ${meals.lunch.restaurantName}；晚 ${meals.dinner.restaurantName}。\n当天预算 ¥${meals.dayBudget}，${totalBudgetText}。`
  }

  private dismissWeatherAlert() {
    if (this.currentWeather !== null) {
      this.baselineWeather = this.currentWeather
    }
    this.weatherAlertText = ''
  }

  private async simulateWeatherChange(worse: boolean) {
    const base: WeatherSnapshot = this.currentWeather === null ? {
      locationName: this.currentPlan().title,
      condition: 'Clear',
      description: '晴',
      temperatureC: 26,
      humidity: 52,
      windSpeed: 3,
      rainMm: 0,
      fetchedAt: new Date().toISOString(),
      severity: 1,
    } : this.currentWeather!
    const simulated: WeatherSnapshot = worse ? {
      locationName: base.locationName,
      condition: 'Rain',
      description: '中雨',
      temperatureC: Math.max(18, base.temperatureC - 3),
      humidity: 88,
      windSpeed: 8,
      rainMm: 5,
      fetchedAt: new Date().toISOString(),
      severity: 3,
    } : {
      locationName: base.locationName,
      condition: 'Clear',
      description: '晴',
      temperatureC: Math.max(22, base.temperatureC + 2),
      humidity: 50,
      windSpeed: 3,
      rainMm: 0,
      fetchedAt: new Date().toISOString(),
      severity: 1,
    }
    this.baselineWeather = base
    this.currentWeather = simulated
    this.weatherAlertText = worse ? WeatherService.alertText(base, simulated) : WeatherService.betterText(base, simulated)
    this.aiPlannerReply = this.weatherAlertText
    this.showAiPlanner = true
    await this.publishWeatherSystemAdvice(worse ? '天气变差，建议调整行程' : '天气转好，可以优化计划', this.weatherAlertText)
  }

  private findPlaceById(plan: TravelPlan, placeId: string): TravelPlace | null {
    for (let i = 0; i < plan.places.length; i++) {
      if (plan.places[i].id === placeId) {
        return plan.places[i]
      }
    }
    return null
  }

  private buildReplacementPlace(plan: TravelPlan, oldPlace: TravelPlace, detail: GooglePlaceDetail): TravelPlace {
    let placeId: string = detail.placeId
    for (let i = 0; i < plan.places.length; i++) {
      if (plan.places[i].id === placeId && plan.places[i].id !== oldPlace.id) {
        placeId = `${detail.placeId}_${Date.now()}`
        break
      }
    }
    const nextPlace: TravelPlace = {
      id: placeId,
      name: detail.title,
      category: detail.category,
      address: detail.address,
      latitude: detail.latitude,
      longitude: detail.longitude,
      openingHours: detail.openingHours,
      recommendedDurationMinutes: oldPlace.recommendedDurationMinutes,
      note: oldPlace.note.length > 0 ? oldPlace.note : '用户手动替换的真实地点',
    }
    return nextPlace
  }

  private replacePlaceInPlan(plan: TravelPlan, oldPlaceId: string, newPlace: TravelPlace): TravelPlan {
    const places: TravelPlace[] = []
    let replaced: boolean = false
    for (let i = 0; i < plan.places.length; i++) {
      if (plan.places[i].id === oldPlaceId) {
        places.push(newPlace)
        replaced = true
      } else {
        places.push(plan.places[i])
      }
    }
    if (!replaced) {
      places.push(newPlace)
    }

    const days: TravelDayPlan[] = []
    for (let i = 0; i < plan.days.length; i++) {
      const day: TravelDayPlan = plan.days[i]
      const rawItems: TravelTimelineItem[] = []
      for (let j = 0; j < day.items.length; j++) {
        const item: TravelTimelineItem = day.items[j]
        const place: TravelPlace = item.place.id === oldPlaceId ? newPlace : item.place
        rawItems.push({
          place: place,
          arriveTime: item.arriveTime,
          leaveTime: item.leaveTime,
          commuteFromPrevious: undefined,
          openStatus: item.place.id === oldPlaceId ? '需确认' : item.openStatus,
        })
      }
      const items: TravelTimelineItem[] = this.recalculateTimelineItems(rawItems)
      const nextDay: TravelDayPlan = {
        id: day.id,
        date: day.date,
        dateLabel: day.dateLabel,
        weekday: day.weekday,
        title: day.title,
        summary: day.summary,
        distanceKm: this.sumTimelineDistance(items),
        items: items,
        mealPlan: day.mealPlan,
      }
      days.push(nextDay)
    }

    let timeline: TravelTimelineItem[] = this.flattenDayItems(days)
    if (timeline.length === 0) {
      const rawTimeline: TravelTimelineItem[] = []
      for (let i = 0; i < plan.timeline.length; i++) {
        const item: TravelTimelineItem = plan.timeline[i]
        const place: TravelPlace = item.place.id === oldPlaceId ? newPlace : item.place
        rawTimeline.push({
          place: place,
          arriveTime: item.arriveTime,
          leaveTime: item.leaveTime,
          commuteFromPrevious: undefined,
          openStatus: item.place.id === oldPlaceId ? '需确认' : item.openStatus,
        })
      }
      timeline = this.recalculateTimelineItems(rawTimeline)
    }
    const nextPlan: TravelPlan = {
      id: plan.id,
      title: plan.title,
      preference: plan.preference,
      places: places,
      timeline: timeline,
      days: days,
      region: this.buildRegionFromPlaces(places, plan.region),
      summary: plan.summary,
      providerTaskId: plan.providerTaskId,
      model: plan.model,
      totalBudget: plan.totalBudget,
    }
    return nextPlan
  }

  private movePlaceInDay(plan: TravelPlan, dayId: string, sourcePlaceId: string, targetPlaceId: string): TravelPlan {
    const days: TravelDayPlan[] = []
    for (let dayIndex: number = 0; dayIndex < plan.days.length; dayIndex++) {
      const day: TravelDayPlan = plan.days[dayIndex]
      let items: TravelTimelineItem[] = day.items
      if (day.id === dayId) {
        items = this.reorderDayItems(day.items, sourcePlaceId, targetPlaceId)
      }
      days.push({
        id: day.id,
        date: day.date,
        dateLabel: day.dateLabel,
        weekday: day.weekday,
        title: day.title,
        summary: day.summary,
        distanceKm: this.sumTimelineDistance(items),
        items,
        mealPlan: day.mealPlan,
      })
    }
    const timeline: TravelTimelineItem[] = this.flattenDayItems(days)
    const places: TravelPlace[] = this.placesFromTimeline(timeline, plan.places)
    return {
      id: plan.id,
      title: plan.title,
      preference: plan.preference,
      places,
      timeline,
      days,
      region: this.buildRegionFromPlaces(places, plan.region),
      summary: plan.summary,
      providerTaskId: plan.providerTaskId,
      model: plan.model,
      totalBudget: plan.totalBudget,
    }
  }

  private reorderDayItems(items: TravelTimelineItem[], sourcePlaceId: string, targetPlaceId: string): TravelTimelineItem[] {
    const sourceIndex: number = this.timelineItemIndex(items, sourcePlaceId)
    const targetIndex: number = this.timelineItemIndex(items, targetPlaceId)
    if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex) {
      return items
    }
    const moved: TravelTimelineItem = items[sourceIndex]
    const withoutMoved: TravelTimelineItem[] = []
    for (let index: number = 0; index < items.length; index++) {
      if (index !== sourceIndex) {
        withoutMoved.push(items[index])
      }
    }
    const ordered: TravelTimelineItem[] = []
    for (let index: number = 0; index <= withoutMoved.length; index++) {
      if (index === targetIndex) {
        ordered.push(moved)
      }
      if (index < withoutMoved.length) {
        ordered.push(withoutMoved[index])
      }
    }
    const slottedItems: TravelTimelineItem[] = []
    for (let index: number = 0; index < ordered.length; index++) {
      const slot: TravelTimelineItem = items[index]
      const movedItem: TravelTimelineItem = ordered[index]
      slottedItems.push({
        place: movedItem.place,
        arriveTime: slot.arriveTime,
        leaveTime: slot.leaveTime,
        commuteFromPrevious: undefined,
        openStatus: movedItem.openStatus,
      })
    }
    return this.recalculateTimelineItems(slottedItems)
  }

  private placesFromTimeline(timeline: TravelTimelineItem[], fallbackPlaces: TravelPlace[]): TravelPlace[] {
    const places: TravelPlace[] = []
    for (let index: number = 0; index < timeline.length; index++) {
      const place: TravelPlace = timeline[index].place
      if (this.placeListHasId(places, place.id) === false) {
        places.push(place)
      }
    }
    for (let index: number = 0; index < fallbackPlaces.length; index++) {
      const place: TravelPlace = fallbackPlaces[index]
      if (this.placeListHasId(places, place.id) === false) {
        places.push(place)
      }
    }
    return places
  }

  private placeListHasId(places: TravelPlace[], placeId: string): boolean {
    for (let index: number = 0; index < places.length; index++) {
      if (places[index].id === placeId) {
        return true
      }
    }
    return false
  }

  private removePlaceFromPlan(plan: TravelPlan, placeId: string): TravelPlan {
    const places: TravelPlace[] = []
    for (let i = 0; i < plan.places.length; i++) {
      if (plan.places[i].id !== placeId) {
        places.push(plan.places[i])
      }
    }
    const days: TravelDayPlan[] = []
    for (let i = 0; i < plan.days.length; i++) {
      const day: TravelDayPlan = plan.days[i]
      const rawItems: TravelTimelineItem[] = []
      for (let j = 0; j < day.items.length; j++) {
        if (day.items[j].place.id !== placeId) {
          rawItems.push({
            place: day.items[j].place,
            arriveTime: day.items[j].arriveTime,
            leaveTime: day.items[j].leaveTime,
            commuteFromPrevious: undefined,
            openStatus: day.items[j].openStatus,
          })
        }
      }
      const items: TravelTimelineItem[] = this.recalculateTimelineItems(rawItems)
      const nextDay: TravelDayPlan = {
        id: day.id,
        date: day.date,
        dateLabel: day.dateLabel,
        weekday: day.weekday,
        title: day.title,
        summary: items.length > 0 ? day.summary : '当天暂无地点',
        distanceKm: this.sumTimelineDistance(items),
        items,
        mealPlan: day.mealPlan,
      }
      days.push(nextDay)
    }
    let timeline: TravelTimelineItem[] = this.flattenDayItems(days)
    if (timeline.length === 0) {
      const rawTimeline: TravelTimelineItem[] = []
      for (let i = 0; i < plan.timeline.length; i++) {
        if (plan.timeline[i].place.id !== placeId) {
          rawTimeline.push({
            place: plan.timeline[i].place,
            arriveTime: plan.timeline[i].arriveTime,
            leaveTime: plan.timeline[i].leaveTime,
            commuteFromPrevious: undefined,
            openStatus: plan.timeline[i].openStatus,
          })
        }
      }
      timeline = this.recalculateTimelineItems(rawTimeline)
    }
    const nextPlan: TravelPlan = {
      id: plan.id,
      title: plan.title,
      preference: plan.preference,
      places,
      timeline,
      days,
      region: this.buildRegionFromPlaces(places, plan.region),
      summary: plan.summary,
      providerTaskId: plan.providerTaskId,
      model: plan.model,
      totalBudget: plan.totalBudget,
    }
    return nextPlan
  }

  private normalizeKeptTimelineItem(item: TravelTimelineItem, removedPlaceId: string, firstInScope: boolean): TravelTimelineItem {
    let commute: CommuteInfo | undefined = item.commuteFromPrevious
    if (firstInScope) {
      commute = undefined
    } else if (commute !== undefined && commute.fromPlaceId === removedPlaceId) {
      commute = undefined
    }
    const nextItem: TravelTimelineItem = {
      place: item.place,
      arriveTime: item.arriveTime,
      leaveTime: item.leaveTime,
      commuteFromPrevious: commute,
      openStatus: item.openStatus,
    }
    return nextItem
  }

  private recalculateTimelineItems(items: TravelTimelineItem[]): TravelTimelineItem[] {
    const nextItems: TravelTimelineItem[] = []
    for (let i = 0; i < items.length; i++) {
      let commute: CommuteInfo | undefined = undefined
      if (i > 0) {
        commute = this.buildCommuteInfo(items[i - 1].place, items[i].place)
      }
      nextItems.push({
        place: items[i].place,
        arriveTime: items[i].arriveTime,
        leaveTime: items[i].leaveTime,
        commuteFromPrevious: commute,
        openStatus: items[i].openStatus,
      })
    }
    return nextItems
  }

  private buildCommuteInfo(fromPlace: TravelPlace, toPlace: TravelPlace): CommuteInfo {
    const distanceKm: number = this.roundOne(this.distanceBetweenPlaces(fromPlace, toPlace))
    let durationMinutes: number = 0
    let transport: string = '公共交通'
    if (distanceKm < 1.2) {
      durationMinutes = Math.max(8, Math.round(distanceKm / 4.2 * 60))
      transport = '步行'
    } else if (distanceKm < 8) {
      durationMinutes = Math.max(12, Math.round(distanceKm / 18 * 60) + 5)
      transport = '打车'
    } else {
      durationMinutes = Math.max(20, Math.round(distanceKm / 24 * 60) + 8)
      transport = '公共交通'
    }
    const commute: CommuteInfo = {
      fromPlaceId: fromPlace.id,
      toPlaceId: toPlace.id,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      transport: transport,
    }
    return commute
  }

  private distanceBetweenPlaces(fromPlace: TravelPlace, toPlace: TravelPlace): number {
    const earthRadiusKm: number = 6371
    const fromLat: number = this.toRadians(fromPlace.latitude)
    const toLat: number = this.toRadians(toPlace.latitude)
    const latDelta: number = this.toRadians(toPlace.latitude - fromPlace.latitude)
    const lngDelta: number = this.toRadians(toPlace.longitude - fromPlace.longitude)
    const a: number = Math.sin(latDelta / 2) * Math.sin(latDelta / 2) +
      Math.cos(fromLat) * Math.cos(toLat) * Math.sin(lngDelta / 2) * Math.sin(lngDelta / 2)
    const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return earthRadiusKm * c
  }

  private toRadians(value: number): number {
    return value * Math.PI / 180
  }

  private roundOne(value: number): number {
    return Math.round(value * 10) / 10
  }

  private sumTimelineDistance(items: TravelTimelineItem[]): number {
    let total: number = 0
    for (let i = 0; i < items.length; i++) {
      const commute: CommuteInfo | undefined = items[i].commuteFromPrevious
      if (commute !== undefined) {
        total += commute.distanceKm
      }
    }
    return this.roundOne(total)
  }

  private flattenDayItems(days: TravelDayPlan[]): TravelTimelineItem[] {
    const items: TravelTimelineItem[] = []
    for (let i = 0; i < days.length; i++) {
      for (let j = 0; j < days[i].items.length; j++) {
        items.push(days[i].items[j])
      }
    }
    return items
  }

  private buildRegionFromPlaces(places: TravelPlace[], fallback: SelectedRegion): SelectedRegion {
    if (places.length === 0) {
      return fallback
    }
    let north: number = places[0].latitude
    let south: number = places[0].latitude
    let east: number = places[0].longitude
    let west: number = places[0].longitude
    for (let i = 1; i < places.length; i++) {
      north = Math.max(north, places[i].latitude)
      south = Math.min(south, places[i].latitude)
      east = Math.max(east, places[i].longitude)
      west = Math.min(west, places[i].longitude)
    }
    const latPadding: number = Math.max(0.01, (north - south) * 0.22)
    const lngPadding: number = Math.max(0.01, (east - west) * 0.22)
    const region: SelectedRegion = {
      north: north + latPadding,
      south: south - latPadding,
      east: east + lngPadding,
      west: west - lngPadding,
      centerLat: (north + south) / 2,
      centerLng: (east + west) / 2,
      zoom: fallback.zoom,
    }
    return region
  }

  private detailSheetHeight(): string {
    if (this.detailSheetLevel <= 0) {
      return '38%'
    }
    if (this.detailSheetLevel >= 2) {
      return '78%'
    }
    return '56%'
  }

  private moveDetailSheetUp() {
    if (this.detailSheetLevel < 2) {
      this.detailSheetLevel += 1
    }
    this.detailSheetDragOffset = 0
  }

  private moveDetailSheetDown() {
    if (this.detailSheetLevel > 0) {
      this.detailSheetLevel -= 1
    }
    this.detailSheetDragOffset = 0
  }

  private boundedDetailSheetDragOffset(offsetY: number): number {
    let bounded: number = offsetY
    if (this.detailSheetLevel >= 2 && offsetY < 0) {
      bounded = offsetY * 0.25
    }
    if (this.detailSheetLevel <= 0 && offsetY > 0) {
      bounded = offsetY * 0.25
    }
    if (bounded < -160) {
      return -160
    }
    if (bounded > 160) {
      return 160
    }
    return bounded
  }

  private detailSheetBottomFillHeight(): number {
    if (this.detailSheetDragOffset < 0) {
      return -this.detailSheetDragOffset + 2
    }
    return 0
  }

  private updateDetailSheetDrag(event: GestureEvent) {
    this.detailSheetDragOffset = this.boundedDetailSheetDragOffset(event.offsetY)
  }

  private finishDetailSheetDrag(event: GestureEvent) {
    if (event.offsetY < -28) {
      this.moveDetailSheetUp()
    } else if (event.offsetY > 28) {
      this.moveDetailSheetDown()
    } else {
      this.detailSheetDragOffset = 0
    }
  }

  private togglePlanSearch() {
    this.showPlanSearch = !this.showPlanSearch
    if (!this.showPlanSearch) {
      this.planSearchQuery = ''
    }
  }

  private cyclePlanFilter() {
    if (this.planFilterMode === 'all') {
      if (this.placeFilterLabels().length > 1) {
        this.planFilterMode = 'place'
      } else if (this.durationFilterLabels().length > 1) {
        this.planFilterMode = 'days'
      } else {
        this.planFilterMode = 'all'
      }
    } else if (this.planFilterMode === 'place') {
      if (this.durationFilterLabels().length > 1) {
        this.planFilterMode = 'days'
      } else {
        this.planFilterMode = 'all'
      }
    } else {
      this.planFilterMode = 'all'
    }
    this.selectedPlaceFilter = '全部'
    this.selectedDurationFilter = '全部'
  }

  private planFilterLabel(): string {
    if (this.planFilterMode === 'place') {
      return '地点'
    }
    if (this.planFilterMode === 'days') {
      return '天数'
    }
    return '全部'
  }

  private filteredPlans(): TripCardModel[] {
    const result: TripCardModel[] = []
    for (let i = 0; i < this.savedPlans.length; i++) {
      const plan: TripCardModel = this.savedPlans[i]
      if (this.matchesPlanSearch(plan) && this.matchesPlanFilter(plan)) {
        result.push(plan)
      }
    }
    return result
  }

  private matchesPlanSearch(plan: TripCardModel): boolean {
    const query: string = this.planSearchQuery.trim().toLowerCase()
    if (query.length === 0) {
      return true
    }
    const text: string = this.planSearchText(plan).toLowerCase()
    return text.indexOf(query) >= 0
  }

  private planSearchText(plan: TripCardModel): string {
    let text: string = `${plan.title} ${plan.summaryText} ${plan.dateRangeText} ${plan.durationText} ${plan.placeCountText}`
    for (let i = 0; i < plan.plan.places.length; i++) {
      text = `${text} ${plan.plan.places[i].name} ${plan.plan.places[i].address}`
    }
    return text
  }

  private matchesPlanFilter(plan: TripCardModel): boolean {
    if (this.planFilterMode === 'place') {
      if (this.selectedPlaceFilter === '全部') {
        return true
      }
      return this.planLocationLabel(plan) === this.selectedPlaceFilter
    }
    if (this.planFilterMode === 'days') {
      if (this.selectedDurationFilter === '全部') {
        return true
      }
      return this.planDurationGroup(plan) === this.selectedDurationFilter
    }
    return true
  }

  private planLocationLabel(plan: TripCardModel): string {
    if (plan.title.indexOf('杭州') >= 0) {
      return '杭州'
    }
    for (let i = 0; i < plan.plan.places.length; i++) {
      const address: string = plan.plan.places[i].address
      if (address.indexOf('杭州') >= 0) {
        return '杭州'
      }
      if (address.indexOf('北京') >= 0) {
        return '北京'
      }
      if (address.indexOf('上海') >= 0) {
        return '上海'
      }
      if (address.indexOf('广州') >= 0) {
        return '广州'
      }
      if (address.indexOf('深圳') >= 0) {
        return '深圳'
      }
    }
    return '其他'
  }

  private planDurationGroup(plan: TripCardModel): string {
    const dayCount: number = TravelPlanService.getDayCount(plan.plan.preference.startDate, plan.plan.preference.endDate)
    if (dayCount <= 3) {
      return '1-3天'
    }
    return '4天及以上'
  }

  private placeFilterLabels(): string[] {
    const labels: string[] = ['全部']
    for (let i = 0; i < this.savedPlans.length; i++) {
      const label: string = this.planLocationLabel(this.savedPlans[i])
      if (!this.hasString(labels, label)) {
        labels.push(label)
      }
    }
    return labels
  }

  private durationFilterLabels(): string[] {
    const labels: string[] = ['全部']
    for (let i = 0; i < this.savedPlans.length; i++) {
      const label: string = this.planDurationGroup(this.savedPlans[i])
      if (!this.hasString(labels, label)) {
        labels.push(label)
      }
    }
    return labels
  }

  private hasString(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true
      }
    }
    return false
  }

  @Builder
  PlanBackgroundPhoto() {
    Stack() {
      Image(PLAN_BACKGROUND_IMAGES[this.planBackgroundIndex])
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(APP_COLORS.BACKGROUND)
        .opacity(0.82)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PlansPage() {
    Stack() {
      this.PlanBackgroundPhoto()
      Column() {
      Row() {
        Text('WanderSketch')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Blank()
        Text('⌕')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
        .onClick(() => {
          this.togglePlanSearch()
        })
      }
      .width('100%')
      .padding({ left: 22, right: 20, top: 36 })
      .alignItems(VerticalAlign.Center)

      if (this.showPlanSearch) {
        Row() {
          Text('⌕')
            .fontSize(16)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
            .width(28)
          TextInput({
            text: this.planSearchQuery,
            placeholder: '搜索计划、地点或日期',
          })
            .layoutWeight(1)
            .height(38)
            .fontSize(15)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .placeholderColor(APP_COLORS.TEXT_TERTIARY)
            .backgroundColor('rgba(0,0,0,0)')
            .onChange((value: string) => {
              this.planSearchQuery = value
            })
          if (this.planSearchQuery.length > 0) {
            Text('×')
              .fontSize(18)
              .fontColor(APP_COLORS.TEXT_TERTIARY)
              .width(28)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.planSearchQuery = ''
              })
          }
        }
        .width('89%')
        .height(48)
        .padding({ left: 14, right: 10 })
        .backgroundColor(APP_COLORS.SURFACE_MUTED)
        .borderRadius(18)
        .margin({ top: 16 })
      }

      Row() {
        Text('我的计划')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Blank()
        Row() {
          Text('≡')
            .fontSize(17)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
            .margin({ right: 6 })
          Text(this.planFilterLabel())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
        }
        .height(36)
        .padding({ left: 14, right: 16 })
        .backgroundColor(APP_COLORS.SURFACE_MUTED)
        .borderRadius(18)
        .onClick(() => {
          this.cyclePlanFilter()
        })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: this.showPlanSearch ? 18 : 32 })
      .alignItems(VerticalAlign.Center)

      if (this.planFilterMode === 'place') {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.placeFilterLabels(), (label: string) => {
              this.PlanFilterChip(label, this.selectedPlaceFilter === label, 'place')
            }, (label: string) => label)
          }
          .padding({ left: 22, right: 22 })
        }
        .width('100%')
        .height(46)
        .scrollable(ScrollDirection.Horizontal)
        .margin({ top: 14 })
      } else if (this.planFilterMode === 'days') {
        Row({ space: 10 }) {
          ForEach(this.durationFilterLabels(), (label: string) => {
            this.PlanFilterChip(label, this.selectedDurationFilter === label, 'days')
          }, (label: string) => label)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 14 })
      }

      if (this.filteredPlans().length > 0) {
        List({ space: 0 }) {
          ForEach(this.filteredPlans(), (plan: TripCardModel, index: number) => {
            ListItem() {
              Row() {
                this.PlanCard(plan, index)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
          }, (plan: TripCardModel) => plan.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ top: 10, bottom: 96 })
      } else {
        Column() {
          Text(this.savedPlans.length > 0 ? '没有匹配的计划' : '还没有行程')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
          Text(this.savedPlans.length > 0 ? '换个关键词或分类再试试' : '点击底部加号，新建你的第一条旅行计划')
            .fontSize(14)
            .fontColor(APP_COLORS.TEXT_TERTIARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.BACKGROUND)
  }

  @Builder
  PlanFilterChip(label: string, active: boolean, kind: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(active ? APP_COLORS.SURFACE : APP_COLORS.TEXT_SECONDARY)
      .height(32)
      .padding({ left: 14, right: 14 })
      .backgroundColor(active ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.SURFACE_MUTED)
      .borderRadius(16)
      .onClick(() => {
        if (kind === 'place') {
          this.selectedPlaceFilter = label
        } else {
          this.selectedDurationFilter = label
        }
      })
  }

  private planThumbVariant(index: number): number {
    return index % 3
  }

  private planThumbPhoto(plan: TripCardModel, index: number): string {
    const photos: string[] = TravelPhotoService.resolvePlanPhotos(plan.plan)
    if (photos.length === 0) {
      return ''
    }
    return photos[index % photos.length]
  }

  @Builder
  PlanThumb(plan: TripCardModel, index: number) {
    Stack() {
      if (this.planThumbVariant(index) === 0) {
        this.PlanThumbVariantA(plan)
      } else if (this.planThumbVariant(index) === 1) {
        this.PlanThumbVariantB(plan)
      } else {
        this.PlanThumbVariantC(plan)
      }
    }
    .width(104)
    .height(60)
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  PlanThumbVariantA(plan: TripCardModel) {
    Stack() {
      Image(this.planThumbPhoto(plan, 0))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(24, 56, 55, 0.08)')
      Column()
        .width('100%')
        .height(26)
        .backgroundColor('rgba(253,254,253,0.22)')
        .position({ x: 0, y: 34 })
      Column()
        .width(18)
        .height(18)
        .backgroundColor('rgba(253,254,253,0.94)')
        .borderRadius(9)
        .position({ x: 14, y: 10 })
      Text('西湖')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .position({ x: 38, y: 8 })
      Text('实拍')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
        .position({ x: 38, y: 25 })
    }
  }

  @Builder
  PlanThumbVariantB(plan: TripCardModel) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(APP_COLORS.WARNING_SOFT)
      Image(this.planThumbPhoto(plan, 1))
        .width(84)
        .height(60)
        .objectFit(ImageFit.Cover)
        .borderRadius(16)
        .position({ x: 10, y: 6 })
      Column()
        .width(84)
        .height(60)
        .backgroundColor('rgba(24,56,55,0.12)')
        .borderRadius(16)
        .position({ x: 10, y: 6 })
      Column()
        .width(30)
        .height(30)
        .backgroundColor('rgba(253,254,253,0.92)')
        .borderRadius(15)
        .position({ x: 56, y: 10 })
      Text(plan.placeCountText)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .position({ x: 56, y: 44 })
      Text('湖景')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .position({ x: 12, y: 41 })
      Text('真实照片')
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .position({ x: 12, y: 55 })
    }
  }

  @Builder
  PlanThumbVariantC(plan: TripCardModel) {
    Stack() {
      Image(this.planThumbPhoto(plan, 2))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(16, 18, 24, 0.18)')
      Column()
        .width(64)
        .height(22)
        .backgroundColor('rgba(253,254,253,0.86)')
        .borderRadius(11)
        .position({ x: 10, y: 8 })
      Text(plan.countdownLabel)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .position({ x: 18, y: 10 })
      Column()
        .width(82)
        .height(12)
        .backgroundColor('rgba(253,254,253,0.68)')
        .borderRadius(6)
        .position({ x: 12, y: 40 })
      Column()
        .width(26)
        .height(26)
        .backgroundColor('rgba(253,254,253,0.92)')
        .borderRadius(13)
        .position({ x: 66, y: 30 })
      Text('西湖夜色')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .position({ x: 14, y: 52 })
    }
  }

  @Builder
  CalendarTinyIcon() {
    Stack() {
      Column()
        .width(13)
        .height(12)
        .border({ width: 1.4, color: APP_COLORS.TEXT_PRIMARY })
        .borderRadius(3)
        .position({ x: 1, y: 3 })
      Row() {
        Column()
          .width(2)
          .height(4)
          .backgroundColor(APP_COLORS.TEXT_PRIMARY)
          .borderRadius(1)
        Blank()
        Column()
          .width(2)
          .height(4)
          .backgroundColor(APP_COLORS.TEXT_PRIMARY)
          .borderRadius(1)
      }
      .width(10)
      .position({ x: 2.5, y: 1 })
    }
    .width(15)
    .height(16)
  }

  @Builder
  PlanCard(plan: TripCardModel, index: number) {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        Row({ space: 8 }) {
          Button('改名')
            .width(66)
            .height(42)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .backgroundColor(APP_COLORS.SURFACE)
            .borderRadius(15)
            .onClick(() => {
              this.beginRenamePlan(plan)
            })
          Button('删除')
            .width(66)
            .height(42)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .backgroundColor(APP_COLORS.DANGER)
            .borderRadius(15)
            .onClick(() => {
              this.deletePlan(plan.id)
            })
        }
        .height(146)
        .padding({ right: 10 })
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.BottomEnd }) {
          Row() {
          Column() {
            Row() {
              Row() {
                Column() {
                  this.CalendarTinyIcon()
                }
                .margin({ right: 4 })
                Text(plan.countdownLabel)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.TEXT_PRIMARY)
              }
              .height(24)
              .padding({ left: 9, right: 10 })
              .backgroundColor(APP_COLORS.SURFACE)
              .borderRadius(14)
              Blank()
            }
            .width('100%')

            Text(plan.title)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 8 })

            Row() {
              Column()
                .width(3)
                .height(34)
                .backgroundColor('rgba(23,107,104,0.12)')
                .borderRadius(2)
                .margin({ right: 13, top: 2 })
              Column() {
                Text(`${plan.dateRangeText} ${plan.durationText}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.TEXT_SECONDARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(plan.placeCountText)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.TEXT_SECONDARY)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .margin({ top: 8 })

            Text(plan.summaryText)
              .fontSize(11)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .padding({ left: 18, right: 10, top: 14, bottom: 14 })

          Column() {
            this.PlanThumb(plan, index)
          }
          .width(108)
          .height(84)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ right: 14 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .backgroundColor(APP_COLORS.ACCENT_SOFT)
          .borderRadius(18)
          .translate({ x: this.activePlanActionId === plan.id ? -150 : 0, y: 0 })
          .gesture(PanGesture({ direction: PanDirection.Horizontal }).onActionEnd((event: GestureEvent) => {
            this.handlePlanCardPanEnd(plan.id, event)
          }))
          .onClick(() => {
            if (this.activePlanActionId.length > 0) {
              this.resetPlanActions()
            } else {
              this.openPlan(plan)
            }
          })

          if (this.activePlanActionId !== plan.id) {
            Button('查看海报')
              .width(76)
              .height(28)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(APP_COLORS.SURFACE)
              .backgroundColor('rgba(35, 124, 122, 0.92)')
              .border({ width: 1, color: 'rgba(253,254,253,0.35)' })
              .borderRadius(14)
              .margin({ right: 14, bottom: 12 })
              .onClick(() => {
                this.openPoster(plan)
              })
          }
        }
        .width('100%')
      }
      .width('100%')
      .clip(false)

      if (this.renamingPlanId === plan.id) {
        Row({ space: 8 }) {
          TextInput({ text: this.renamePlanTitle, placeholder: '输入新的计划名称' })
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .backgroundColor(APP_COLORS.SURFACE)
            .borderRadius(12)
            .onChange((value: string) => {
              this.renamePlanTitle = value
            })
          Button('保存')
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .backgroundColor(APP_COLORS.TEXT_PRIMARY)
            .borderRadius(18)
            .onClick(() => {
              this.applyRenamePlan()
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })
      }
    }
    .width('89%')
    .borderRadius(18)
    .margin({ bottom: 18 })
    .clip(false)
  }

  @Builder
  CreatePage() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor(APP_COLORS.DARK_SURFACE)
          .width(40)
          .height(44)
          .onClick(() => {
            this.currentTab = 'plans'
          })
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 22, top: 24 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          Text('你想去哪里？')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .width('100%')
            .margin({ top: 24, bottom: 14 })

          Column() {
            Row() {
              if (this.selectedDestinationName.length > 0) {
                Row() {
                  Column() {
                    Text(this.selectedDestinationName)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(APP_COLORS.TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.selectedDestinationAddress.length > 0) {
                      Text(this.selectedDestinationAddress)
                        .fontSize(11)
                        .fontColor(APP_COLORS.TEXT_SECONDARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Text('×')
                    .fontSize(18)
                    .fontColor(APP_COLORS.TEXT_SECONDARY)
                    .margin({ left: 10 })
                }
                .height(42)
                .padding({ left: 14, right: 12 })
                .backgroundColor(APP_COLORS.SURFACE_MUTED)
                .borderRadius(21)
                .onClick(() => {
                  this.clearDestination()
                })
              }
            }
            .width('100%')

            Row() {
              Text('⌕')
                .fontSize(18)
                .fontColor(APP_COLORS.TEXT_SECONDARY)
                .width(32)
              TextInput({
                text: this.destinationQuery,
                placeholder: '输入目的地或告诉我你的想法',
              })
                .layoutWeight(1)
                .height(36)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
                .placeholderColor(APP_COLORS.TEXT_TERTIARY)
                .backgroundColor('rgba(0,0,0,0)')
                .onChange((value: string) => {
                  this.handleDestinationInput(value)
                })
            }
            .width('100%')
            .margin({ top: this.selectedDestinationName.length > 0 ? 12 : 0 })

            if (this.isSearchingDestination) {
              Text('正在搜索地图地点...')
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_TERTIARY)
                .width('100%')
                .margin({ top: 10 })
            }

            if (this.destinationSuggestions.length > 0) {
              Column() {
                ForEach(this.destinationSuggestions, (item: GooglePlaceSuggestion) => {
                  this.DestinationSuggestionRow(item)
                }, (item: GooglePlaceSuggestion) => item.placeId)
              }
              .width('100%')
              .margin({ top: 10 })
            }
          }
          .width('100%')
          .padding({ left: 20, right: 18, top: 12, bottom: 12 })
          .constraintSize({ minHeight: 76 })
          .backgroundColor(APP_COLORS.SURFACE)
          .borderRadius(24)
          .shadow({ radius: 24, color: 'rgba(31,47,70,0.08)', offsetX: 0, offsetY: 12 })

          Row() {
            Column() {
              Text(this.screenshotUri.length > 0 ? '已上传截图' : '上传截图')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.screenshotUri.length > 0 ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.TEXT_SECONDARY)
              Text(this.screenshotUri.length > 0 ? '将作为规划参考' : '可上传攻略、聊天记录或地图截图')
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_TERTIARY)
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(this.screenshotUri.length > 0 ? '✓' : '+')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.screenshotUri.length > 0 ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.TEXT_TERTIARY)
          }
          .width('100%')
          .height(60)
          .padding({ left: 24, right: 20 })
          .backgroundColor(APP_COLORS.SURFACE)
          .borderRadius(24)
          .shadow({ radius: 24, color: 'rgba(31,47,70,0.08)', offsetX: 0, offsetY: 12 })
          .margin({ top: 14 })
          .onClick(() => {
            this.pickScreenshot()
          })

          Text('你想去多久？')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .width('100%')
            .margin({ top: 40, bottom: 18 })

          Row({ space: 12 }) {
            Column() {
              Text('开始日期')
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_TERTIARY)
              Text(this.startDate)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.hasSelectedDate ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.TEXT_TERTIARY)
                .margin({ top: 5 })
            }
            .layoutWeight(1)
            .height(60)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 18, right: 18 })
            .backgroundColor(APP_COLORS.SURFACE)
            .borderRadius(22)
            .onClick(() => {
              this.showStartDatePicker()
            })

            Column() {
              Text('结束日期')
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_TERTIARY)
              Text(this.endDate)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.hasSelectedDate ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.TEXT_TERTIARY)
                .margin({ top: 5 })
            }
              .layoutWeight(1)
              .height(60)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 18, right: 18 })
              .backgroundColor(APP_COLORS.SURFACE)
              .borderRadius(22)
              .onClick(() => {
                this.showEndDatePicker()
              })
          }
          .width('100%')

          Text('旅游节奏')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .width('100%')
            .margin({ top: 42, bottom: 20 })

          Row({ space: 10 }) {
            this.PreferenceChip(this.preferenceOptions[0])
            this.PreferenceChip(this.preferenceOptions[1])
            this.PreferenceChip(this.preferenceOptions[2])
          }
          .width('100%')

          Text('饮食偏好')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .width('100%')
            .margin({ top: 42, bottom: 20 })

          Column({ space: 12 }) {
            Row({ space: 10 }) {
              this.FoodPreferenceChip(this.foodPreferenceOptions[0])
              this.FoodPreferenceChip(this.foodPreferenceOptions[1])
              this.FoodPreferenceChip(this.foodPreferenceOptions[2])
            }
            Row({ space: 10 }) {
              this.FoodPreferenceChip(this.foodPreferenceOptions[3])
              this.FoodPreferenceChip(this.foodPreferenceOptions[4])
              this.FoodPreferenceChip(this.foodPreferenceOptions[5])
            }
          }
          .width('100%')
          .margin({ bottom: 96 })
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
      }
      .layoutWeight(1)

      if (this.planGenerationError.length > 0) {
        Text(this.planGenerationError)
          .width('89%')
          .fontSize(12)
          .fontColor(APP_COLORS.DANGER)
          .lineHeight(18)
          .margin({ bottom: 10 })
      }

      Button(this.isGeneratingPlan ? '正在生成行程...' : '智能规划')
        .width('89%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .backgroundColor(this.isGeneratingPlan ? APP_COLORS.PRIMARY_ACTIVE : APP_COLORS.PRIMARY)
        .borderRadius(28)
        .shadow({ radius: 16, color: 'rgba(29,139,135,0.22)', offsetX: 0, offsetY: 8 })
        .margin({ bottom: 16 })
        .enabled(!this.isGeneratingPlan)
        .onClick(() => {
          this.handleSmartPlan()
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.SURFACE_MUTED)
  }

  @Builder
  DestinationSuggestionRow(item: GooglePlaceSuggestion) {
    Row() {
      Text('⌖')
        .fontSize(15)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .width(26)
      Column() {
        Text(item.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle.length > 0) {
          Text(item.subtitle)
            .fontSize(11)
            .fontColor(APP_COLORS.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({
      width: 1,
      color: APP_COLORS.BORDER,
    })
    .borderRadius(14)
    .onClick(() => {
      this.chooseDestination(item)
    })
  }

  @Builder
  PreferenceChip(option: PreferenceOption) {
    Row() {
      Text(option.icon)
        .fontSize(13)
        .margin({ right: 6 })
      Text(option.label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasPreference(option.label) ? APP_COLORS.PRIMARY_ACTIVE : APP_COLORS.TEXT_PRIMARY)
    }
    .height(44)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.hasPreference(option.label) ? APP_COLORS.ACCENT_SOFT : APP_COLORS.SURFACE_MUTED)
    .borderRadius(22)
    .border({
      width: 1,
      color: this.hasPreference(option.label) ? APP_COLORS.PRIMARY : APP_COLORS.BORDER,
    })
    .shadow({
      radius: this.hasPreference(option.label) ? 10 : 0,
      color: this.hasPreference(option.label) ? 'rgba(29,139,135,0.14)' : 'transparent',
      offsetX: 0,
      offsetY: 4,
    })
    .onClick(() => {
      this.togglePreference(option.label)
    })
  }

  @Builder
  FoodPreferenceChip(option: PreferenceOption) {
    Row() {
      Text(option.icon)
        .fontSize(13)
        .margin({ right: 6 })
      Text(option.label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasFoodPreference(option.label) ? APP_COLORS.PRIMARY : APP_COLORS.TEXT_PRIMARY)
    }
    .height(44)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.hasFoodPreference(option.label) ? APP_COLORS.ACCENT_SOFT : APP_COLORS.SURFACE_MUTED)
    .borderRadius(22)
    .border({
      width: 1,
      color: this.hasFoodPreference(option.label) ? APP_COLORS.PRIMARY : APP_COLORS.BORDER,
    })
    .shadow({
      radius: this.hasFoodPreference(option.label) ? 10 : 0,
      color: this.hasFoodPreference(option.label) ? 'rgba(15,118,110,0.12)' : 'transparent',
      offsetX: 0,
      offsetY: 4,
    })
    .onClick(() => {
      this.toggleFoodPreference(option.label)
    })
  }

  @Builder
  AiPlannerEntry() {
    Row() {
      Text('AI')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.weatherAlertText.length > 0 ? APP_COLORS.SURFACE : APP_COLORS.PRIMARY)
      if (this.weatherAlertText.length > 0) {
        Column()
          .width(7)
          .height(7)
          .backgroundColor(APP_COLORS.DANGER)
          .borderRadius(4)
          .margin({ left: 5 })
      }
    }
    .width(48)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.weatherAlertText.length > 0 ? APP_COLORS.PRIMARY : APP_COLORS.ACCENT_SOFT)
    .border({
      width: 1,
      color: this.weatherAlertText.length > 0 ? 'rgba(253,254,253,0.30)' : APP_COLORS.ACCENT_SOFT,
    })
    .borderRadius(22)
    .shadow({ radius: 18, color: 'rgba(29,139,135,0.16)', offsetX: 0, offsetY: 8 })
    .margin({ left: 10 })
    .onClick(() => {
      this.showAiPlanner = !this.showAiPlanner
      this.refreshDetailWeather(false)
    })
  }

  @Builder
  CollaborationPanel() {
    Column() {
      Row() {
        Column() {
          Text('共同编辑')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
          Text(`${this.collaborationMembers.length} 位成员正在协作`)
            .fontSize(12)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('×')
          .fontSize(25)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.showCollaborationPanel = false
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        Text('邀请码')
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
        Text(this.collaborationInviteCode())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.PRIMARY)
          .layoutWeight(1)
        Button('复制')
          .height(30)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(APP_COLORS.PRIMARY)
          .backgroundColor(APP_COLORS.ACCENT_SOFT)
          .borderRadius(15)
          .onClick(() => {
            this.copyCollaborationInvite()
          })
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 8, bottom: 8 })
      .backgroundColor(APP_COLORS.ACCENT_SOFT)
      .borderRadius(12)
      .margin({ top: 14 })

      Text('协作成员')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .width('100%')
        .margin({ top: 16, bottom: 8 })

      ForEach(this.collaborationMembers, (member: CollaborationMember) => {
        Row({ space: 10 }) {
          Text(member.name.substring(0, 1))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor(member.color)
            .borderRadius(16)
          Column() {
            Text(member.name)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
            Text(member.status)
              .fontSize(11)
              .fontColor(member.id === 'owner' ? APP_COLORS.PRIMARY : APP_COLORS.TEXT_TERTIARY)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          if (member.id === 'owner') {
            Text('创建者')
              .fontSize(11)
              .fontColor(APP_COLORS.PRIMARY)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(APP_COLORS.ACCENT_SOFT)
              .borderRadius(10)
          } else {
            Text(member.permission)
              .fontSize(11)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(APP_COLORS.SURFACE_MUTED)
              .borderRadius(10)
              .onClick(() => {
                this.toggleCollaborationPermission(member.id)
              })
          }
        }
        .width('100%')
        .padding({ top: 7, bottom: 7 })
      }, (member: CollaborationMember) => member.id)

      Text('邀请同行人')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .width('100%')
        .margin({ top: 12, bottom: 8 })

      TextInput({ text: this.collaborationInvitee, placeholder: '输入同行人昵称' })
        .width('100%')
        .height(40)
        .fontSize(13)
        .backgroundColor(APP_COLORS.SURFACE_MUTED)
        .borderRadius(12)
        .onChange((value: string) => {
          this.collaborationInvitee = value
        })

      Row({ space: 8 }) {
        Button('可编辑')
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .fontColor(this.collaborationPermission === '可编辑' ? APP_COLORS.SURFACE : APP_COLORS.TEXT_SECONDARY)
          .backgroundColor(this.collaborationPermission === '可编辑' ? APP_COLORS.PRIMARY : APP_COLORS.SURFACE_MUTED)
          .borderRadius(17)
          .onClick(() => {
            this.collaborationPermission = '可编辑'
          })
        Button('仅查看')
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .fontColor(this.collaborationPermission === '仅查看' ? APP_COLORS.SURFACE : APP_COLORS.TEXT_SECONDARY)
          .backgroundColor(this.collaborationPermission === '仅查看' ? APP_COLORS.PRIMARY : APP_COLORS.SURFACE_MUTED)
          .borderRadius(17)
          .onClick(() => {
            this.collaborationPermission = '仅查看'
          })
        Button('发送邀请')
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.SURFACE)
          .backgroundColor(APP_COLORS.TEXT_PRIMARY)
          .borderRadius(17)
          .onClick(() => {
            this.addCollaborationMember()
          })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.collaborationFeedback.length > 0) {
        Text(this.collaborationFeedback)
          .fontSize(12)
          .fontColor(APP_COLORS.PRIMARY)
          .width('100%')
          .margin({ top: 10 })
      }
    }
    .width('88%')
    .padding(16)
    .backgroundColor('rgba(253,254,253,0.98)')
    .borderRadius(20)
    .shadow({ radius: 24, color: 'rgba(22,32,48,0.20)', offsetX: 0, offsetY: 10 })
    .position({ x: 22, y: 92 })
    .zIndex(40)
  }

  @Builder
  AiPlannerPanel() {
    Column() {
      Row() {
        Text('AI 行程助手')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Blank()
        Text('×')
          .fontSize(22)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.showAiPlanner = false
          })
      }
      .width('100%')

      Text(WeatherService.summary(this.currentWeather))
        .fontSize(12)
        .fontColor(APP_COLORS.PRIMARY)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ top: 6 })

      Row({ space: 8 }) {
        Button('模拟转雨')
          .height(30)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .backgroundColor(APP_COLORS.INFO_SOFT)
          .borderRadius(15)
          .onClick(() => {
            this.simulateWeatherChange(true)
          })
        Button('模拟转好')
          .height(30)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .backgroundColor(APP_COLORS.SUCCESS_SOFT)
          .borderRadius(15)
          .onClick(() => {
            this.simulateWeatherChange(false)
          })
      }
      .width('100%')
      .margin({ top: 10 })

      Row({ space: 8 }) {
        Button('5秒后台测试')
          .height(30)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .backgroundColor(APP_COLORS.SURFACE_MUTED)
          .borderRadius(15)
          .onClick(() => {
            this.scheduleBackgroundNotificationTest()
          })
        Button('通知设置')
          .height(30)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .backgroundColor(APP_COLORS.SURFACE_MUTED)
          .borderRadius(15)
          .onClick(() => {
            this.openSystemNotificationSettings()
          })
      }
      .width('100%')
      .margin({ top: 8 })

      if (this.weatherAlertText.length > 0) {
        Column() {
          Text(this.weatherAlertText)
            .fontSize(12)
            .fontColor(APP_COLORS.DANGER)
            .lineHeight(18)
            .width('100%')
          Row({ space: 8 }) {
            Button('按天气调整')
              .height(32)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.SURFACE)
              .backgroundColor(APP_COLORS.TEXT_PRIMARY)
              .borderRadius(16)
              .enabled(!this.isAiReplanning)
              .onClick(() => {
                this.handleAiPlannerSend()
              })
            Button('忽略')
              .height(32)
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .backgroundColor(APP_COLORS.SURFACE)
              .borderRadius(16)
              .onClick(() => {
                this.dismissWeatherAlert()
              })
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(10)
        .backgroundColor(APP_COLORS.WARNING_SOFT)
        .borderRadius(12)
        .margin({ top: 10 })
      }

      Text(this.aiPlannerReply)
        .fontSize(13)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .lineHeight(19)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 12 })

      TextInput({ text: this.aiPlannerInput, placeholder: '例如：下雨了，把下午户外景点换成室内' })
        .width('100%')
        .height(42)
        .fontSize(13)
        .backgroundColor(APP_COLORS.SURFACE_MUTED)
        .borderRadius(14)
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.aiPlannerInput = value
        })

      Row() {
        if (this.isAiReplanning) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(APP_COLORS.TEXT_PRIMARY)
            .margin({ right: 8 })
        }
        Text(this.isAiReplanning ? '调整中' : '发送')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.SURFACE)
      }
      .width('100%')
      .height(42)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isAiReplanning ? APP_COLORS.TEXT_SECONDARY : APP_COLORS.TEXT_PRIMARY)
      .borderRadius(21)
      .margin({ top: 12 })
      .onClick(() => {
        this.handleAiPlannerSend()
      })
    }
    .width('86%')
    .padding(14)
    .backgroundColor('rgba(253,254,253,0.96)')
    .borderRadius(18)
    .shadow({ radius: 24, color: 'rgba(22,32,48,0.18)', offsetX: 0, offsetY: 10 })
    .position({ x: 18, y: 88 })
    .zIndex(30)
  }

  @Builder
  EditPlacePanel() {
    Column() {
      Row() {
        Text('替换地点')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Blank()
        Text('×')
          .fontSize(24)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.closeEditPlacePanel()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({ text: this.editingPlaceQuery, placeholder: '搜索真实地点' })
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor(APP_COLORS.SURFACE_MUTED)
        .borderRadius(14)
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.handleEditPlaceInput(value)
        })

      if (this.isSearchingEditPlace) {
        Row() {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(APP_COLORS.TEXT_PRIMARY)
            .margin({ right: 8 })
          Text('搜索中')
            .fontSize(13)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
        }
        .width('100%')
        .height(44)
        .justifyContent(FlexAlign.Center)
      } else if (this.editingPlaceSuggestions.length > 0) {
        Column() {
          ForEach(this.editingPlaceSuggestions, (suggestion: GooglePlaceSuggestion) => {
            Row() {
              Column() {
                Text(suggestion.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                if (suggestion.subtitle.length > 0) {
                  Text(suggestion.subtitle)
                    .fontSize(12)
                    .fontColor(APP_COLORS.TEXT_TERTIARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 4 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (this.replacingPlaceId === suggestion.placeId) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color(APP_COLORS.TEXT_PRIMARY)
              } else {
                Text('选择')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.PRIMARY)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(APP_COLORS.ACCENT_SOFT)
                  .borderRadius(12)
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(APP_COLORS.SURFACE)
            .borderRadius(14)
            .border({ width: 1, color: APP_COLORS.BORDER })
            .margin({ top: 8 })
            .onClick(() => {
              this.chooseEditPlaceSuggestion(suggestion)
            })
          }, (suggestion: GooglePlaceSuggestion) => suggestion.placeId)
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Text('输入地点名称后选择 Google 返回的真实地点')
          .fontSize(13)
          .fontColor(APP_COLORS.TEXT_TERTIARY)
          .width('100%')
          .margin({ top: 14 })
      }
    }
    .width('88%')
    .padding(14)
    .backgroundColor('rgba(253,254,253,0.97)')
    .borderRadius(18)
    .shadow({ radius: 24, color: 'rgba(22,32,48,0.18)', offsetX: 0, offsetY: 10 })
    .position({ x: 18, y: 132 })
    .zIndex(31)
  }

  @Builder
  PlanDetailPage() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        RealMapView({
          initialRegion: this.currentPlan().region,
          items: this.currentTimeline(this.currentPlan()),
          dayItems: this.mapDays(this.currentPlan()),
          showRoute: true,
          onPlaceSelected: (placeId: string) => {
            this.selectPlaceFromMap(placeId)
          },
        })
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')

      Column() {
        Row() {
          Text('<')
            .fontSize(32)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .fontWeight(FontWeight.Bold)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor('rgba(245,248,252,0.78)')
            .border({ width: 1, color: 'rgba(253,254,253,0.94)' })
            .borderRadius(22)
            .shadow({ radius: 18, color: 'rgba(22,32,48,0.18)', offsetX: 0, offsetY: 8 })
            .onClick(() => {
              this.stopDetailWeatherWatch()
              this.currentTab = 'plans'
            })
          this.AiPlannerEntry()
          Blank()
          Row({ space: 5 }) {
            Text('👥')
              .fontSize(16)
            Text('共同编辑')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
          }
          .width(94)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(245,248,252,0.78)')
          .border({ width: 1, color: 'rgba(253,254,253,0.94)' })
          .borderRadius(22)
          .shadow({ radius: 18, color: 'rgba(22,32,48,0.18)', offsetX: 0, offsetY: 8 })
          .onClick(() => {
            this.openCollaborationPanel()
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 34 })
      }
      .width('100%')
      .height(88)
      .zIndex(20)

      if (this.showAiPlanner) {
        this.AiPlannerPanel()
      }

      if (this.showCollaborationPanel) {
        this.CollaborationPanel()
      }

      if (this.editingPlaceId.length > 0) {
        this.EditPlacePanel()
      }

      Column() {
        Row() {
          Blank()
          Column()
            .width(50)
            .height(5)
            .backgroundColor(APP_COLORS.BORDER)
            .borderRadius(3)
          Blank()
        }
        .width('100%')
        .height(36)
        .alignItems(VerticalAlign.Center)
        .gesture(PanGesture({ direction: PanDirection.Vertical })
          .onActionUpdate((event: GestureEvent) => {
            this.updateDetailSheetDrag(event)
          })
          .onActionEnd((event: GestureEvent) => {
            this.finishDetailSheetDrag(event)
          }))

        Text(this.currentPlan().title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 22, right: 22 })

        Row() {
          Text(`${this.currentPlan().preference.startDate.substring(5)}至${this.currentPlan().preference.endDate.substring(5)} ${TravelPlanService.getDayCount(this.currentPlan().preference.startDate, this.currentPlan().preference.endDate)}天${Math.max(0, TravelPlanService.getDayCount(this.currentPlan().preference.startDate, this.currentPlan().preference.endDate) - 1)}晚`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
          Text('›')
            .fontSize(24)
            .fontColor(APP_COLORS.TEXT_TERTIARY)
            .margin({ left: 4 })
          Blank()
          Text(this.currentPlan().places.length + '个地点')
            .fontSize(13)
            .fontColor(APP_COLORS.TEXT_TERTIARY)
            .height(30)
            .padding({ left: 12, right: 12 })
            .backgroundColor(APP_COLORS.SURFACE_MUTED)
            .borderRadius(15)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 12 })

        Row({ space: 22 }) {
          this.DayTab('overview', '总览')
          ForEach(this.currentPlan().days, (day: TravelDayPlan) => {
            this.DayTab(day.id, `${day.dateLabel} ${day.weekday}`)
          }, (day: TravelDayPlan) => day.id)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 22, bottom: 8 })

        Scroll() {
          Column() {
            Text(this.currentDayTitle(this.currentPlan()))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .width('100%')
              .margin({ top: 18 })

            Text(this.currentDaySummary(this.currentPlan()))
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .lineHeight(21)
              .width('100%')
              .margin({ top: 8, bottom: 16 })

            if (this.selectedDayId === 'overview' && this.currentPlan().totalBudget !== undefined && this.currentPlan().totalBudget! > 0) {
              Text(`预计总预算 ¥${this.currentPlan().totalBudget}`)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.PRIMARY)
                .width('100%')
                .margin({ bottom: 14 })
            }

            if (this.selectedDayId === 'overview') {
              ForEach(this.currentPlan().days, (day: TravelDayPlan) => {
                this.DayOverviewCard(day)
              }, (day: TravelDayPlan) => day.id)
            } else {
              ForEach(this.mapDays(this.currentPlan()), (day: TravelDayPlan) => {
                this.DayMealPlanCard(day)
              }, (day: TravelDayPlan) => day.id)
              ForEach(this.currentTimeline(this.currentPlan()), (item: TravelTimelineItem, index: number) => {
                this.PlaceTimelineCard(item, index)
              }, (item: TravelTimelineItem) => item.place.id)
            }
          }
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 34 })
          .onClick(() => {
            if (this.activePlaceActionId.length > 0) {
              this.resetPlaceActions()
            }
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height(this.detailSheetHeight())
      .translate({ x: 0, y: this.detailSheetDragOffset })
      .backgroundColor(APP_COLORS.SURFACE)
      .borderRadius({ topLeft: 28, topRight: 28 })
      .shadow({ radius: 24, color: 'rgba(22,32,48,0.12)', offsetX: 0, offsetY: -8 })

      Column()
        .width('100%')
        .height(this.detailSheetBottomFillHeight())
        .backgroundColor(APP_COLORS.SURFACE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.SURFACE_MUTED)
  }

  @Builder
  DayTab(dayId: string, label: string) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedDayId === dayId ? APP_COLORS.TEXT_PRIMARY : APP_COLORS.TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Column()
        .width(34)
        .height(4)
        .backgroundColor(this.selectedDayId === dayId ? APP_COLORS.INFO : 'rgba(0,0,0,0)')
        .borderRadius(2)
        .margin({ top: 8 })
    }
    .constraintSize({ minWidth: 54 })
    .onClick(() => {
      this.selectDay(dayId)
    })
  }

  @Builder
  DayOverviewCard(day: TravelDayPlan) {
    Column() {
      Row() {
        Text(`${day.dateLabel} ${day.weekday}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Blank()
        Text(`${day.distanceKm}公里`)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(APP_COLORS.ACCENT_SOFT)
          .borderRadius(12)
      }
      .width('100%')

      Text(day.title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .width('100%')
        .margin({ top: 12 })

      Text(day.items.length > 0 ? TravelPlanService.formatShortDate(day.date) + ' ' + day.items[0].place.name + ' → ' + day.items[day.items.length - 1].place.name : day.summary)
        .fontSize(14)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .lineHeight(21)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 10 })

      this.DayMealPlanCard(day)

      Row() {
        Text('查看当天')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.INFO)
        Blank()
        Text('›')
          .fontSize(24)
          .fontColor(APP_COLORS.BORDER)
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(APP_COLORS.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: APP_COLORS.BORDER })
    .shadow({ radius: 16, color: 'rgba(24,37,56,0.06)', offsetX: 0, offsetY: 8 })
    .margin({ bottom: 14 })
    .onClick(() => {
      this.selectDay(day.id)
    })
  }

  @Builder
  DayMealPlanCard(day: TravelDayPlan) {
    if (day.mealPlan !== undefined) {
      Column() {
        Row() {
          Text('每日三餐')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.DARK_SURFACE)
          Blank()
          Text(`预算 ¥${day.mealPlan!.dayBudget}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.PRIMARY)
        }
        .width('100%')

        Row({ space: 8 }) {
          this.MealPlanCell('早', day.mealPlan!.breakfast)
          this.MealPlanCell('午', day.mealPlan!.lunch)
          this.MealPlanCell('晚', day.mealPlan!.dinner)
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(APP_COLORS.ACCENT_SOFT)
      .borderRadius(14)
      .margin({ top: 14 })
    }
  }

  @Builder
  MealPlanCell(label: string, meal: TravelMeal) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.PRIMARY)
      Text(meal.restaurantName)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })
      Text(`¥${meal.estimatedCost}`)
        .fontSize(11)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PlaceTimelineCard(item: TravelTimelineItem, itemIndex: number) {
    Column() {
      if (itemIndex > 0) {
        this.CommuteConnector(this.renderedCommuteItem(item, itemIndex))
      }

      Stack({ alignContent: Alignment.End }) {
        Row({ space: 8 }) {
          Button('编辑')
            .width(76)
            .height(44)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .backgroundColor(APP_COLORS.PRIMARY)
            .borderRadius(16)
            .onClick(() => {
              this.beginEditPlace(item)
            })
          Button('删除')
            .width(76)
            .height(44)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .backgroundColor(APP_COLORS.DANGER)
            .borderRadius(16)
            .onClick(() => {
              this.deletePlace(item.place.id)
            })
        }
        .margin({ right: 8 })

        Column() {
          Row() {
            Column() {
              Text(item.arriveTime)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
              Text(item.leaveTime)
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_TERTIARY)
                .margin({ top: 3 })
            }
            .width(58)
            .alignItems(HorizontalAlign.Start)

            Column()
              .width(10)
              .height(10)
              .backgroundColor(this.focusedPlaceId === item.place.id ? APP_COLORS.INFO : APP_COLORS.INFO)
              .borderRadius(5)
              .margin({ right: 12 })

            Column() {
              Row() {
                Text(item.place.name)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text(this.categoryLabel(item.place.category))
                  .fontSize(11)
                  .fontColor(APP_COLORS.PRIMARY)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(APP_COLORS.ACCENT_SOFT)
                  .borderRadius(10)
                Text('⠿')
                  .fontSize(20)
                  .fontColor(APP_COLORS.TEXT_TERTIARY)
                  .width(30)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .margin({ left: 6 })
                  .gesture(PanGesture({ direction: PanDirection.Vertical })
                    .onActionStart(() => {
                      this.startPlaceDrag(item.place.id)
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      this.updatePlaceDrag(item.place.id, event)
                    })
                    .onActionEnd(() => {
                      this.finishPlaceDrag(item.place.id)
                    })
                    .onActionCancel(() => {
                      this.cancelPlaceDrag()
                    }))
              }
              .width('100%')

              if (this.focusedPlaceId === item.place.id) {
                if (this.detailPlacePhotoLoadingId === item.place.id) {
                  Row() {
                    LoadingProgress()
                      .width(18)
                      .height(18)
                      .color(APP_COLORS.PRIMARY)
                    Text('正在获取地点图片…')
                      .fontSize(12)
                      .fontColor(APP_COLORS.TEXT_SECONDARY)
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .height(128)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(APP_COLORS.ACCENT_SOFT)
                  .borderRadius(12)
                  .margin({ top: 12 })
                } else if (this.detailPlacePhotoUrl(item.place.id).length > 0) {
                  Image(this.detailPlacePhotoUrl(item.place.id))
                    .width('100%')
                    .height(148)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(12)
                    .margin({ top: 12 })
                  Text(this.detailPlacePhotoAttribution(item.place.id))
                    .fontSize(10)
                    .fontColor(APP_COLORS.TEXT_TERTIARY)
                    .width('100%')
                    .margin({ top: 5 })
                } else if (this.hasDetailPlacePhoto(item.place.id)) {
                  Text('暂未获取到此地点图片')
                    .fontSize(12)
                    .fontColor(APP_COLORS.TEXT_TERTIARY)
                    .width('100%')
                    .padding({ top: 16, bottom: 8 })
                }
              }

              if (this.isPlaceDragTarget(item.place.id)) {
                Text('松手后移动到此处')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(APP_COLORS.PRIMARY)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(APP_COLORS.ACCENT_SOFT)
                  .borderRadius(10)
                  .margin({ top: 8 })
              }

              Text(item.place.note)
                .fontSize(13)
                .fontColor(APP_COLORS.TEXT_SECONDARY)
                .lineHeight(19)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .margin({ top: 8 })

              Row() {
                Text(item.openStatus)
                  .fontSize(12)
                  .fontColor(APP_COLORS.SUCCESS)
                Text(item.place.openingHours)
                  .fontSize(12)
                  .fontColor(APP_COLORS.TEXT_TERTIARY)
                  .margin({ left: 10 })
                Blank()
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(16)
        }
        .backgroundColor(this.isPlaceDragTarget(item.place.id) ? APP_COLORS.SUCCESS_SOFT :
          (this.focusedPlaceId === item.place.id ? APP_COLORS.INFO_SOFT : APP_COLORS.SURFACE))
        .borderRadius(16)
        .border({ width: 1, color: this.isPlaceDragTarget(item.place.id) ? APP_COLORS.PRIMARY :
          (this.focusedPlaceId === item.place.id ? APP_COLORS.INFO : APP_COLORS.BORDER) })
        .translate({ x: this.activePlaceActionId === item.place.id ? -168 : 0, y: this.placeCardDragOffset(item.place.id) })
        .opacity(this.draggingPlaceId === item.place.id ? 0.92 : 1)
        .shadow(this.draggingPlaceId === item.place.id ?
          { radius: 24, color: 'rgba(35,124,122,0.28)', offsetX: 0, offsetY: 12 } :
          { radius: 0, color: 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
        .zIndex(this.draggingPlaceId === item.place.id ? 8 : 0)
        .animation({ duration: 160 })
        .gesture(PanGesture({ direction: PanDirection.Horizontal }).onActionEnd((event: GestureEvent) => {
          this.handlePlaceCardPanEnd(item.place.id, event)
        }))
        .onClick(() => {
          if (this.activePlaceActionId.length > 0) {
            this.resetPlaceActions()
          } else {
            this.openPlaceDetail(item)
          }
        })
      }
      .width('100%')
      .clip(false)
    }
    .width('100%')
    .margin({ bottom: 12 })
    .clip(false)
  }

  @Builder
  CommuteConnector(item: TravelTimelineItem) {
    Row() {
      Column()
        .width(2)
        .height(46)
        .backgroundColor(APP_COLORS.SURFACE_SUBTLE)
        .borderRadius(1)
        .margin({ left: 62, right: 13 })
      Row() {
        Text(this.commuteIcon(item))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.commuteIconColor(item))
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.commuteIconBg(item))
          .borderRadius(12)
        Text(this.commuteText(item))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .margin({ left: 8 })
          .lineHeight(16)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text('›')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_TERTIARY)
          .width(18)
          .height(24)
          .textAlign(TextAlign.Center)
      }
      .height(46)
      .layoutWeight(1)
      .padding({ left: 8, right: 10 })
      .backgroundColor(APP_COLORS.SURFACE_MUTED)
      .borderRadius(23)
      .onClick(() => {
        this.showCommuteDetail(item)
      })
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  ExplorePlacePanel() {
    if (this.exploreSelectedPlace !== null) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          if (this.isExplorePlaceLoading) {
            Column() {
              LoadingProgress()
                .color(APP_COLORS.PRIMARY)
              Text('正在加载地点图片…')
                .fontSize(13)
                .fontColor(APP_COLORS.TEXT_SECONDARY)
                .margin({ top: 10 })
            }
            .width('100%')
            .height(150)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(APP_COLORS.ACCENT_SOFT)
          } else if (this.explorePlaceImageUrl.length > 0) {
            Image(this.explorePlaceImageUrl)
              .width('100%')
              .height(150)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text('地点图片暂不可用')
                .fontSize(13)
                .fontColor(APP_COLORS.TEXT_SECONDARY)
            }
            .width('100%')
            .height(150)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(APP_COLORS.ACCENT_SOFT)
          }
          Text('关闭')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.DARK_SURFACE)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor('rgba(253,254,253,0.92)')
            .borderRadius(14)
            .position({ x: 14, y: 12 })
            .onClick(() => {
              this.closeExplorePlacePanel()
            })
        }
        .width('100%')
        .height(150)
        .clip(true)
        .borderRadius({ topLeft: 22, topRight: 22 })
        .margin({ top: 12 })

        Row() {
          Column() {
            Text(this.exploreSelectedPlace!.name)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.categoryLabel(this.exploreSelectedPlace!.category))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.PRIMARY)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .backgroundColor(APP_COLORS.ACCENT_SOFT)
              .borderRadius(10)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .margin({ top: 14 })

        Text(this.exploreSelectedPlace!.note)
          .fontSize(14)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .width('100%')
          .margin({ top: 10 })
        Text(this.exploreSelectedPlace!.address)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8 })
        if (this.exploreSelectedPlace!.openingHours.length > 0) {
          Text(`营业时间 ${this.exploreSelectedPlace!.openingHours}`)
            .fontSize(12)
            .fontColor(APP_COLORS.PRIMARY)
            .width('100%')
            .margin({ top: 6 })
        }
        if (this.explorePlaceImageAttribution.length > 0) {
          Text(this.explorePlaceImageAttribution)
            .fontSize(10)
            .fontColor(APP_COLORS.TEXT_TERTIARY)
            .width('100%')
            .margin({ top: 7 })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 16 })
      .backgroundColor(APP_COLORS.SURFACE)
      .borderRadius({ topLeft: 22, topRight: 22 })
      .clip(true)
      .shadow({ radius: 22, color: 'rgba(22,32,48,0.20)', offsetX: 0, offsetY: -8 })
    }
  }

  @Builder
  ExplorePage() {
    Stack({ alignContent: Alignment.Bottom }) {
      RealMapView({
        initialRegion: HANGZHOU_REGION,
        items: [],
        onPlaceSelected: (placeId: string) => {
          this.selectExplorePlace(placeId)
        },
      })
        .width('100%')
        .height('100%')
      if (this.exploreSelectedPlace !== null) {
        this.ExplorePlacePanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.SURFACE_MUTED)
  }

  @Builder
  BottomNav() {
    Row() {
      this.NavItem('plans', '行程', 'plans')
      this.AddNavItem()
      this.NavItem('explore', '探索', 'explore')
    }
    .width('100%')
    .height(72)
    .padding({ left: 34, right: 34, top: 12 })
    .alignItems(VerticalAlign.Top)
    .backgroundColor(APP_COLORS.SURFACE)
  }

  @Builder
  SuitcaseActiveIcon() {
    Stack() {
      Column()
        .width(20)
        .height(16)
        .backgroundColor(APP_COLORS.DARK_SURFACE)
        .borderRadius(5)
        .position({ x: 2, y: 7 })
      Column()
        .width(10)
        .height(6)
        .backgroundColor(APP_COLORS.DARK_SURFACE)
        .borderRadius({ topLeft: 4, topRight: 4 })
        .position({ x: 7, y: 2 })
    }
    .width(24)
    .height(25)
  }

  @Builder
  SuitcaseInactiveIcon() {
    Stack() {
      Column()
        .width(20)
        .height(16)
        .border({
          width: 2,
          color: APP_COLORS.TEXT_TERTIARY,
        })
        .borderRadius(5)
        .position({ x: 2, y: 7 })
      Column()
        .width(10)
        .height(6)
        .border({
          width: 2,
          color: APP_COLORS.TEXT_TERTIARY,
        })
        .borderRadius({ topLeft: 4, topRight: 4 })
        .position({ x: 7, y: 2 })
    }
    .width(24)
    .height(25)
  }

  @Builder
  ExploreActiveIcon() {
    Stack() {
      Column()
        .width(8)
        .height(8)
        .backgroundColor(APP_COLORS.DARK_SURFACE)
        .borderRadius(2)
        .rotate({ angle: 45 })
        .position({ x: 8, y: 15 })
      Stack() {
        Column()
          .width(22)
          .height(22)
          .backgroundColor(APP_COLORS.DARK_SURFACE)
          .borderRadius(11)
        Column()
          .width(7)
          .height(7)
          .backgroundColor(APP_COLORS.SURFACE)
          .borderRadius(4)
          .position({ x: 7.5, y: 7.5 })
      }
      .width(22)
      .height(22)
      .position({ x: 1, y: 1 })
    }
    .width(24)
    .height(26)
  }

  @Builder
  ExploreInactiveIcon() {
    Stack() {
      Column()
        .backgroundColor(APP_COLORS.TEXT_TERTIARY)
        .width(7)
        .height(7)
        .borderRadius(2)
        .rotate({ angle: 45 })
        .position({ x: 8, y: 15 })
      Stack() {
        Column()
          .width(22)
          .height(22)
          .backgroundColor(APP_COLORS.SURFACE)
          .border({ width: 2, color: APP_COLORS.TEXT_TERTIARY })
          .borderRadius(11)
        Column()
          .width(7)
          .height(7)
          .backgroundColor(APP_COLORS.TEXT_TERTIARY)
          .borderRadius(4)
          .position({ x: 7.5, y: 7.5 })
      }
      .width(22)
      .height(22)
      .position({ x: 1, y: 1 })
    }
    .width(24)
    .height(26)
  }

  @Builder
  AddNavItem() {
    Column() {
      Text('+')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === 'create' ? APP_COLORS.SURFACE : APP_COLORS.TEXT_TERTIARY)
        .textAlign(TextAlign.Center)
        .width(52)
        .height(44)
        .backgroundColor(this.currentTab === 'create' ? APP_COLORS.DARK_SURFACE : APP_COLORS.SURFACE)
        .border({
          width: this.currentTab === 'create' ? 0 : 2,
          color: this.currentTab === 'create' ? APP_COLORS.DARK_SURFACE : APP_COLORS.BORDER,
        })
        .borderRadius(16)
        .onClick(() => {
          this.currentTab = 'create'
        })
    }
    .layoutWeight(1)
    .height('100%')
    .padding({ top: 0 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  NavItem(kind: string, label: string, tab: HomeTab) {
    Column() {
      if (kind === 'plans') {
        if (this.currentTab === tab) {
          this.SuitcaseActiveIcon()
        } else {
          this.SuitcaseInactiveIcon()
        }
      } else {
        if (this.currentTab === tab) {
          this.ExploreActiveIcon()
        } else {
          this.ExploreInactiveIcon()
        }
      }
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === tab ? APP_COLORS.DARK_SURFACE : APP_COLORS.TEXT_TERTIARY)
        .margin({ top: 1 })
    }
    .layoutWeight(1)
    .height('100%')
    .padding({ top: 0 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      if (tab !== 'detail') {
        this.stopDetailWeatherWatch()
      }
      this.currentTab = tab
    })
  }

  private mealPosterColor(meal: TravelPosterMeal): string {
    if (meal.period === 'breakfast') {
      return APP_COLORS.ACCENT
    }
    if (meal.period === 'lunch') {
      return APP_COLORS.ACCENT
    }
    return APP_COLORS.INFO
  }

  private mealPosterIcon(meal: TravelPosterMeal): string {
    if (meal.period === 'breakfast') {
      return '☀'
    }
    if (meal.period === 'lunch') {
      return '🍜'
    }
    return '✦'
  }

  @Builder
  PosterMealCard(meal: TravelPosterMeal) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (meal.imageUrl.length > 0) {
          Image(meal.imageUrl)
            .width('100%')
            .height(88)
            .objectFit(ImageFit.Cover)
        } else {
          Column({ space: 5 }) {
            Text(this.mealPosterIcon(meal))
              .fontSize(23)
              .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
            Text(meal.label)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
          }
          .width('100%')
          .height(88)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.mealPosterColor(meal))
        }
        Text(meal.label)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.DARK_SURFACE)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor(APP_COLORS.PARCHMENT)
          .borderRadius(9)
          .position({ x: 7, y: 7 })
      }
      .width('100%')
      .height(88)
      .clip(true)
      .borderRadius(12)

      Text(meal.restaurantName)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })
      Text(meal.attribution)
        .fontSize(9)
        .fontColor(APP_COLORS.TEXT_ON_DARK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PosterMealDayCard(day: TravelPosterDay) {
    Column() {
      Text(`${day.dateLabel} · 今日三餐`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.PARCHMENT)
        .width('100%')
        .margin({ bottom: 10 })
      Row({ space: 8 }) {
        ForEach(day.meals, (meal: TravelPosterMeal) => {
          this.PosterMealCard(meal)
        }, (meal: TravelPosterMeal) => meal.id)
      }
      .width('100%')
      Text('餐厅实拍优先；未匹配时显示餐食主题图。')
        .fontSize(10)
        .fontColor(APP_COLORS.TEXT_ON_DARK)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(APP_COLORS.DARK_SURFACE)
    .borderRadius(18)
  }

  @Builder
  PosterPlaceCard(item: TravelPosterPlace, index: number) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (item.imageUrl.length > 0) {
          Image(item.imageUrl)
            .width('100%')
            .height(182)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('此处留给下一次相遇的风景')
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
          }
          .width('100%')
          .height(182)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(APP_COLORS.PRIMARY_ACTIVE)
        }
        Text(`${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.DARK_SURFACE)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(APP_COLORS.PARCHMENT)
          .borderRadius(14)
          .position({ x: 14, y: 14 })
      }
      .width('100%')
      .height(182)
      .clip(true)
      .borderRadius(16)
      Text(item.name)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.SURFACE)
        .width('100%')
        .margin({ top: 12 })
      Text(item.description)
        .fontSize(14)
        .fontColor(APP_COLORS.TEXT_ON_DARK)
        .lineHeight(21)
        .width('100%')
        .margin({ top: 6 })
      Text(item.attribution)
        .fontSize(10)
        .fontColor(APP_COLORS.TEXT_ON_DARK)
        .width('100%')
        .margin({ top: 7 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(APP_COLORS.DARK_SURFACE)
    .borderRadius(18)
  }

  @Builder
  PosterDayCard(day: TravelPosterDay) {
    Column({ space: 14 }) {
      if (day.meals.length > 0) {
        this.PosterMealDayCard(day)
      }
      ForEach(day.places, (item: TravelPosterPlace, index: number) => {
        this.PosterPlaceCard(item, index)
      }, (item: TravelPosterPlace) => item.id)
    }
    .width('100%')
  }

  @Builder
  PosterOverlay() {
    Column() {
      Row() {
        Column() {
          Text('WanderSketch · 旅行海报')
            .fontSize(12)
            .fontColor(APP_COLORS.TEXT_ON_DARK)
          Text(this.posterTitle)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.SURFACE)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.posterSubtitle)
            .fontSize(13)
            .fontColor(APP_COLORS.TEXT_ON_DARK)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button('关闭')
          .height(34)
          .fontSize(12)
          .fontColor(APP_COLORS.SURFACE)
          .backgroundColor('rgba(253,254,253,0.16)')
          .borderRadius(17)
          .onClick(() => {
            this.closePoster()
          })
      }
      .width('100%')
      .padding({ left: 22, right: 18, top: 24, bottom: 18 })

      if (this.isPosterLoading) {
        Column() {
          LoadingProgress()
            .color(APP_COLORS.TEXT_ON_DARK)
          Text('正在整理沿途风景与每日三餐…')
            .fontSize(14)
            .fontColor(APP_COLORS.TEXT_ON_DARK)
            .margin({ top: 16 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.posterError.length > 0) {
        Text(this.posterError)
          .fontSize(14)
          .fontColor(APP_COLORS.DANGER_SOFT)
          .padding(22)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Text('把脚步留在风景里，也把风景带回日常。')
              .fontSize(16)
              .fontColor(APP_COLORS.TEXT_ON_DARK)
              .fontStyle(FontStyle.Italic)
              .width('100%')
              .margin({ bottom: 4 })
            ForEach(this.posterDays, (day: TravelPosterDay) => {
              this.PosterDayCard(day)
            }, (day: TravelPosterDay) => day.id)
            if (this.posterDays.length === 0) {
              Text('当前行程还没有可展示的景点或餐食。')
                .fontSize(15)
                .fontColor(APP_COLORS.TEXT_ON_DARK)
            }
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 28 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.DARK_SURFACE)
  }

  @Builder
  LaunchAnimationOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(APP_COLORS.SURFACE)
        .opacity(this.launchOverlayOpacity)

      Column({ space: 14 }) {
        Image($r('app.media.icon'))
          .width(88)
          .height(88)
          .borderRadius(22)
          .shadow({ radius: 20, color: 'rgba(22, 87, 83, 0.24)', offsetX: 0, offsetY: 10 })

        Text('WanderSketch')
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.DARK_SURFACE)

        Text('把旅行，画成你的故事')
          .fontSize(14)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
      }
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.launchLogoScale, y: this.launchLogoScale })
      .opacity(this.launchLogoOpacity)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        Stack() {
          if (this.currentTab === 'plans') {
            this.PlansPage()
          } else if (this.currentTab === 'create') {
            this.CreatePage()
          } else if (this.currentTab === 'detail') {
            this.PlanDetailPage()
          } else {
            this.ExplorePage()
          }
        }
        .layoutWeight(1)
        .width('100%')

        if (this.currentTab !== 'detail') {
          this.BottomNav()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(APP_COLORS.SURFACE)

      if (this.showPoster) {
        this.PosterOverlay()
      }

      if (this.showLaunchAnimation) {
        this.LaunchAnimationOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
