import { APP_COLORS, DEFAULT_SELECTED_REGION, SelectedRegion, TravelTimelineItem } from '../model/Types'

const DASH_RATIOS: number[] = [0.18, 0.30, 0.42, 0.54, 0.66, 0.78]

@Component
export struct RouteOverlay {
  @Prop region: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []
  @Prop compactLabels: boolean = false

  private clampPercent(value: number): number {
    return Math.max(-12, Math.min(108, value))
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

  private segmentX(item: TravelTimelineItem, index: number, ratio: number): number {
    if (index <= 0) {
      return this.placeX(item)
    }
    const from: TravelTimelineItem = this.items[index - 1]
    return this.placeX(from) + (this.placeX(item) - this.placeX(from)) * ratio
  }

  private segmentY(item: TravelTimelineItem, index: number, ratio: number): number {
    if (index <= 0) {
      return this.placeY(item)
    }
    const from: TravelTimelineItem = this.items[index - 1]
    return this.placeY(from) + (this.placeY(item) - this.placeY(from)) * ratio
  }

  private segmentAngle(item: TravelTimelineItem, index: number): number {
    if (index <= 0) {
      return 0
    }
    const from: TravelTimelineItem = this.items[index - 1]
    const dx: number = this.placeX(item) - this.placeX(from)
    const dy: number = this.placeY(item) - this.placeY(from)
    return Math.atan2(dy, dx) * 180 / Math.PI
  }

  @Builder
  SegmentDash(item: TravelTimelineItem, index: number, ratio: number) {
    Column()
      .width(14)
      .height(5)
      .backgroundColor('rgba(35,124,122,0.78)')
      .borderRadius(3)
      .position({
        x: `${this.segmentX(item, index, ratio)}%`,
        y: `${this.segmentY(item, index, ratio)}%`,
      })
      .rotate({
        angle: this.segmentAngle(item, index),
      })
  }

  @Builder
  SegmentDirection(item: TravelTimelineItem, index: number) {
    if (index > 0) {
      Text('>')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.WHITE)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor(APP_COLORS.ACCENT)
        .borderRadius(15)
        .border({
          width: 2,
          color: APP_COLORS.WHITE,
        })
        .position({
          x: `${this.segmentX(item, index, 0.58)}%`,
          y: `${this.segmentY(item, index, 0.58)}%`,
        })
        .rotate({
          angle: this.segmentAngle(item, index),
        })
    }
  }

  @Builder
  SegmentTransport(item: TravelTimelineItem, index: number) {
    if (index > 0 && item.commuteFromPrevious !== undefined) {
      Text(`${item.commuteFromPrevious!.transport} ${item.commuteFromPrevious!.durationMinutes}min`)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(APP_COLORS.ACCENT)
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor('rgba(255,255,255,0.90)')
        .borderRadius(9)
        .position({
          x: `${this.segmentX(item, index, 0.40)}%`,
          y: `${this.segmentY(item, index, 0.40)}%`,
        })
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

      if (!this.compactLabels) {
        Text(item.place.name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor('rgba(255,255,255,0.90)')
          .borderRadius(8)
          .constraintSize({ maxWidth: 96 })
      }
    }
    .alignItems(HorizontalAlign.Center)
    .position({ x: `${this.placeX(item)}%`, y: `${this.placeY(item)}%` })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.items, (item: TravelTimelineItem, index: number) => {
        if (index > 0) {
          ForEach(DASH_RATIOS, (ratio: number) => {
            this.SegmentDash(item, index, ratio)
          }, (ratio: number) => `${item.place.id}-dash-${ratio}`)
          this.SegmentTransport(item, index)
          this.SegmentDirection(item, index)
        }
      }, (item: TravelTimelineItem) => `${item.place.id}-segment`)

      ForEach(this.items, (item: TravelTimelineItem, index: number) => {
        this.PlacePin(item, index)
      }, (item: TravelTimelineItem) => item.place.id)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
