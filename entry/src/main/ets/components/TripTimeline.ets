import { APP_COLORS, CommuteInfo, TravelTimelineItem } from '../model/Types'

@Component
export struct TripTimeline {
  @Prop items: TravelTimelineItem[] = []

  @Builder
  CommuteBadge(commute?: CommuteInfo) {
    if (commute) {
      Row({ space: 6 }) {
        Text(commute.transport)
          .fontSize(11)
          .fontColor(APP_COLORS.ACCENT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(APP_COLORS.ACCENT_SOFT)
          .borderRadius(10)
        Text(`${commute.distanceKm.toFixed(1)}km · ${commute.durationMinutes}min`)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
  }

  @Builder
  TimelineCard(item: TravelTimelineItem, index: number) {
    Row() {
      Column() {
        Text(`${index + 1}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.WHITE)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(APP_COLORS.ACCENT)
          .borderRadius(14)

        if (index < this.items.length - 1) {
          Column()
            .width(2)
            .height(78)
            .backgroundColor('rgba(35,124,122,0.24)')
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Center)
      .width(38)

      Column() {
        this.CommuteBadge(item.commuteFromPrevious)

        Row() {
          Column() {
            Text(`${item.arriveTime} - ${item.leaveTime}`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(APP_COLORS.PRIMARY)
            Text(item.place.name)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(item.openStatus)
            .fontSize(11)
            .fontColor(item.openStatus === '营业中' ? APP_COLORS.SUCCESS : APP_COLORS.WARNING)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(item.openStatus === '营业中' ? '#EAF7EF' : '#FFF4DD')
            .borderRadius(10)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(item.place.address)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .margin({ top: 8 })
        Text(`营业时间 ${item.place.openingHours}`)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .margin({ top: 4 })
        Text(item.place.note)
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .lineHeight(18)
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .padding(14)
      .backgroundColor(APP_COLORS.CARD)
      .borderRadius(16)
      .shadow({
        radius: 10,
        color: 'rgba(35,124,122,0.10)',
        offsetY: 4,
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      ForEach(this.items, (item: TravelTimelineItem, index: number) => {
        this.TimelineCard(item, index)
      }, (item: TravelTimelineItem) => item.place.id)
    }
    .width('100%')
  }
}
