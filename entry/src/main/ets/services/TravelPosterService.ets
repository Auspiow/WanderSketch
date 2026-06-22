import {
  TravelDayMealPlan,
  TravelMeal,
  TravelMealPeriod,
  TravelPlan,
  TravelPosterDay,
  TravelPosterMeal,
  TravelPosterMealDay,
  TravelPosterPlace,
  TravelTimelineItem,
} from '../model/Types'
import { GoogleMapService, GooglePlacePhotoResult } from './GoogleMapService'

export class TravelPosterService {
  static async buildPlaces(plan: TravelPlan): Promise<TravelPosterPlace[]> {
    const items: TravelPosterPlace[] = []
    const timeline: TravelTimelineItem[] = TravelPosterService.uniqueTimeline(plan.timeline)
    const batchSize: number = 3
    for (let start: number = 0; start < timeline.length; start += batchSize) {
      const tasks: Promise<TravelPosterPlace>[] = []
      const end: number = Math.min(start + batchSize, timeline.length)
      for (let index: number = start; index < end; index++) {
        tasks.push(TravelPosterService.buildPlace(timeline[index], index))
      }
      const resolved: TravelPosterPlace[] = await Promise.all(tasks)
      for (let index: number = 0; index < resolved.length; index++) {
        const posterPlace: TravelPosterPlace = resolved[index]
        if (TravelPosterService.hasImageUrl(items, posterPlace.imageUrl)) {
          const place = timeline[start + index].place
          items.push({
            id: posterPlace.id,
            name: posterPlace.name,
            imageUrl: GoogleMapService.buildPlaceMapCoverUrl(place.latitude, place.longitude),
            description: posterPlace.description,
            attribution: '路线坐标图 · Google Maps',
          })
        } else {
          items.push(posterPlace)
        }
      }
    }
    return items
  }

  static async buildMealDays(plan: TravelPlan): Promise<TravelPosterMealDay[]> {
    const mealDays: TravelPosterMealDay[] = []
    for (let dayIndex: number = 0; dayIndex < plan.days.length; dayIndex++) {
      const day = plan.days[dayIndex]
      if (day.mealPlan === undefined) {
        continue
      }
      const meals: TravelPosterMeal[] = await TravelPosterService.buildMeals(day.mealPlan, plan.title, dayIndex)
      mealDays.push({
        id: `meal-${day.id}`,
        dateLabel: `${day.dateLabel} ${day.weekday}`,
        meals,
      })
    }
    return mealDays
  }

  static async buildPosterDays(plan: TravelPlan): Promise<TravelPosterDay[]> {
    const posterDays: TravelPosterDay[] = []
    for (let dayIndex: number = 0; dayIndex < plan.days.length; dayIndex++) {
      const day = plan.days[dayIndex]
      const places: TravelPosterPlace[] = await TravelPosterService.buildPlacesFromTimeline(day.items)
      const meals: TravelPosterMeal[] = day.mealPlan === undefined ? [] :
        await TravelPosterService.buildMeals(day.mealPlan, plan.title, dayIndex)
      posterDays.push({
        id: `poster-${day.id}`,
        dateLabel: `${day.dateLabel} ${day.weekday}`,
        meals,
        places,
      })
    }
    return posterDays
  }

