/**
 * AI Fantasy Cartographer - Main Page
 *
 * Components:
 *   POIDialog            - Custom dialog for naming new landmarks
 *   RealMapView           - Interactive real map (Map Kit)
 *   BottomPanel           - POI list & theme selector
 *   MapCaptureCompiler    - Hidden canvas: screenshot + POI overlay → Base64
 *   LineartPreviewDialog  - Preview the compiled map image
 *   Index                 - Main entry page orchestrating all components
 */

import {
  POI,
  BBox,
  MapViewport,
  APP_COLORS,
  PIN_COLORS,
  DEFAULT_MAP_CENTER,
  getThemeColors,
  THEMES,
  GenerateRequest,
} from '../model/Types'
import { RealMapView } from '../components/RealMapView'
import { MapCaptureCompiler } from '../compiler/MapCaptureCompiler'
import { LineartPreviewDialog } from '../compiler/LineartPreviewDialog'

// ╔══════════════════════════════════════════════════════════════════╗
// ║  POI Naming Dialog                                              ║
// ╚══════════════════════════════════════════════════════════════════╝

@CustomDialog
struct POIDialog {
  controller: CustomDialogController
  @State poiName: string = ''
  onConfirm: (name: string) => void = () => {}
  onCancel: () => void = () => {}
  defaultName: string = 'Landmark'

  build() {
    Column() {
      Text('📍 Add Landmark')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .margin({ bottom: 20 })

      TextInput({ placeholder: 'Enter landmark name...', text: this.defaultName })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(APP_COLORS.TEXT_PRIMARY)
        .placeholderColor(APP_COLORS.TEXT_HINT)
        .caretColor(APP_COLORS.PRIMARY)
        .backgroundColor(APP_COLORS.BACKGROUND)
        .borderRadius(12)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.poiName = value
        })
        .margin({ bottom: 24 })

