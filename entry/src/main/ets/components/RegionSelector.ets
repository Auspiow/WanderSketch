import { APP_COLORS } from '../model/Types'

@Component
export struct RegionSelector {
  @Prop widthRatio: number = 0.78
  @Prop heightRatio: number = 0.52
  @Prop centerYOffsetRatio: number = -0.10
  @Prop title: string = 'Selected region'

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.10)')
        .hitTestBehavior(HitTestMode.Transparent)

      Column() {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .border({
              width: 2,
              color: APP_COLORS.WHITE,
              style: BorderStyle.Solid,
            })
            .borderRadius(18)
            .shadow({
              radius: 18,
              color: 'rgba(0,0,0,0.25)',
              offsetY: 4,
            })

          Column()
            .width('92%')
            .height('88%')
            .border({
              width: 1,
              color: 'rgba(255,255,255,0.56)',
              style: BorderStyle.Dashed,
            })
            .borderRadius(12)

          Text(this.title)
            .fontSize(12)
            .fontColor(APP_COLORS.WHITE)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('rgba(44,24,16,0.76)')
            .borderRadius(12)
            .position({ x: 14, y: 12 })
        }
        .width(`${this.widthRatio * 100}%`)
        .height(`${this.heightRatio * 100}%`)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .translate({ y: `${this.centerYOffsetRatio * 100}%` })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
