import { APP_COLORS, SketchStyle } from '../model/Types'

@Component
export struct SketchCanvas {
  @Prop imageBase64: string = ''
  @Prop style: SketchStyle = 'pencil'

  build() {
    Column() {
      if (this.imageBase64.length > 0) {
        Image(`data:image/png;base64,${this.imageBase64}`)
          .width('100%')
          .aspectRatio(1)
          .objectFit(ImageFit.Contain)
          .borderRadius(22)
      } else {
        Column() {
          Text('Hand-drawn map preview')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
          Text(`Style: ${this.style}`)
            .fontSize(13)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .aspectRatio(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(APP_COLORS.PARCHMENT)
        .borderRadius(22)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(APP_COLORS.CARD)
    .borderRadius(28)
    .shadow({
      radius: 18,
      color: APP_COLORS.SHADOW_MEDIUM,
      offsetY: 6,
    })
  }
}
