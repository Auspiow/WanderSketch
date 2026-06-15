import { router } from '@kit.ArkUI'
import {
  APP_COLORS,
  DEFAULT_SELECTED_REGION,
  SelectedRegion,
  SketchStyle,
} from '../model/Types'
import { SketchCanvas } from '../components/SketchCanvas'

interface SketchPreviewParams {
  imageBase64: string
  style: SketchStyle
  region: SelectedRegion
}

@Entry
@Component
struct SketchPreviewPage {
  @State imageBase64: string = ''
  @State style: SketchStyle = 'pencil'
  @State region: SelectedRegion = DEFAULT_SELECTED_REGION

  aboutToAppear() {
    const params: SketchPreviewParams = router.getParams() as SketchPreviewParams
    this.imageBase64 = params.imageBase64
    this.style = params.style
    this.region = params.region
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

        Text('Sketch Preview')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          SketchCanvas({
            imageBase64: this.imageBase64,
            style: this.style,
          })

          Column() {
            Text('Selected Region')
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
          .borderRadius(18)
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
