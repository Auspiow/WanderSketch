import { router } from '@kit.ArkUI'
import {
  APP_COLORS,
  DEFAULT_SELECTED_REGION,
  SelectedRegion,
  SketchStyle,
  TravelPlan,
  TravelPreference,
  TripViewMode,
} from '../model/Types'
import { SketchRouteMap } from '../components/SketchRouteMap'
import { RealRouteMap } from '../components/RealRouteMap'
import { TripTimeline } from '../components/TripTimeline'

interface SketchPreviewParams {
  imageBase64: string
  style: SketchStyle
  region: SelectedRegion
  travelPlan?: TravelPlan
  initialViewMode?: TripViewMode
}

const DEFAULT_TRAVEL_PREFERENCE: TravelPreference = {
  travelDate: '2026-06-07',
  startDate: '2026-06-07',
  endDate: '2026-06-07',
  startTime: '09:30',
  peopleCount: 2,
  purpose: 'parent_child',
  attractionPreference: '',
  hotelPreference: '',
  sharedPostText: '',
}
const DEFAULT_TRAVEL_PLAN: TravelPlan = {
  preference: DEFAULT_TRAVEL_PREFERENCE,
  places: [],
  timeline: [],
  region: DEFAULT_SELECTED_REGION,
  summary: '',
}

@Entry
@Component
struct SketchPreviewPage {
  @State imageBase64: string = ''
  @State style: SketchStyle = 'pencil'
  @State region: SelectedRegion = DEFAULT_SELECTED_REGION
  @State viewMode: TripViewMode = 'timeline'
  @State travelPlan: TravelPlan = DEFAULT_TRAVEL_PLAN

  aboutToAppear() {
    const params: SketchPreviewParams = router.getParams() as SketchPreviewParams
    this.imageBase64 = params.imageBase64
    this.style = params.style
    this.region = params.region
    if (params.travelPlan) {
      this.travelPlan = params.travelPlan
      this.region = params.travelPlan.region
    }
    if (params.initialViewMode) {
      this.viewMode = params.initialViewMode
    } else if (this.imageBase64.length === 0) {
      this.viewMode = 'real'
    }
  }

  @Builder
  ModeButton(label: string, mode: TripViewMode) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.viewMode === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.viewMode === mode ? APP_COLORS.WHITE : APP_COLORS.TEXT_PRIMARY)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(38)
      .padding({ top: 9 })
      .backgroundColor(this.viewMode === mode ? APP_COLORS.ACCENT : 'rgba(35,124,122,0.08)')
      .borderRadius(19)
      .onClick(() => {
        this.viewMode = mode
      })
  }

  build() {
    Column() {
      Row() {
        Button('Back')
          .fontSize(14)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .backgroundColor(APP_COLORS.BACKGROUND)
          .borderRadius(16)
          .height(36)
          .onClick(() => {
            router.back()
          })

        Blank()

        Text('Travel Route')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          Column() {
            Text(this.travelPlan.summary)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
            Text('已结合地点顺序、营业时间和通勤距离生成路线')
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(APP_COLORS.SURFACE)
          .borderRadius(18)

          Row({ space: 8 }) {
            this.ModeButton('时间轴', 'timeline')
            this.ModeButton('真实地图', 'real')
            this.ModeButton('手绘地图', 'sketch')
          }
          .width('100%')
          .padding(4)
          .backgroundColor(APP_COLORS.WHITE)
          .borderRadius(23)
          .margin({ top: 14, bottom: 14 })

          if (this.viewMode === 'timeline') {
            TripTimeline({
              items: this.travelPlan.timeline,
            })
          } else if (this.viewMode === 'real') {
            RealRouteMap({
              initialRegion: this.travelPlan.region,
              items: this.travelPlan.timeline,
            })
          } else {
            SketchRouteMap({
              imageBase64: this.imageBase64,
              region: this.travelPlan.region,
              items: this.travelPlan.timeline,
            })
          }

          Column() {
            Text('Map Region')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .margin({ bottom: 8 })
            Text(`N ${this.region.north.toFixed(5)}  S ${this.region.south.toFixed(5)}`)
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
            Text(`E ${this.region.east.toFixed(5)}  W ${this.region.west.toFixed(5)}`)
              .fontSize(12)
              .fontColor(APP_COLORS.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(APP_COLORS.CARD)
          .borderRadius(16)
          .margin({ top: 16 })

          Button('Export Image')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.WHITE)
            .backgroundColor(APP_COLORS.PRIMARY)
            .borderRadius(25)
            .margin({ top: 18 })
            .onClick(() => {
              console.info('Export image action is not implemented')
            })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.BACKGROUND)
  }
}
