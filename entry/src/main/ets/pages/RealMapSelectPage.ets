import { router } from '@kit.ArkUI'
import {
  APP_COLORS,
  DEFAULT_MAP_CENTER,
  DEFAULT_SELECTED_REGION,
  MapViewport,
  SelectedRegion,
  SketchGenerateRequest,
  SketchGenerateResult,
  SketchStyle,
  TravelPlan,
  TravelPreference,
  TravelPurpose,
  TripViewMode,
} from '../model/Types'
import { RealMapView } from '../components/RealMapView'
import { TripTimeline } from '../components/TripTimeline'
import { SketchGenerateService } from '../services/SketchGenerateService'
import { TravelPlanService } from '../services/TravelPlanService'

interface SketchPreviewRouteParams {
  imageBase64: string
  style: SketchStyle
  region: SelectedRegion
  travelPlan: TravelPlan
  initialViewMode: TripViewMode
}

const DEFAULT_SHARED_POST: string = ''
const DEFAULT_TRAVEL_PREFERENCE: TravelPreference = {
  travelDate: '2026-06-07',
  startDate: '2026-06-07',
  endDate: '2026-06-07',
  startTime: '09:30',
  peopleCount: 2,
  purpose: 'parent_child',
  attractionPreference: '',
  hotelPreference: '',
  sharedPostText: DEFAULT_SHARED_POST,
}
const DEFAULT_TRAVEL_PLAN: TravelPlan = {
  preference: DEFAULT_TRAVEL_PREFERENCE,
  places: [],
  timeline: [],
  region: DEFAULT_SELECTED_REGION,
  summary: '',
}
const SKETCH_API_ENDPOINTS: string[] = [
  'http://127.0.0.1:3000/api/sketch-map',
  'http://10.0.2.2:3000/api/sketch-map',
]
const TRAVEL_PLAN_API_ENDPOINTS: string[] = [
  'http://127.0.0.1:3000/api/travel-plan',
  'http://10.0.2.2:3000/api/travel-plan',
]

@Entry
@Component
struct RealMapSelectPage {
  @State currentViewport: MapViewport = DEFAULT_MAP_CENTER
  @State selectedRegion: SelectedRegion = DEFAULT_TRAVEL_PLAN.region
  @State selectedStyle: SketchStyle = 'pencil'
  @State keepLabels: boolean = true
  @State isGenerating: boolean = false
  @State isPlanning: boolean = false
  @State errorMessage: string = ''
  @State sharedPostText: string = DEFAULT_SHARED_POST
  @State travelDate: string = '2026-06-07'
  @State startDate: string = '2026-06-07'
  @State endDate: string = '2026-06-07'
  @State startTime: string = '09:30'
  @State peopleCountText: string = '2'
  @State selectedPurpose: TravelPurpose = 'parent_child'
  @State attractionPreference: string = ''
  @State hotelPreference: string = ''
  @State travelPlan: TravelPlan = DEFAULT_TRAVEL_PLAN
  @State useHandDrawnMap: boolean = true

  private captureSnapshotFn: () => Promise<string> = () => {
    return Promise.resolve('')
  }

  private handleViewportChanged(viewport: MapViewport) {
    this.currentViewport = viewport
  }

  private trimText(value: string): string {
    return value.trim()
  }

  private hasRequiredPostUrl(): boolean {
    const parts: string[] = this.sharedPostText.trim().split(/\s+/)
    for (let i = 0; i < parts.length; i++) {
      const candidate: string = parts[i]
      if (candidate.indexOf('http://') === 0 || candidate.indexOf('https://') === 0) {
        return true
      }
    }
    return false
  }

  private isDateText(value: string): boolean {
    return /^\d{4}-\d{2}-\d{2}$/.test(value)
  }

  private isTimeText(value: string): boolean {
    return /^([01]\d|2[0-3]):[0-5]\d$/.test(value)
  }

