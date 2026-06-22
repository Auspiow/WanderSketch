import { http } from '@kit.NetworkKit'
import { SelectedRegion, WeatherSnapshot } from '../model/Types'
import { OPENWEATHER_API_KEY } from './ApiKeys'

const OPENWEATHER_CURRENT_ENDPOINT: string = 'https://api.openweathermap.org/data/2.5/weather'

interface OpenWeatherCondition {
  id: number
  main: string
  description: string
  icon: string
}

interface OpenWeatherMain {
  temp: number
  humidity: number
}

interface OpenWeatherWind {
  speed: number
}

interface OpenWeatherResponse {
  name?: string
  weather: OpenWeatherCondition[]
  main: OpenWeatherMain
  wind?: OpenWeatherWind
  rain?: Record<string, number>
  snow?: Record<string, number>
}

export class WeatherService {
  static async fetchCurrent(region: SelectedRegion): Promise<WeatherSnapshot> {
    const url: string = `${OPENWEATHER_CURRENT_ENDPOINT}?lat=${region.centerLat}&lon=${region.centerLng}&appid=${OPENWEATHER_API_KEY}&units=metric&lang=zh_cn`
    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 12000,
      })
      const body: string = response.result as string
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`OpenWeather HTTP ${response.responseCode}: ${body}`)
      }
      const parsed: OpenWeatherResponse = JSON.parse(body) as OpenWeatherResponse
      return WeatherService.normalize(parsed)
    } finally {
      httpRequest.destroy()
    }
  }

  static isLargeChange(previous: WeatherSnapshot, current: WeatherSnapshot): boolean {
    if (previous.severity < 2 && current.severity >= 2) {
      return true
    }
    if (current.severity - previous.severity >= 2) {
      return true
    }
    if (Math.abs(current.temperatureC - previous.temperatureC) >= 8) {
      return true
    }
    return previous.condition !== current.condition && current.severity >= 2
  }

  static isGoodChange(previous: WeatherSnapshot, current: WeatherSnapshot): boolean {
    if (previous.severity >= 2 && current.severity <= 1) {
      return true
    }
    if (previous.severity - current.severity >= 2) {
      return true
    }
    return previous.condition !== current.condition && previous.severity >= 2 && current.severity < previous.severity
  }

  static summary(weather: WeatherSnapshot | null): string {
    if (weather === null) {
      return '天气读取中'
    }
    return `${weather.locationName} ${Math.round(weather.temperatureC)}°C ${weather.description}`
  }

  static alertText(previous: WeatherSnapshot, current: WeatherSnapshot): string {
    return `天气从「${previous.description}」变为「${current.description}」，建议让 AI 重新调整户外和交通安排。`
  }

  static betterText(previous: WeatherSnapshot, current: WeatherSnapshot): string {
    return `天气从「${previous.description}」转为「${current.description}」，可以考虑恢复户外景点或优化步行路线。`
  }

  private static normalize(data: OpenWeatherResponse): WeatherSnapshot {
    const condition: OpenWeatherCondition = data.weather.length > 0 ? data.weather[0] : {
      id: 800,
      main: 'Clear',
      description: '晴',
      icon: '',
    }
    const temp: number = data.main === undefined ? 0 : data.main.temp
    const humidity: number = data.main === undefined ? 0 : data.main.humidity
    const windSpeed: number = data.wind === undefined ? 0 : data.wind.speed
    const rainMm: number = WeatherService.volume(data.rain) + WeatherService.volume(data.snow)
    return {
      locationName: data.name === undefined || data.name.length === 0 ? '当前区域' : data.name,
      condition: condition.main,
      description: condition.description.length === 0 ? condition.main : condition.description,
      temperatureC: temp,
      humidity,
      windSpeed,
      rainMm,
      fetchedAt: new Date().toISOString(),
      severity: WeatherService.severity(condition.id, condition.main, temp, windSpeed, rainMm),
    }
  }

  private static volume(value: Record<string, number> | undefined): number {
    if (value === undefined) {
      return 0
    }
    const oneHour: number | undefined = value['1h']
    if (oneHour !== undefined) {
      return oneHour
    }
    const threeHours: number | undefined = value['3h']
    if (threeHours !== undefined) {
      return threeHours
    }
    return 0
  }

  private static severity(id: number, main: string, temp: number, windSpeed: number, rainMm: number): number {
    const lowerMain: string = main.toLowerCase()
    if (id >= 200 && id < 300) {
      return 4
    }
    if (lowerMain.indexOf('snow') >= 0 || lowerMain.indexOf('rain') >= 0 || lowerMain.indexOf('drizzle') >= 0 || rainMm > 0) {
      return rainMm >= 4 ? 3 : 2
    }
    if (windSpeed >= 10 || temp >= 35 || temp <= 0) {
      return 3
    }
    if (windSpeed >= 7 || temp >= 32) {
      return 2
    }
    return 1
  }
}
