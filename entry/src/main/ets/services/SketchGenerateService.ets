import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  SelectedRegion,
  SketchGenerateRequest,
  SketchGenerateResult,
  SketchStyle,
} from '../model/Types'

interface ImageModelPayload {
  image: string
  prompt: string
  region: SelectedRegion
  keepLabels: boolean
  outputFormat: string
}

interface ImageModelResponse {
  imageBase64: string
  mimeType: string
  taskId: string
}

interface ImageModelErrorResponse {
  error: string
  stage: string
}

export class SketchGenerateService {
  private endpoint: string

  constructor(endpoint: string) {
    this.endpoint = endpoint
  }

  async generate(request: SketchGenerateRequest): Promise<SketchGenerateResult> {
    if (this.endpoint.length === 0) {
      return this.generateMock(request)
    }

    const payload: ImageModelPayload = {
      image: request.baseMapImage,
      prompt: this.buildPrompt(request.style, request.keepLabels),
      region: request.region,
      keepLabels: request.keepLabels,
      outputFormat: 'png',
    }

    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(this.endpoint, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        extraData: JSON.stringify(payload),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 120000,
        readTimeout: 420000,
      })

      if (response.responseCode < 200 || response.responseCode >= 300) {
        const errorBody: string = response.result as string
        let message: string = `Sketch API failed with HTTP ${response.responseCode}`
        try {
          const parsedError: ImageModelErrorResponse = JSON.parse(errorBody) as ImageModelErrorResponse
          if (parsedError.error.length > 0) {
            message = `Sketch API ${parsedError.stage}: ${parsedError.error}`
          }
        } catch (parseError) {
          message = `${message}: ${errorBody}`
        }
        throw new Error(message)
      }

      const body: string = response.result as string
      const parsed: ImageModelResponse = JSON.parse(body) as ImageModelResponse
      const result: SketchGenerateResult = {
        imageBase64: parsed.imageBase64,
        mimeType: parsed.mimeType.length > 0 ? parsed.mimeType : 'image/png',
        providerTaskId: parsed.taskId,
      }
      return result
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`Sketch generation failed: ${err.message}`)
    } finally {
      httpRequest.destroy()
    }
  }

  private buildPrompt(style: SketchStyle, keepLabels: boolean): string {
    const labelRule: string = keepLabels ? 'keep readable major map labels' : 'remove small labels and keep only geographic structure'
    if (style === 'watercolor') {
      return `Transform this real map crop into a soft watercolor hand-drawn map, preserve road, building, water and green-space layout, ${labelRule}.`
    }
    if (style === 'ink') {
      return `Transform this real map crop into a black ink illustrated map, preserve geometry and hierarchy, ${labelRule}.`
    }
    if (style === 'vintage') {
      return `Transform this real map crop into a vintage parchment illustrated map, preserve main roads and blocks, ${labelRule}.`
    }
    return `Transform this real map crop into a pencil hand-drawn map, preserve roads, buildings and waterways, ${labelRule}.`
  }

  private generateMock(request: SketchGenerateRequest): SketchGenerateResult {
    const result: SketchGenerateResult = {
      imageBase64: request.baseMapImage,
      mimeType: 'image/png',
      providerTaskId: 'local-preview',
    }
    return result
  }
}