  private validateRequiredFields(): string {
    if (!this.hasRequiredPostUrl()) {
      return '请先粘贴小红书链接'
    }
    if (!this.isDateText(this.startDate) || !this.isDateText(this.endDate)) {
      return '计划开始和结束日期必须有效'
    }
    if (this.endDate < this.startDate) {
      return '计划结束日期不能早于开始日期'
    }
    if (!this.isTimeText(this.startTime)) {
      return '每日出发时间必须使用 HH:mm'
    }
    const parsedCount: number = Number(this.peopleCountText)
    if (this.isInvalidNumber(parsedCount) || parsedCount < 1 || parsedCount > 20) {
      return '人数必须是 1 到 20'
    }
    return ''
  }

  private buildPreference(): TravelPreference {
    const parsedCount: number = Number(this.peopleCountText)
    const peopleCount: number = this.isInvalidNumber(parsedCount) ? 1 : Math.max(1, Math.round(parsedCount))
    const preference: TravelPreference = {
      travelDate: this.startDate,
      startDate: this.startDate,
      endDate: this.endDate,
      startTime: this.trimText(this.startTime),
      peopleCount: peopleCount,
      purpose: this.selectedPurpose,
      attractionPreference: this.trimText(this.attractionPreference),
      hotelPreference: this.trimText(this.hotelPreference),
      sharedPostText: this.trimText(this.sharedPostText),
    }
    this.peopleCountText = `${peopleCount}`
    return preference
  }

  private async handleBuildPlan() {
    if (this.isPlanning || this.isGenerating) {
      return
    }

    this.errorMessage = ''
    const validationMessage: string = this.validateRequiredFields()
    if (validationMessage.length > 0) {
      this.errorMessage = validationMessage
      return
    }

    this.isPlanning = true
    try {
      const preference: TravelPreference = this.buildPreference()
      const service: TravelPlanService = new TravelPlanService(TRAVEL_PLAN_API_ENDPOINTS)
      this.travelPlan = await service.generate(preference)
      this.selectedRegion = this.travelPlan.region
    } catch (e) {
      const err = e as Error
      this.errorMessage = err.message
    } finally {
      this.isPlanning = false
    }
  }

  private async refreshTravelPlanForGenerate(): Promise<boolean> {
    try {
      const validationMessage: string = this.validateRequiredFields()
      if (validationMessage.length > 0) {
        this.errorMessage = validationMessage
        return false
      }
      const preference: TravelPreference = this.buildPreference()
      const service: TravelPlanService = new TravelPlanService(TRAVEL_PLAN_API_ENDPOINTS)
      this.travelPlan = await service.generate(preference)
      this.selectedRegion = this.travelPlan.region
      this.errorMessage = ''
      return true
    } catch (e) {
      const err = e as Error
      this.errorMessage = err.message
      return false
    }
  }

  private navigateToPreview(params: SketchPreviewRouteParams): boolean {
    try {
      router.pushUrl({
        url: 'pages/SketchPreviewPage',
        params: params,
      })
      return true
    } catch (e) {
      const err = e as Error
      this.errorMessage = err.message
      return false
    }
  }

  private isInvalidNumber(value: number): boolean {
    return value !== value
  }

  private sharedPostInputHeight(): number {
    if (this.sharedPostText.length > 420) {
      return 180
    }
    if (this.sharedPostText.length > 180) {
      return 132
    }
    return 88
  }

  private parseDate(value: string): Date {
    const parts: string[] = value.split('-')
    if (parts.length < 3) {
      return new Date(2026, 5, 7)
    }
    const year: number = Number(parts[0])
    const month: number = Number(parts[1])
    const day: number = Number(parts[2])
    if (this.isInvalidNumber(year) || this.isInvalidNumber(month) || this.isInvalidNumber(day)) {
      return new Date(2026, 5, 7)
    }
    return new Date(year, month - 1, day)
  }

