import { APP_COLORS, DEFAULT_SELECTED_REGION, SelectedRegion, TravelTimelineItem } from '../model/Types'

@Component
export struct TravelMapPanel {
  @Prop region: SelectedRegion = DEFAULT_SELECTED_REGION
  @Prop items: TravelTimelineItem[] = []
  @Prop title: string = 'Trip Planner'

  @Builder
  RouteDash(x: string, y: string, angle: number) {
    Column()
      .width(24)
      .height(7)
      .backgroundColor('rgba(35,124,122,0.72)')
      .borderRadius(4)
      .rotate({ angle: angle })
      .position({ x: x, y: y })
  }

  @Builder
  PinSticker(x: string, y: string, color: string, label: string) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(32)
        .height(32)
        .backgroundColor(color)
        .borderRadius(16)
        .border({
          width: 3,
          color: APP_COLORS.WHITE,
        })
        .position({ x: 6, y: 0 })

      Column()
        .width(15)
        .height(15)
        .backgroundColor(color)
        .rotate({ angle: 45 })
        .position({ x: 15, y: 23 })

      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.WHITE)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .position({ x: 6, y: 6 })
    }
    .width(44)
    .height(44)
    .position({ x: x, y: y })
  }

  @Builder
  TicketSticker() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(112)
        .height(60)
        .backgroundColor('#F9D77E')
        .borderRadius(10)
        .border({
          width: 3,
          color: APP_COLORS.WHITE,
        })

      Column()
        .width(1)
        .height(44)
        .backgroundColor('rgba(44,24,16,0.26)')
        .position({ x: 32, y: 8 })

      Text('DAY PLAN')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .position({ x: 44, y: 12 })

      Text(`${this.items.length} stops`)
        .fontSize(10)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .position({ x: 44, y: 34 })
    }
    .width(112)
    .height(60)
    .rotate({ angle: -8 })
  }

  @Builder
  CameraSticker() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(66)
        .height(42)
        .backgroundColor('#BEE4E1')
        .borderRadius(12)
        .border({
          width: 3,
          color: APP_COLORS.WHITE,
        })
        .position({ x: 0, y: 11 })

      Column()
        .width(26)
        .height(14)
        .backgroundColor('#BEE4E1')
        .borderRadius({ topLeft: 8, topRight: 8 })
        .position({ x: 9, y: 3 })

      Column()
        .width(24)
        .height(24)
        .backgroundColor(APP_COLORS.WHITE)
        .borderRadius(12)
        .border({
          width: 5,
          color: APP_COLORS.ACCENT,
        })
        .position({ x: 22, y: 20 })

      Column()
        .width(10)
        .height(7)
        .backgroundColor(APP_COLORS.TEXT_PRIMARY)
        .borderRadius(4)
        .position({ x: 49, y: 19 })
    }
    .width(66)
    .height(56)
    .rotate({ angle: 9 })
  }

  @Builder
  ItinerarySticker() {
    Column({ space: 8 }) {
      Text('智能行程')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .width('100%')

      Row({ space: 6 }) {
        Column()
          .width(8)
          .height(8)
          .backgroundColor(APP_COLORS.PIN_RED)
          .borderRadius(4)
        Text('营业时间')
          .fontSize(10)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
      }

      Row({ space: 6 }) {
        Column()
          .width(8)
          .height(8)
          .backgroundColor(APP_COLORS.ACCENT)
          .borderRadius(4)
        Text('通勤距离')
          .fontSize(10)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
      }
    }
    .width(112)
    .padding(9)
    .backgroundColor('rgba(255,255,255,0.90)')
    .borderRadius(14)
    .border({
      width: 2,
      color: APP_COLORS.WHITE,
    })
  }

  @Builder
  LabelSticker(label: string, x: string, y: string, color: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(APP_COLORS.TEXT_PRIMARY)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(color)
      .borderRadius(14)
      .border({
        width: 2,
        color: APP_COLORS.WHITE,
      })
      .position({ x: x, y: y })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F7E9D6')

      Column()
        .width(96)
        .height(96)
        .backgroundColor('rgba(35,124,122,0.10)')
        .borderRadius(48)
        .position({ x: '58%', y: '-6%' })

      Column()
        .width(94)
        .height(56)
        .backgroundColor('rgba(167,184,61,0.18)')
        .borderRadius(18)
        .rotate({ angle: -11 })
        .position({ x: '4%', y: '60%' })

      this.RouteDash('23%', '31%', 16)
      this.RouteDash('35%', '38%', 24)
      this.RouteDash('47%', '45%', 31)
      this.RouteDash('58%', '52%', 22)

      this.PinSticker('15%', '31%', APP_COLORS.PIN_RED, '1')
      this.PinSticker('44%', '43%', APP_COLORS.ACCENT, '2')
      this.PinSticker('69%', '50%', '#B7791F', '3')

      Column() {
        this.TicketSticker()
      }
      .position({ x: '7%', y: '10%' })

      Column() {
        this.CameraSticker()
      }
      .position({ x: '68%', y: '13%' })

      Column() {
        this.ItinerarySticker()
      }
      .position({ x: '47%', y: '62%' })

      this.LabelSticker('餐厅', '9%', '73%', '#F9D77E')
      this.LabelSticker('打卡地', '67%', '76%', '#D9E785')
      this.LabelSticker('路线', '75%', '8%', '#BEE4E1')

      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('rgba(255,255,255,0.88)')
        .borderRadius(14)
        .position({ x: 16, y: 16 })
    }
    .width('100%')
    .height(188)
    .clip(true)
    .borderRadius(22)
    .shadow({
      radius: 14,
      color: APP_COLORS.SHADOW_MEDIUM,
      offsetY: 5,
    })
  }
}
