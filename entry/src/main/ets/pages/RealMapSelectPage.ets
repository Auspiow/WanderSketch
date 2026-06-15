import { router } from '@kit.ArkUI'
import { MapViewport, SelectedRegion, SketchGenerateRequest, SketchGenerateResult, SketchStyle, APP_COLORS, DEFAULT_MAP_CENTER } from '../model/Types'
import { RealMapView } from '../components/RealMapView'
import { RegionSelector } from '../components/RegionSelector'
import { MapRegionService, RegionSelectorRatio } from '../services/MapRegionService'
import { SketchGenerateService } from '../services/SketchGenerateService'

interface SketchPreviewRouteParams {
  imageBase64: string
  style: SketchStyle
  region: SelectedRegion
}

const SELECTOR_RATIO: RegionSelectorRatio = {
  widthRatio: 0.78,
  heightRatio: 0.52,
  centerYOffsetRatio: -0.10,
}

const SKETCH_API_ENDPOINT: string = ''

@Entry
@Component
struct RealMapSelectPage {
  @State currentViewport: MapViewport = DEFAULT_MAP_CENTER
  @State selectedRegion: SelectedRegion = MapRegionService.viewportToSelectedRegion(DEFAULT_MAP_CENTER, SELECTOR_RATIO)
  @State selectedStyle: SketchStyle = 'pencil'
  @State keepLabels: boolean = true
  @State isGenerating: boolean = false
  @State errorMessage: string = ''

  private captureSnapshotFn: () => Promise<string> = () => {
    return Promise.resolve('')
  }

  private handleViewportChanged(viewport: MapViewport) {
    this.currentViewport = viewport
    this.selectedRegion = MapRegionService.viewportToSelectedRegion(viewport, SELECTOR_RATIO)
  }

  private async handleGenerate() {
    if (this.isGenerating) {
      return
    }
    this.isGenerating = true
    this.errorMessage = ''

    try {
      const baseMapImage: string = await this.captureSnapshotFn()
      const request: SketchGenerateRequest = {
        region: this.selectedRegion,
        style: this.selectedStyle,
        keepLabels: this.keepLabels,
        baseMapImage: baseMapImage,
      }
      const service: SketchGenerateService = new SketchGenerateService(SKETCH_API_ENDPOINT)
      const result: SketchGenerateResult = await service.generate(request)
      const params: SketchPreviewRouteParams = {
        imageBase64: result.imageBase64,
        style: this.selectedStyle,
        region: this.selectedRegion,
      }
      router.pushUrl({
        url: 'pages/SketchPreviewPage',
        params: params,
      })
    } catch (e) {
      const err = e as Error
      this.errorMessage = err.message
    } finally {
      this.isGenerating = false
    }
  }

  @Builder
  StyleChip(label: string, style: SketchStyle) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.selectedStyle === style ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedStyle === style ? APP_COLORS.WHITE : APP_COLORS.TEXT_PRIMARY)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.selectedStyle === style ? APP_COLORS.PRIMARY : APP_COLORS.BACKGROUND)
      .borderRadius(18)
      .onClick(() => {
        this.selectedStyle = style
      })
  }

  build() {
    Stack() {
      RealMapView({
        onViewportChanged: (viewport: MapViewport) => {
          this.handleViewportChanged(viewport)
        },
        onSnapshotReady: (captureFn: () => Promise<string>) => {
          this.captureSnapshotFn = captureFn
        },
      })

      RegionSelector({
        widthRatio: SELECTOR_RATIO.widthRatio,
        heightRatio: SELECTOR_RATIO.heightRatio,
        centerYOffsetRatio: SELECTOR_RATIO.centerYOffsetRatio,
        title: 'Move map to frame the area',
      })

      Column() {
        Text('Select Map Area')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
        Text(`Center ${this.selectedRegion.centerLat.toFixed(4)}, ${this.selectedRegion.centerLng.toFixed(4)}  Zoom ${this.selectedRegion.zoom.toFixed(1)}`)
          .fontSize(11)
          .fontColor(APP_COLORS.TEXT_ON_DARK)
          .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 54, bottom: 18 })
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [['rgba(44,24,16,0.82)', 0], ['rgba(44,24,16,0)', 1]],
      })
      .position({ x: 0, y: 0 })

      Column() {
        Blank().layoutWeight(1)

        Column() {
          Row({ space: 8 }) {
            this.StyleChip('Pencil', 'pencil')
            this.StyleChip('Watercolor', 'watercolor')
            this.StyleChip('Ink', 'ink')
            this.StyleChip('Vintage', 'vintage')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14 })

          Row() {
            Text('Keep labels')
              .fontSize(14)
              .fontColor(APP_COLORS.TEXT_PRIMARY)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.keepLabels })
              .selectedColor(APP_COLORS.PRIMARY)
              .onChange((isOn: boolean) => {
                this.keepLabels = isOn
              })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 8 })

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor(APP_COLORS.PIN_RED)
              .width('100%')
              .padding({ left: 18, right: 18, bottom: 8 })
          }

          Button() {
            Row() {
              if (this.isGenerating) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(APP_COLORS.WHITE)
                  .margin({ right: 8 })
              }
              Text(this.isGenerating ? 'Generating...' : 'Generate Hand-drawn Map')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLORS.WHITE)
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(52)
          .backgroundColor(this.isGenerating ? APP_COLORS.GENERATING_BG : APP_COLORS.PRIMARY)
          .borderRadius(26)
          .margin({ left: 18, right: 18, bottom: 28 })
          .enabled(!this.isGenerating)
          .onClick(() => {
            this.handleGenerate()
          })
        }
        .width('100%')
        .backgroundColor(APP_COLORS.SURFACE)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({
          radius: 18,
          color: APP_COLORS.SHADOW_MEDIUM,
          offsetY: -6,
        })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.BACKGROUND)
  }
}