      Row() {
        Button('Cancel')
          .fontSize(15)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .backgroundColor(APP_COLORS.DIVIDER)
          .borderRadius(12)
          .width('45%')
          .height(44)
          .onClick(() => {
            this.onCancel()
            this.controller.close()
          })

        Blank().width('10%')

        Button('Confirm')
          .fontSize(15)
          .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
          .backgroundColor(APP_COLORS.PRIMARY)
          .borderRadius(12)
          .width('45%')
          .height(44)
          .onClick(() => {
            const name = this.poiName.trim() || this.defaultName
            this.onConfirm(name)
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

// ╔══════════════════════════════════════════════════════════════════╗
// ║  Bottom Panel — POI List & Theme Selector                       ║
// ╚══════════════════════════════════════════════════════════════════╝

@Component
struct BottomPanel {
  @Link pois: POI[]
  @Link selectedTheme: string
  @Link panelExpanded: boolean
  @State editingPoiId: string = ''
  @State editingPoiName: string = ''

  build() {
    Column() {
      // ---- Drag Handle ----
      Row() {
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor(APP_COLORS.TEXT_HINT)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 10, bottom: 6 })
      .onClick(() => {
        this.panelExpanded = !this.panelExpanded
      })

      // ---- Header Row ----
      Row() {
        Row() {
          Text('📍')
            .fontSize(16)
            .margin({ right: 6 })
          Text('Landmarks')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
          Text(` (${this.pois.length})`)
            .fontSize(14)
            .fontColor(APP_COLORS.TEXT_SECONDARY)
        }

        Blank()

        Text(this.panelExpanded ? '▼' : '▲')
          .fontSize(12)
          .fontColor(APP_COLORS.TEXT_SECONDARY)
          .margin({ right: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .onClick(() => {
        this.panelExpanded = !this.panelExpanded
      })

      // ---- Expandable Content ----
      if (this.panelExpanded) {
        if (this.pois.length > 0) {
          Scroll() {
            Column() {
              ForEach(this.pois, (poi: POI) => {
                this.POIItem(poi)
              }, (poi: POI) => poi.id)
            }
          }
          .width('100%')
          .constraintSize({ maxHeight: 220 })
          .scrollBar(BarState.Auto)
          .margin({ top: 8 })
        } else {
          Column() {
            Text('🗺️')
              .fontSize(28)
              .margin({ bottom: 8 })
            Text('Tap the map to add landmarks')
              .fontSize(13)
              .fontColor(APP_COLORS.TEXT_HINT)
          }
          .width('100%')
          .padding({ top: 20, bottom: 20 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        Divider()
          .color(APP_COLORS.DIVIDER)
          .margin({ left: 20, right: 20, top: 4, bottom: 12 })

        // ---- Theme Selector ----
        Row() {
          Text('🎨 Art Style')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(APP_COLORS.TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        .margin({ bottom: 10 })

        Row({ space: 10 }) {
          ForEach(THEMES, (theme: string) => {
            this.ThemeChip(theme)
          }, (theme: string) => theme)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        Blank().height(16)
      }
    }
    .width('100%')
    .backgroundColor(APP_COLORS.SURFACE)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: APP_COLORS.SHADOW_MEDIUM,
      offsetY: -4
    })
    .clip(true)
  }

  @Builder
  POIItem(poi: POI) {
    Row() {
      Column() {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(poi.color)
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 8 })

      if (this.editingPoiId === poi.id) {
        TextInput({ text: this.editingPoiName })
          .width(120)
          .height(36)
          .fontSize(14)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .caretColor(APP_COLORS.PRIMARY)
          .backgroundColor(APP_COLORS.BACKGROUND)
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.editingPoiName = value
          })
          .onSubmit(() => {
            this.commitEdit(poi)
          })
          .onBlur(() => {
            this.commitEdit(poi)
          })
      } else {
        Text(poi.name)
          .fontSize(14)
          .fontColor(APP_COLORS.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            this.editingPoiId = poi.id
            this.editingPoiName = poi.name
          })
      }

      Blank()

      // Lat/Lng display
      Text(`${poi.latitude.toFixed(3)}, ${poi.longitude.toFixed(3)}`)
        .fontSize(10)
        .fontColor(APP_COLORS.TEXT_HINT)
        .margin({ right: 8 })

      // Delete button
      Row() {
        Text('✕')
          .fontSize(14)
          .fontColor(APP_COLORS.PIN_RED)
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor(APP_COLORS.DELETE_BG)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.deletePoi(poi.id)
      })
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ThemeChip(theme: string) {
    Column() {
      Row() {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(getThemeColors(theme).primary)
          .margin({ right: 6 })

        Text(theme)
          .fontSize(13)
          .fontWeight(this.selectedTheme === theme ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.selectedTheme === theme ? APP_COLORS.WHITE : APP_COLORS.TEXT_PRIMARY)
      }
    }
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .borderRadius(20)
    .backgroundColor(this.selectedTheme === theme ? getThemeColors(theme).primary : APP_COLORS.BACKGROUND)
    .border({
      width: 1,
      color: this.selectedTheme === theme ? getThemeColors(theme).primary : APP_COLORS.BORDER,
      style: BorderStyle.Solid
    })
    .shadow({
      radius: this.selectedTheme === theme ? 8 : 0,
      color: this.selectedTheme === theme ? getThemeColors(theme).primary + '40' : 'transparent',
      offsetY: this.selectedTheme === theme ? 2 : 0
    })
    .onClick(() => {
      this.selectedTheme = theme
    })
  }

  private commitEdit(poi: POI) {
    if (this.editingPoiName.trim()) {
      const idx = this.pois.findIndex((p: POI) => p.id === poi.id)
      if (idx >= 0) {
        this.pois[idx].name = this.editingPoiName.trim()
        this.pois = [...this.pois]
      }
    }
    this.editingPoiId = ''
    this.editingPoiName = ''
  }

  private deletePoi(id: string) {
    this.pois = this.pois.filter((p: POI) => p.id !== id)
  }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  Main Page — Index                                              ║
// ╚══════════════════════════════════════════════════════════════════╝

@Entry
@Component
struct Index {
  // ============ Reactive State ============

  @State pois: POI[] = []
  @State selectedTheme: string = 'Parchment'
  @State bbox: BBox = {
    north: 39.9234,
    south: 39.8850,
    east: 116.4474,
    west: 116.3674
  }
  @State buttonScale: number = 1.0
  @State panelExpanded: boolean = false
  @State poiCounter: number = 0
  @State isGenerating: boolean = false
  @State compileTrigger: number = 0
  @State lineartBase64: string = ''
  @State mapSnapshotBase64: string = ''
  @State currentViewport: MapViewport = DEFAULT_MAP_CENTER

  // Pending pin position (geographic coordinates)
  private pendingPinLat: number = 0
  private pendingPinLng: number = 0

  // POI naming dialog controller
  private dialogController: CustomDialogController = new CustomDialogController({
    builder: POIDialog({
      onConfirm: (name: string) => {
        this.addPOI(name)
      },
      onCancel: () => {}
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  })

  // Map preview dialog controller
  private previewController: CustomDialogController = new CustomDialogController({
    builder: LineartPreviewDialog({
      imageDataUrl: `data:image/png;base64,${this.lineartBase64}`,
      onConfirm: () => {
        // Phase 3: send to AI API
      },
      onDismiss: () => {}
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: true
  })

  // ============ Lifecycle ============

  aboutToAppear() {
    // Could load saved POIs or map config here
  }

  // ============ Actions ============

  private addPOI(name: string) {
    this.poiCounter++
    const colorIdx = (this.poiCounter - 1) % PIN_COLORS.length
    const newPoi: POI = {
      id: `poi_${this.poiCounter}`,
      name: name,
      latitude: this.pendingPinLat,
      longitude: this.pendingPinLng,
      color: PIN_COLORS[colorIdx]
    }
    this.pois = [...this.pois, newPoi]

    if (!this.panelExpanded) {
      this.panelExpanded = true
    }
  }

  private handleMapTap(latitude: number, longitude: number) {
    this.pendingPinLat = latitude
    this.pendingPinLng = longitude
    this.dialogController.open()
  }

  private handleViewportChanged(viewport: MapViewport) {
    this.currentViewport = viewport
    this.bbox = {
      north: viewport.northLat,
      south: viewport.southLat,
      east: viewport.eastLng,
      west: viewport.westLng
    }
  }

  // Callback stored by RealMapView so the parent can trigger screenshot
  private captureSnapshotFn: () => Promise<string> = () => { return Promise.resolve('') }

  private async handleGenerate() {
    if (this.pois.length === 0) {
      return
    }
    this.isGenerating = true

    // 1. Capture the real map screenshot via the callback RealMapView registered
    this.mapSnapshotBase64 = await this.captureSnapshotFn()

    if (this.mapSnapshotBase64.length === 0) {
      console.warn('Map snapshot returned empty, compiling with fallback')
    }

    // 2. Trigger the capture compiler (draws screenshot + POI markers)
    this.compileTrigger++
  }

  /** Called by MapCaptureCompiler when the compiled image is ready */
  private onCaptureCompiled(base64: string) {
    this.lineartBase64 = base64
    this.isGenerating = false
    this.previewController.open()
  }

  // ============ Build ============

  build() {
    Stack() {
      // ────────────────────────────────────
      // Layer 0: Real Map (Map Kit)
      // ────────────────────────────────────
      RealMapView({
        pois: this.pois,
        onMapTap: (latitude: number, longitude: number) => {
          this.handleMapTap(latitude, longitude)
        },
        onViewportChanged: (viewport: MapViewport) => {
          this.handleViewportChanged(viewport)
        },
        onSnapshotReady: (captureFn: () => Promise<string>) => {
          this.captureSnapshotFn = captureFn
        }
      })

      // ────────────────────────────────────
      // Hidden Capture Compiler (screenshot + POI overlay → Base64)
      // ────────────────────────────────────
      MapCaptureCompiler({
        compileTrigger: this.compileTrigger,
        mapSnapshotBase64: this.mapSnapshotBase64,
        pois: this.pois,
        viewport: this.currentViewport,
        onCompiled: (base64: string) => {
          this.onCaptureCompiled(base64)
        }
      })

      // ────────────────────────────────────
      // Layer 1: Top Bar
      // ────────────────────────────────────
      Row() {
        Text('🗺️')
          .fontSize(22)
          .margin({ right: 8 })

        Column() {
          Text('AI Fantasy Cartographer')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
            .maxLines(1)
          Text(`${this.selectedTheme} Style · ${this.pois.length} landmark${this.pois.length !== 1 ? 's' : ''}`)
            .fontSize(11)
            .fontColor(APP_COLORS.TEXT_ON_DARK)
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('🔍')
            .fontSize(16)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(APP_COLORS.ICON_BG_DARK)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [['rgba(107, 66, 38, 0.95)', 0], ['rgba(74, 46, 26, 0.92)', 1]]
      })
      .alignItems(VerticalAlign.Center)
      .shadow({
        radius: 8,
        color: 'rgba(0,0,0,0.15)',
        offsetY: 2
      })

      // ────────────────────────────────────
      // Layer 2: Floating Generate Button
      // ────────────────────────────────────
      Row() {
        Button() {
          Row() {
            if (this.isGenerating) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color(APP_COLORS.WHITE)
                .margin({ right: 8 })
            } else {
              Text('✨')
                .fontSize(18)
                .margin({ right: 8 })
            }
            Text(this.isGenerating ? 'Generating...' : '生成手绘地图')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(APP_COLORS.TEXT_ON_PRIMARY)
          }
        }
        .height(52)
        .padding({ left: 28, right: 28 })
        .backgroundColor(this.isGenerating ? APP_COLORS.GENERATING_BG : APP_COLORS.PRIMARY)
        .borderRadius(26)
        .shadow({
          radius: 16,
          color: APP_COLORS.SHADOW_PRIMARY,
          offsetY: 4
        })
        .scale({ x: this.buttonScale, y: this.buttonScale })
        .animation({
          duration: 150,
          curve: Curve.EaseOut
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.buttonScale = 0.92
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.buttonScale = 1.0
          }
        })
        .onClick(() => {
          this.handleGenerate()
        })
        .enabled(!this.isGenerating && this.pois.length > 0)
        .opacity(this.pois.length === 0 ? 0.5 : 1.0)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: '72%' })

      // ────────────────────────────────────
      // Layer 3: Bottom Panel
      // ────────────────────────────────────
      Column() {
        Blank().layoutWeight(1)

        BottomPanel({
          pois: $pois,
          selectedTheme: $selectedTheme,
          panelExpanded: $panelExpanded
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLORS.BACKGROUND)
  }
}
