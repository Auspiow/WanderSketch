/**
 * AI Fantasy Cartographer - Phase 2: Lineart Preview Dialog
 *
 * CustomDialog that displays the compiled B&W lineart image
 * with pinch-to-zoom and pan support for inspection.
 */

import { APP_COLORS } from '../model/Types'

@CustomDialog
export struct LineartPreviewDialog {
  controller: CustomDialogController

  // The full data URL for the lineart image: "data:image/png;base64,..."
  imageDataUrl: string = ''

  // Zoom/pan state
  @State previewScale: number = 1.0
  @State previewOffsetX: number = 0
  @State previewOffsetY: number = 0
  private pinchStartScale: number = 1.0
  private panStartX: number = 0
  private panStartY: number = 0

  // Action callbacks
  onConfirm: () => void = () => {}
  onDismiss: () => void = () => {}

  build() {
    Column() {
      // ---- Title ----
      Row() {
        Text('🗺️ 地图预览')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ bottom: 12 })

      Text('This map image with POI markers will be sent to the AI for rendering')
        .fontSize(12)
        .fontColor(APP_COLORS.TEXT_SECONDARY)
        .width('100%')
        .margin({ bottom: 16 })

      // ---- Image Preview with zoom/pan ----
      Stack() {
        Image(this.imageDataUrl)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height(320)
          .scale({ x: this.previewScale, y: this.previewScale })
          .translate({ x: this.previewOffsetX, y: this.previewOffsetY })
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.pinchStartScale = this.previewScale
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.previewScale = Math.max(0.5, Math.min(4.0,
                    this.pinchStartScale * event.scale))
                })
                .onActionEnd(() => {}),

              PanGesture({ fingers: 1, distance: 5 })
                .onActionStart(() => {
                  this.panStartX = this.previewOffsetX
                  this.panStartY = this.previewOffsetY
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.previewOffsetX = this.panStartX + event.offsetX
                  this.previewOffsetY = this.panStartY + event.offsetY
                })
                .onActionEnd(() => {})
            )
          )
      }
      .width('100%')
      .height(320)
      .borderRadius(12)
      .backgroundColor('#F5F5F5')
      .clip(true)
      .alignContent(Alignment.Center)

      // ---- Zoom hint ----
      Text('Pinch to zoom · Drag to pan')
        .fontSize(11)
        .fontColor(APP_COLORS.TEXT_HINT)
        .margin({ top: 8, bottom: 16 })

      // ---- Reset zoom button ----
      if (this.previewScale !== 1.0 || this.previewOffsetX !== 0 || this.previewOffsetY !== 0) {
        Text('Reset View')
          .fontSize(12)
          .fontColor(APP_COLORS.PRIMARY)
          .margin({ bottom: 12 })
          .onClick(() => {
            this.previewScale = 1.0
            this.previewOffsetX = 0
            this.previewOffsetY = 0
          })
      }

      // ---- Action Buttons ----
      Row() {
        Button('返回编辑')
          .fontSize(15)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .backgroundColor(APP_COLORS.DIVIDER)
          .borderRadius(12)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.onDismiss()
            this.controller.close()
          })

        Blank().width(12)

        Button('确认发送')
          .fontSize(15)
          .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
          .backgroundColor(APP_COLORS.PRIMARY)
          .borderRadius(12)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.onConfirm()
            this.controller.close()
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor(APP_COLORS.CARD)
    .borderRadius(20)
  }
}
