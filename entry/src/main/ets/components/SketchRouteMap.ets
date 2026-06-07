import { APP_COLORS, DEFAULT_SELECTED_REGION, SelectedRegion, TravelTimelineItem } from '../model/Types'

@Component
export struct SketchRouteMap {
  @Prop imageBase64: string = ''
  @Prop region: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []

  private clampPercent(value: number): number {
    return Math.max(6, Math.min(94, value))
  }

  private placeX(item: TravelTimelineItem): number {
    const span: number = this.region.east - this.region.west
    if (span <= 0) {
      return 50
    }
    return this.clampPercent((item.place.longitude - this.region.west) / span * 100)
  }

  private placeY(item: TravelTimelineItem): number {
    const span: number = this.region.north - this.region.south
    if (span <= 0) {
      return 50
    }
    return this.clampPercent((this.region.north - item.place.latitude) / span * 100)
  }

  private midX(item: TravelTimelineItem, index: number): number {
    if (index <= 0) {
      return this.placeX(item)
    }
    return (this.placeX(this.items[index - 1]) + this.placeX(item)) / 2
  }

  private midY(item: TravelTimelineItem, index: number): number {
    if (index <= 0) {
      return this.placeY(item)
    }
    return (this.placeY(this.items[index - 1]) + this.placeY(item)) / 2
  }

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

  @Builder
  PlacePin(item: TravelTimelineItem, index: number) {
    Column({ space: 4 }) {
      Text(`${index + 1}`)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.WHITE)
        .width(26)
        .height(26)
        .textAlign(TextAlign.Center)
        .backgroundColor(APP_COLORS.PIN_RED)
        .borderRadius(13)
        .border({
          width: 2,
          color: APP_COLORS.WHITE,
        })

      Text(item.place.name)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 6, right: 6, top: 3, bottom: 3 })
        .backgroundColor('rgba(255,255,255,0.88)')
        .borderRadius(8)
        .constraintSize({ maxWidth: 96 })
    }
    .alignItems(HorizontalAlign.Center)
    .position({ x: `${this.placeX(item)}%`, y: `${this.placeY(item)}%` })
  }

  @Builder
  DirectionArrow(item: TravelTimelineItem, index: number) {
    if (index > 0) {
      Text('>')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.WHITE)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .backgroundColor(APP_COLORS.ACCENT)
        .borderRadius(14)
        .border({
          width: 2,
          color: 'rgba(255,255,255,0.92)',
        })
        .position({ x: `${this.midX(item, index)}%`, y: `${this.midY(item, index)}%` })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.MapBase()

      ForEach(this.items, (item: TravelTimelineItem, index: number) => {
        this.DirectionArrow(item, index)
      }, (item: TravelTimelineItem) => `${item.place.id}-arrow`)

      ForEach(this.items, (item: TravelTimelineItem, index: number) => {
        this.PlacePin(item, index)
      }, (item: TravelTimelineItem) => item.place.id)
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
