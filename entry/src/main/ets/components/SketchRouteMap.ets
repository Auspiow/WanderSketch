import { APP_COLORS, DEFAULT_SELECTED_REGION, SelectedRegion, TravelTimelineItem } from '../model/Types'
import { RouteOverlay } from './RouteOverlay'

@Component
export struct SketchRouteMap {
  @Prop imageBase64: string = ''
  @Prop region: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []

  @Builder
  MapBase() {
    if (this.imageBase64.length > 0) {
      Image(`data:image/png;base64,${this.imageBase64}`)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
    } else {
      Column() {
        Text('Hand-drawn route map')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
        Text('Waiting for sketch image')
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(APP_COLORS.PARCHMENT)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.MapBase()

      RouteOverlay({
        region: this.region,
        items: this.items,
      })
    }
    .width('100%')
    .aspectRatio(1)
    .clip(true)
    .borderRadius(22)
    .backgroundColor(APP_COLORS.PARCHMENT)
    .shadow({
      radius: 16,
      color: APP_COLORS.SHADOW_MEDIUM,
      offsetY: 6,
    })
  }
}