  private formatDateResult(value: DatePickerResult): string {
    const fallbackDate: Date = this.parseDate(this.startDate)
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
      start: new Date(2026, 0, 1),
      end: new Date(2027, 11, 31),
      selected: this.parseDate(this.startDate),
      onAccept: (value: DatePickerResult) => {
        this.startDate = this.formatDateResult(value)
        this.travelDate = this.startDate
        if (this.endDate < this.startDate) {
          this.endDate = this.startDate
        }
      },
    })
  }

  private showEndDatePicker() {
    DatePickerDialog.show({
      start: new Date(2026, 0, 1),
      end: new Date(2027, 11, 31),
      selected: this.parseDate(this.endDate),
      onAccept: (value: DatePickerResult) => {
        this.endDate = this.formatDateResult(value)
        if (this.endDate < this.startDate) {
          this.startDate = this.endDate
          this.travelDate = this.startDate
        }
      },
    })
  }

  private async handleGenerate() {
    if (this.isGenerating || this.isPlanning) {
      return
    }

    this.isGenerating = true
    this.errorMessage = ''

    const hasPlan: boolean = await this.refreshTravelPlanForGenerate()
    if (!hasPlan) {
      this.isGenerating = false
      return
    }

    if (!this.useHandDrawnMap) {
      const params: SketchPreviewRouteParams = {
        imageBase64: '',
        style: this.selectedStyle,
        region: this.travelPlan.region,
        travelPlan: this.travelPlan,
        initialViewMode: 'real',
      }
      this.navigateToPreview(params)
      this.isGenerating = false
      return
    }

    try {
      const baseMapImage: string = await this.captureSnapshotFn()
      const request: SketchGenerateRequest = {
        region: this.travelPlan.region,
        style: this.selectedStyle,
        keepLabels: this.keepLabels,
        baseMapImage: baseMapImage,
      }
      const service: SketchGenerateService = new SketchGenerateService(SKETCH_API_ENDPOINTS)
      const result: SketchGenerateResult = await service.generate(request)
      const params: SketchPreviewRouteParams = {
        imageBase64: result.imageBase64,
        style: this.selectedStyle,
        region: this.travelPlan.region,
        travelPlan: this.travelPlan,
        initialViewMode: 'sketch',
      }
      this.navigateToPreview(params)
    } catch (e) {
      const err = e as Error
      this.errorMessage = err.message
    } finally {
      this.isGenerating = false
    }
  }

  @Builder
  StyleChip(label: string, style: SketchStyle) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.selectedStyle === style ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedStyle === style ? APP_COLORS.WHITE : APP_COLORS.TEXT_PRIMARY)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.selectedStyle === style ? APP_COLORS.PRIMARY : APP_COLORS.WHITE)
      .borderRadius(18)
      .onClick(() => {
        this.selectedStyle = style
      })
  }

  @Builder
  PurposeChip(label: string, purpose: TravelPurpose) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.selectedPurpose === purpose ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedPurpose === purpose ? APP_COLORS.WHITE : APP_COLORS.TEXT_PRIMARY)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(this.selectedPurpose === purpose ? APP_COLORS.ACCENT : APP_COLORS.WHITE)
      .borderRadius(16)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectedPurpose = purpose
      })
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(APP_COLORS.TEXT_SECONDARY)
      .margin({ bottom: 6 })
  }

  @Builder
  BannerSummary() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('82%')
        .height(1)
        .backgroundColor('rgba(35,124,122,0.12)')
        .position({ x: 24, y: 24 })

      Column()
        .width('70%')
        .height(1)
        .backgroundColor('rgba(35,124,122,0.10)')
        .position({ x: 54, y: 70 })

      Column()
        .width(1)
        .height(54)
        .backgroundColor('rgba(35,124,122,0.10)')
        .position({ x: 206, y: 18 })

      Column()
        .width(84)
        .height(3)
        .borderRadius(2)
        .backgroundColor('rgba(35,124,122,0.30)')
        .rotate({ angle: -8 })
        .position({ x: 160, y: 58 })

      Text('1')
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.ACCENT)
        .textAlign(TextAlign.Center)
        .width(18)
        .height(18)
        .backgroundColor('rgba(35,124,122,0.12)')
        .borderRadius(4)
        .position({ x: 154, y: 50 })

      Text('2')
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.ACCENT)
        .textAlign(TextAlign.Center)
        .width(18)
        .height(18)
        .backgroundColor('rgba(249,215,126,0.42)')
        .borderRadius(4)
        .position({ x: 236, y: 42 })

      Row() {
        Column() {
          Text('WanderSketch')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.travelPlan.places.length > 0) {
            Text(this.travelPlan.summary)
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          } else {
            Text('粘贴小红书链接，生成真实路线')
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .opacity(0.62)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
          if (this.travelPlan.timeline.length > 0) {
            Text(this.travelPlan.timeline[0].place.name + (this.travelPlan.timeline.length > 1 ? ` > ${this.travelPlan.timeline[1].place.name}` : ''))
              .fontSize(12)
              .fontColor(APP_COLORS.ACCENT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.travelPlan.places.length > 0 ? `${this.travelPlan.places.length}` : 'AI')
            .fontSize(this.travelPlan.places.length > 0 ? 18 : 15)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.WHITE)
          Text(this.travelPlan.places.length > 0 ? 'stops' : 'route')
            .fontSize(10)
            .fontColor(APP_COLORS.TEXT_ON_DARK)
        }
        .width(52)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(APP_COLORS.ACCENT)
        .borderRadius(8)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.CARD)
    .borderRadius(8)
  }

  build() {
    Column() {
      Stack() {
        RealMapView({
          initialRegion: this.selectedRegion,
          onViewportChanged: (viewport: MapViewport) => {
            this.handleViewportChanged(viewport)
          },
          onSnapshotReady: (captureFn: () => Promise<string>) => {
            this.captureSnapshotFn = captureFn
          },
        })
        .opacity(0.01)
        .hitTestBehavior(HitTestMode.Transparent)

        Column() {
          this.BannerSummary()
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
      .width('100%')
      .height(104)
      .backgroundColor(APP_COLORS.BACKGROUND)

      Scroll() {
        Column() {
          Column() {
            this.FieldLabel('小红书链接 *')
            TextArea({
              placeholder: '粘贴小红书链接；分享文案、截图识别文字可选',
              text: this.sharedPostText,
            })
              .height(this.sharedPostInputHeight())
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .placeholderColor(APP_COLORS.TEXT_SECONDARY)
              .backgroundColor(APP_COLORS.WHITE)
              .borderRadius(14)
              .padding(12)
              .onChange((value: string) => {
                this.sharedPostText = value
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column() {
            this.FieldLabel('出游目的 *')
            Flex({ wrap: FlexWrap.Wrap }) {
              this.PurposeChip('亲子游', 'parent_child')
              this.PurposeChip('家庭游', 'family')
              this.PurposeChip('特种兵', 'fast_paced')
              this.PurposeChip('轻松慢游', 'relaxed')
              this.PurposeChip('美食优先', 'foodie')
              this.PurposeChip('拍照打卡', 'photo')
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 14 })

          Row({ space: 10 }) {
            Column() {
              this.FieldLabel('计划开始 *')
              Button(this.startDate)
                .width('100%')
                .height(42)
                .fontSize(14)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
                .backgroundColor(APP_COLORS.WHITE)
                .borderRadius(12)
                .onClick(() => {
                  this.showStartDatePicker()
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.FieldLabel('计划结束 *')
              Button(this.endDate)
                .width('100%')
                .height(42)
                .fontSize(14)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
                .backgroundColor(APP_COLORS.WHITE)
                .borderRadius(12)
                .onClick(() => {
                  this.showEndDatePicker()
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.FieldLabel('人数 *')
              TextInput({ text: this.peopleCountText })
                .height(42)
                .fontSize(14)
                .backgroundColor(APP_COLORS.WHITE)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.peopleCountText = value
                })
            }
            .width(72)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 14 })

          Column() {
            this.FieldLabel('每日出发时间 *')
            TextInput({ text: this.startTime })
              .height(42)
              .fontSize(14)
              .backgroundColor(APP_COLORS.WHITE)
              .borderRadius(12)
              .onChange((value: string) => {
                this.startTime = value
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 14 })

          Column() {
            this.FieldLabel('景点偏好（可选）')
            TextArea({
              placeholder: '例如：博物馆、自然风景、少排队、适合老人小孩、不要太累',
              text: this.attractionPreference,
            })
              .height(76)
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .placeholderColor(APP_COLORS.TEXT_SECONDARY)
              .backgroundColor(APP_COLORS.WHITE)
              .borderRadius(12)
              .padding(10)
              .onChange((value: string) => {
                this.attractionPreference = value
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 14 })

          Column() {
            this.FieldLabel('酒店偏好（可选）')
            TextArea({
              placeholder: '例如：地铁附近、亲子房、预算、靠近商圈或景点、不频繁换酒店',
              text: this.hotelPreference,
            })
              .height(76)
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .placeholderColor(APP_COLORS.TEXT_SECONDARY)
              .backgroundColor(APP_COLORS.WHITE)
              .borderRadius(12)
              .padding(10)
              .onChange((value: string) => {
                this.hotelPreference = value
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 14 })

          Button('分析帖子并生成路线')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.WHITE)
            .backgroundColor(APP_COLORS.ACCENT)
            .borderRadius(23)
            .margin({ top: 14 })
            .enabled(!this.isPlanning && !this.isGenerating)
            .onClick(() => {
              this.handleBuildPlan()
            })

          if (this.isPlanning) {
            Row() {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(APP_COLORS.ACCENT)
                .margin({ right: 8 })
              Text('Analyzing travel post...')
                .fontSize(12)
                .fontColor(APP_COLORS.TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ top: 10 })
          }

          if (this.travelPlan.timeline.length > 0) {
            Column() {
              Text(this.travelPlan.summary)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
                .width('100%')
              TripTimeline({
                items: this.travelPlan.timeline,
              })
                .margin({ top: 12 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 18 })
          } else {
            Text('路线会在分析后展示；当前不会使用示例地点占位。')
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .opacity(0.58)
              .width('100%')
              .margin({ top: 16 })
          }

          Row() {
            Text('生成手绘地图')
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.useHandDrawnMap })
              .selectedColor(APP_COLORS.ACCENT)
              .onChange((isOn: boolean) => {
                this.useHandDrawnMap = isOn
              })
          }
          .width('100%')
          .padding({ top: 14, bottom: 6 })

          if (this.useHandDrawnMap) {
            Row({ space: 8 }) {
              this.StyleChip('Pencil', 'pencil')
              this.StyleChip('Watercolor', 'watercolor')
              this.StyleChip('Ink', 'ink')
              this.StyleChip('Vintage', 'vintage')
            }
            .width('100%')
            .margin({ top: 6 })

            Row() {
              Text('Keep labels')
                .fontSize(14)
                .fontColor(APP_COLORS.TEXT_PRIMARY)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.keepLabels })
                .selectedColor(APP_COLORS.ACCENT)
                .onChange((isOn: boolean) => {
                  this.keepLabels = isOn
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 8 })
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor(APP_COLORS.PIN_RED)
              .width('100%')
              .margin({ bottom: 8 })
          }

          Button() {
            Row() {
              if (this.isGenerating) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(APP_COLORS.WHITE)
                  .margin({ right: 8 })
              }
              Text(this.isGenerating ? 'Generating...' : (this.useHandDrawnMap ? 'Generate Hand-drawn Route' : 'Open Live Map Route'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.WHITE)
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(52)
          .backgroundColor(this.isGenerating ? APP_COLORS.GENERATING_BG : APP_COLORS.PRIMARY)
          .borderRadius(26)
          .margin({ top: 4, bottom: 24 })
          .enabled(!this.isGenerating && !this.isPlanning)
          .onClick(() => {
            this.handleGenerate()
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 18 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.BACKGROUND)
  }
}
