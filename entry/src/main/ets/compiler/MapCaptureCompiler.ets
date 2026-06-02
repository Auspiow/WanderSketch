/**
 * AI Fantasy Cartographer - Map Capture Compiler
 *
 * Hidden canvas component that:
 * 1. Renders the map screenshot (base64) onto a Canvas
 * 2. Overlays POI markers (colored circles with labels)
 * 3. Exports the combined image as Base64 PNG
 *
 * Uses Canvas 2D for compositing and image.createImagePacker
 * from @kit.ImageKit for PixelMap → byte stream conversion.
 *
 * ArkTS NEXT: all object literals backed by explicit interfaces,
 * no any/unknown, no untyped object literals.
 */

import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  POI,
  MapViewport,
  DEFAULT_MAP_CENTER,
  LINEART_COLORS,
} from '../model/Types'

// ============ Explicit Interface Declarations ============

/** Canvas pixel coordinate */
interface PixelPosition {
  px: number
  py: number
}

/** POI marker visual configuration */
interface MarkerDrawStyle {
  radius: number
  strokeWidth: number
  fontSize: number
  labelOffsetY: number
}

// ============ Constants ============

/** Canvas output dimensions for the compiled image */
const CANVAS_WIDTH: number = 800
const CANVAS_HEIGHT: number = 800

/** Default marker drawing style */
const MARKER_STYLE: MarkerDrawStyle = {
  radius: 16,
  strokeWidth: 3,
  fontSize: 12,
  labelOffsetY: 28,
}

@Component
export struct MapCaptureCompiler {
  // Trigger: parent increments to re-compile
  @Watch('onTriggerChanged')
  @Prop compileTrigger: number = 0

  // Base64 of the map screenshot (raw map, no POI overlays)
  @Prop mapSnapshotBase64: string = ''

  // POIs to overlay as markers
  @Prop pois: POI[] = []

  // Current map viewport for coordinate → pixel conversion
  @Prop viewport: MapViewport = DEFAULT_MAP_CENTER

  // Callback with the compiled base64 result
  onCompiled: (base64: string) => void = () => {}

  // Canvas rendering context (2D)
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  // ============ Watch Handler ============

  onTriggerChanged() {
    if (this.compileTrigger > 0) {
      this.compile()
    }
  }

  // ============ Coordinate Conversion ============

  /** Convert geographic coordinates to canvas pixel position */
  private geoToPixel(latitude: number, longitude: number): PixelPosition {
    const vp: MapViewport = this.viewport
    const lngSpan: number = vp.eastLng - vp.westLng
    const latSpan: number = vp.northLat - vp.southLat

    // Avoid division by zero
    const safeLngSpan: number = lngSpan !== 0 ? lngSpan : 1
    const safeLatSpan: number = latSpan !== 0 ? latSpan : 1

    const px: number = (longitude - vp.westLng) / safeLngSpan * CANVAS_WIDTH
    const py: number = (vp.northLat - latitude) / safeLatSpan * CANVAS_HEIGHT

    const pos: PixelPosition = { px: px, py: py }
    return pos
  }

  // ============ Drawing Helpers ============

  /** Draw the map screenshot as background; fill parchment if no screenshot */
  private drawMapBackground() {
    if (this.mapSnapshotBase64.length === 0) {
      // No screenshot available — fill with parchment background
      this.context.fillStyle = LINEART_COLORS.BG
      this.context.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)
      return
    }

    // Load screenshot from data URL
    const dataUrl: string = 'data:image/png;base64,' + this.mapSnapshotBase64
    const img: ImageBitmap = new ImageBitmap(dataUrl)
    this.context.drawImage(img, 0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)
  }

  /** Draw POI markers on the canvas */
  private drawPOIMarkers() {
    const style: MarkerDrawStyle = MARKER_STYLE

    for (let i = 0; i < this.pois.length; i++) {
      const poi: POI = this.pois[i]
      const pos: PixelPosition = this.geoToPixel(poi.latitude, poi.longitude)

      // Outer circle — white border ring
      this.context.beginPath()
      this.context.arc(pos.px, pos.py, style.radius + style.strokeWidth, 0, Math.PI * 2)
      this.context.fillStyle = LINEART_COLORS.BG
      this.context.fill()

      // Inner circle — POI color fill
      this.context.beginPath()
      this.context.arc(pos.px, pos.py, style.radius, 0, Math.PI * 2)
      this.context.fillStyle = poi.color
      this.context.fill()

      // Label text below the marker
      this.context.font = style.fontSize + 'px sans-serif'
      this.context.textAlign = 'center'
      this.context.fillStyle = LINEART_COLORS.STROKE
      this.context.fillText(poi.name, pos.px, pos.py + style.labelOffsetY)
    }
  }

  // ============ Compile Pipeline ============

  /**
   * Compile: draw map background + POI markers → export as Base64 PNG.
   *
   * Uses Canvas toDataURL for direct PNG export.
   * For PixelMap-based workflows, image.createImagePacker().packToData()
   * provides the same ArrayBuffer → Base64 conversion.
   */
  private compile() {
    try {
      // 1. Clear canvas
      this.context.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT)

      // 2. Draw map screenshot background
      this.drawMapBackground()

      // 3. Draw POI marker overlays
      this.drawPOIMarkers()

      // 4. Export canvas to Base64 PNG via toDataURL
      const dataUrl: string = this.context.toDataURL('image/png', 1.0)
      const prefix: string = 'data:image/png;base64,'
      let base64: string = ''
      if (dataUrl.startsWith(prefix)) {
        base64 = dataUrl.substring(prefix.length)
      }

      // 5. Deliver result
      this.onCompiled(base64)
    } catch (e) {
      const err = e as BusinessError
      console.error(`MapCaptureCompiler compile failed: ${err.message}`)
      this.onCompiled('')
    }
  }

  // ============ Build ============

  build() {
    // Hidden canvas — invisible to user, used only for compositing
    Canvas(this.context)
      .width(CANVAS_WIDTH)
      .height(CANVAS_HEIGHT)
      .position({ x: 0, y: 0 })
      .opacity(0)
  }
}
