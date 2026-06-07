import { router } from '@kit.ArkUI'
import {
  APP_COLORS,
  DEFAULT_MAP_CENTER,
  MapViewport,
  SelectedRegion,
  SketchGenerateRequest,
  SketchGenerateResult,
  SketchStyle,
  TravelPlan,
  TravelPreference,
  TripViewMode,
} from '../model/Types'
import { RealMapView } from '../components/RealMapView'
import { TravelMapPanel } from '../components/TravelMapPanel'
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

const DEFAULT_SHARED_POST: string = '北京一日路线：上午先去故宫博物院，出来到景山公园看中轴线；午餐想吃四季民福烤鸭店，下午去南锣鼓巷逛小店，晚上到前门大街和PAGEONE书店拍照。'
const DEFAULT_TRAVEL_PREFERENCE: TravelPreference = {
  travelDate: '2026-06-07',
  startTime: '09:30',
  peopleCount: 2,
  sharedPostText: DEFAULT_SHARED_POST,
}
const DEFAULT_TRAVEL_PLAN: TravelPlan = TravelPlanService.buildPlan(DEFAULT_TRAVEL_PREFERENCE)
const SKETCH_API_ENDPOINTS: string[] = [
  'http://127.0.0.1:3000/api/sketch-map',
  'http://10.0.2.2:3000/api/sketch-map',
]

@Entry
@Component
struct RealMapSelectPage {
  @State currentViewport: MapViewport = DEFAULT_MAP_CENTER
  @State selectedRegion: SelectedRegion = DEFAULT_TRAVEL_PLAN.region
  @State selectedStyle: SketchStyle = 'pencil'
  @State keepLabels: boolean = true
  @State isGenerating: boolean = false
  @State errorMessage: string = ''
  @State sharedPostText: string = DEFAULT_SHARED_POST
  @State travelDate: string = '2026-06-07'
  @State startTime: string = '09:30'
  @State peopleCountText: string = '2'
  @State travelPlan: TravelPlan = DEFAULT_TRAVEL_PLAN
  @State useHandDrawnMap: boolean = true

  private captureSnapshotFn: () => Promise<string> = () => {
    return Promise.resolve('')
  }

  private handleViewportChanged(viewport: MapViewport) {
    this.currentViewport = viewport
  }

  private handleBuildPlan() {
    const parsedCount: number = Number(this.peopleCountText)
    const peopleCount: number = this.isInvalidNumber(parsedCount) ? 1 : Math.max(1, Math.round(parsedCount))
    const preference: TravelPreference = {
      travelDate: this.travelDate,
      startTime: this.startTime,
      peopleCount: peopleCount,
      sharedPostText: this.sharedPostText,
    }
    this.travelPlan = TravelPlanService.buildPlan(preference)
    this.selectedRegion = this.travelPlan.region
    this.peopleCountText = `${peopleCount}`
    this.errorMessage = ''
  }

  private isInvalidNumber(value: number): boolean {
    return value !== value
  }

  private async handleGenerate() {
    if (this.isGenerating) {
      return
    }
    this.handleBuildPlan()

    if (!this.useHandDrawnMap) {
      const params: SketchPreviewRouteParams = {
        imageBase64: '',
        style: this.selectedStyle,
        region: this.travelPlan.region,
        travelPlan: this.travelPlan,
        initialViewMode: 'real',
      }
      router.pushUrl({
        url: 'pages/SketchPreviewPage',
        params: params,
      })
      return
    }

    this.isGenerating = true
    this.errorMessage = ''

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
      router.pushUrl({
        url: 'pages/SketchPreviewPage',
        params: params,
      })
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
  FieldLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(APP_COLORS.TEXT_SECONDARY)
      .margin({ bottom: 6 })
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
          TravelMapPanel({
            region: this.travelPlan.region,
            items: this.travelPlan.timeline,
            title: 'Travel Planner',
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 18, right: 18, top: 18, bottom: 12 })
        .backgroundColor(APP_COLORS.BACKGROUND)
      }
      .width('100%')
      .height(224)

      Scroll() {
        Column() {
          Column() {
            this.FieldLabel('小红书分享帖')
            TextArea({
              placeholder: '粘贴分享内容',
              text: this.sharedPostText,
            })
              .height(132)
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

          Row({ space: 10 }) {
            Column() {
              this.FieldLabel('日期')
              TextInput({ text: this.travelDate })
                .height(42)
                .fontSize(14)
                .backgroundColor(APP_COLORS.WHITE)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.travelDate = value
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.FieldLabel('出发')
              TextInput({ text: this.startTime })
                .height(42)
                .fontSize(14)
                .backgroundColor(APP_COLORS.WHITE)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.startTime = value
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              this.FieldLabel('人数')
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

          Button('分析帖子并生成路线')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.WHITE)
            .backgroundColor(APP_COLORS.ACCENT)
            .borderRadius(23)
            .margin({ top: 14 })
            .onClick(() => {
              this.handleBuildPlan()
            })

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
          .enabled(!this.isGenerating)
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