  private static hasImageUrl(items: TravelPosterPlace[], imageUrl: string): boolean {
    if (imageUrl.length === 0) {
      return false
    }
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].imageUrl === imageUrl) {
        return true
      }
    }
    return false
  }

  private static async buildPlacesFromTimeline(timelineItems: TravelTimelineItem[]): Promise<TravelPosterPlace[]> {
    const items: TravelPosterPlace[] = []
    const timeline: TravelTimelineItem[] = TravelPosterService.uniqueTimeline(timelineItems)
    const batchSize: number = 3
    for (let start: number = 0; start < timeline.length; start += batchSize) {
      const tasks: Promise<TravelPosterPlace>[] = []
      const end: number = Math.min(start + batchSize, timeline.length)
      for (let index: number = start; index < end; index++) {
        tasks.push(TravelPosterService.buildPlace(timeline[index], index))
      }
      const resolved: TravelPosterPlace[] = await Promise.all(tasks)
      for (let index: number = 0; index < resolved.length; index++) {
        const posterPlace: TravelPosterPlace = resolved[index]
        if (TravelPosterService.hasImageUrl(items, posterPlace.imageUrl)) {
          const place = timeline[start + index].place
          items.push({
            id: posterPlace.id,
            name: posterPlace.name,
            imageUrl: GoogleMapService.buildPlaceMapCoverUrl(place.latitude, place.longitude),
            description: posterPlace.description,
            attribution: '路线坐标图 · Google Maps',
          })
        } else {
          items.push(posterPlace)
        }
      }
    }
    return items
  }

  private static uniqueTimeline(timeline: TravelTimelineItem[]): TravelTimelineItem[] {
    const items: TravelTimelineItem[] = []
    for (let index: number = 0; index < timeline.length; index++) {
      let exists: boolean = false
      for (let compareIndex: number = 0; compareIndex < items.length; compareIndex++) {
        if (items[compareIndex].place.id === timeline[index].place.id) {
          exists = true
          break
        }
      }
      if (!exists) {
        items.push(timeline[index])
      }
    }
    return items
  }

  private static async buildPlace(item: TravelTimelineItem, photoIndex: number): Promise<TravelPosterPlace> {
    const place = item.place
    const query: string = `${place.name} ${place.address}`
    let photo: GooglePlacePhotoResult | null = await GoogleMapService.fetchPlacePhoto(query, photoIndex)
    if (photo === null) {
      photo = await GoogleMapService.fetchPlacePhoto(place.name, photoIndex)
    }
    const fallbackMapUrl: string = GoogleMapService.buildPlaceMapCoverUrl(place.latitude, place.longitude)
    return {
      id: place.id,
      name: place.name,
      imageUrl: photo === null ? fallbackMapUrl : photo.imageUrl,
      description: TravelPosterService.resolveDescription(place.note, place.name),
      attribution: photo === null ? '路线坐标图 · Google Maps' : photo.attribution,
    }
  }

  private static async buildMeal(period: TravelMealPeriod, label: string, meal: TravelMeal, planTitle: string,
    photoIndex: number): Promise<TravelPosterMeal> {
    const restaurantName: string = meal.restaurantName.trim()
    let photo: GooglePlacePhotoResult | null = null
    if (restaurantName.length > 0) {
      photo = await GoogleMapService.fetchPlacePhoto(`${restaurantName} ${planTitle}`, photoIndex)
      if (photo === null) {
        photo = await GoogleMapService.fetchPlacePhoto(restaurantName, photoIndex)
      }
    }
    return {
      id: `${period}-${photoIndex}-${restaurantName}`,
      period,
      label,
      restaurantName: restaurantName.length > 0 ? restaurantName : '待定餐厅',
      imageUrl: photo === null ? '' : photo.imageUrl,
      recommendation: meal.recommendation,
      estimatedCost: meal.estimatedCost,
      attribution: photo === null ? '餐食主题插画' : photo.attribution,
    }
  }

  private static async buildMeals(mealPlan: TravelDayMealPlan, planTitle: string, dayIndex: number): Promise<TravelPosterMeal[]> {
    return Promise.all([
      TravelPosterService.buildMeal('breakfast', '早餐', mealPlan.breakfast, planTitle, dayIndex * 3),
      TravelPosterService.buildMeal('lunch', '午餐', mealPlan.lunch, planTitle, dayIndex * 3 + 1),
      TravelPosterService.buildMeal('dinner', '晚餐', mealPlan.dinner, planTitle, dayIndex * 3 + 2),
    ])
  }

  private static resolveDescription(note: string, name: string): string {
    if (note.trim().length > 0) {
      return note.trim()
    }
    return `在${name}放慢脚步，让沿途的光影成为这段旅程的注脚。`
  }
}
