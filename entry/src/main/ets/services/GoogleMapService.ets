import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { GOOGLE_MAPS_API_KEY, OPENWEATHER_API_KEY } from './ApiKeys'
import {
  MapViewport,
  SelectedRegion,
  TravelDayPlan,
  TravelPlaceCategory,
  TravelTimelineItem,
} from '../model/Types'

const GOOGLE_MAPS_API_KEY_PLACEHOLDER: string = 'YOUR_GOOGLE_MAPS_API_KEY'
const GOOGLE_MAPS_JS_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/js'
const GOOGLE_STATIC_MAP_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/staticmap'
const GOOGLE_PLACE_AUTOCOMPLETE_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
const GOOGLE_PLACE_DETAILS_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/place/details/json'
const GOOGLE_FIND_PLACE_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
const GOOGLE_PLACE_PHOTO_ENDPOINT: string = 'https://maps.googleapis.com/maps/api/place/photo'
const GOOGLE_MAPS_DIR_ENDPOINT: string = 'https://www.google.com/maps/dir/'
const GOOGLE_MAPS_WEB_ENDPOINT: string = 'https://www.google.com/maps'
const OPENWEATHER_TILE_ENDPOINT: string = 'https://tile.openweathermap.org/map'
const OPENWEATHER_CURRENT_ENDPOINT: string = 'https://api.openweathermap.org/data/2.5/weather'

export interface GoogleStaticMapRequest {
  region: SelectedRegion
  width: number
  height: number
  scale: number
  items: TravelTimelineItem[]
}

interface GoogleMapPoint {
  id: string
  label: string
  name: string
  category: string
  address: string
  note: string
  openingHours: string
  durationMinutes: number
  arriveTime: string
  leaveTime: string
  openStatus: string
  lat: number
  lng: number
  color: string
  transport: string
}

interface GoogleMapRegionPayload {
  centerLat: number
  centerLng: number
  zoom: number
}

export interface GooglePlaceSuggestion {
  placeId: string
  title: string
  subtitle: string
}

export interface GooglePlaceDetail {
  placeId: string
  title: string
  address: string
  summary: string
  latitude: number
  longitude: number
  category: TravelPlaceCategory
  openingHours: string
}

interface GooglePlacePredictionStructuredFormatting {
  main_text: string
  secondary_text?: string
}

interface GooglePlacePrediction {
  place_id: string
  description: string
  structured_formatting?: GooglePlacePredictionStructuredFormatting
}

interface GooglePlaceAutocompleteResponse {
  predictions: GooglePlacePrediction[]
  status: string
  error_message?: string
}

interface GooglePlaceLocation {
  lat: number
  lng: number
}

interface GooglePlaceGeometry {
  location?: GooglePlaceLocation
}

interface GooglePlaceOpeningHours {
  open_now?: boolean
  weekday_text?: string[]
}

interface GooglePlaceEditorialSummary {
  overview?: string
}

interface GooglePlaceDetailsResult {
  place_id?: string
  name?: string
  formatted_address?: string
  geometry?: GooglePlaceGeometry
  types?: string[]
  opening_hours?: GooglePlaceOpeningHours
  editorial_summary?: GooglePlaceEditorialSummary
}

interface GooglePlaceDetailsResponse {
  result?: GooglePlaceDetailsResult
  status: string
  error_message?: string
}

interface GooglePlacePhoto {
  photo_reference?: string
  html_attributions?: string[]
}

interface GoogleFindPlaceCandidate {
  photos?: GooglePlacePhoto[]
}

interface GoogleFindPlaceResponse {
  candidates?: GoogleFindPlaceCandidate[]
  status: string
  error_message?: string
}

export interface GooglePlacePhotoResult {
  imageUrl: string
  attribution: string
}

export class GoogleMapService {
  static hasApiKey(): boolean {
    const key: string = GOOGLE_MAPS_API_KEY.trim()
    return key.length > 0 && key !== GOOGLE_MAPS_API_KEY_PLACEHOLDER
  }

  static regionToViewport(region: SelectedRegion): MapViewport {
    const viewport: MapViewport = {
      northLat: region.north,
      southLat: region.south,
      eastLng: region.east,
      westLng: region.west,
      zoomLevel: region.zoom,
    }
    return viewport
  }

  static buildInteractiveMapUrl(region: SelectedRegion, items: TravelTimelineItem[]): string {
    if (!GoogleMapService.hasApiKey()) {
      return GoogleMapService.buildGoogleMapsUrl(region, items)
    }

    const html: string = GoogleMapService.buildInteractiveMapHtml(region, items)
    return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`
  }

  static buildInteractiveDayMapUrl(region: SelectedRegion, days: TravelDayPlan[]): string {
    if (!GoogleMapService.hasApiKey()) {
      const flattened: TravelTimelineItem[] = []
      for (let i = 0; i < days.length; i++) {
        for (let j = 0; j < days[i].items.length; j++) {
          flattened.push(days[i].items[j])
        }
      }
      return GoogleMapService.buildGoogleMapsUrl(region, flattened)
    }

    const html: string = GoogleMapService.buildInteractiveDayMapHtml(region, days)
    return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`
  }

  static buildGoogleMapsUrl(region: SelectedRegion, items: TravelTimelineItem[]): string {
    const points: GoogleMapPoint[] = GoogleMapService.toPoints(items)
    if (points.length > 1) {
      const origin: string = `${points[0].lat},${points[0].lng}`
      const destinationPoint: GoogleMapPoint = points[points.length - 1]
      const destination: string = `${destinationPoint.lat},${destinationPoint.lng}`
      let url: string = `${GOOGLE_MAPS_DIR_ENDPOINT}?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&travelmode=driving`
      const waypoints: string = GoogleMapService.buildWaypointText(points)
      if (waypoints.length > 0) {
        url = `${url}&waypoints=${encodeURIComponent(waypoints)}`
      }
      return url
    }

    if (points.length === 1) {
      const point: GoogleMapPoint = points[0]
      return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${point.lat},${point.lng}`)}`
    }

    return `${GOOGLE_MAPS_WEB_ENDPOINT}?q=${region.centerLat},${region.centerLng}&z=${Math.round(region.zoom)}&output=embed`
  }

  static buildGoogleMapsEmbedPageUrl(region: SelectedRegion, items: TravelTimelineItem[]): string {
    const iframeUrl: string = GoogleMapService.buildGoogleMapsUrl(region, items)
    const html: string = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html, body, iframe {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      border: 0;
      overflow: hidden;
      background: #eef3f7;
    }
  </style>
</head>
<body>
  <iframe
    src="${GoogleMapService.escapeHtmlAttribute(iframeUrl)}"
    loading="eager"
    allowfullscreen
    referrerpolicy="no-referrer-when-downgrade">
  </iframe>
</body>
</html>`
    return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`
  }

  static async searchPlaceSuggestions(input: string): Promise<GooglePlaceSuggestion[]> {
    const query: string = input.trim()
    if (query.length < 2 || !GoogleMapService.hasApiKey()) {
      return []
    }

    const url: string = `${GOOGLE_PLACE_AUTOCOMPLETE_ENDPOINT}?input=${encodeURIComponent(query)}&language=zh-CN&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())}`
    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000,
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return []
      }
      const body: string = response.result as string
      const parsed: GooglePlaceAutocompleteResponse = JSON.parse(body) as GooglePlaceAutocompleteResponse
      if (parsed.status !== 'OK' && parsed.status !== 'ZERO_RESULTS') {
        console.error(`Google place autocomplete failed: ${parsed.status} ${parsed.error_message ? parsed.error_message : ''}`)
        return []
      }
      const suggestions: GooglePlaceSuggestion[] = []
      const maxCount: number = Math.min(parsed.predictions.length, 5)
      for (let i = 0; i < maxCount; i++) {
        const prediction: GooglePlacePrediction = parsed.predictions[i]
        let title: string = prediction.description
        let subtitle: string = ''
        if (prediction.structured_formatting !== undefined) {
          title = prediction.structured_formatting.main_text
          if (prediction.structured_formatting.secondary_text !== undefined) {
            subtitle = prediction.structured_formatting.secondary_text
          }
        }
        suggestions.push({
          placeId: prediction.place_id,
          title: title,
          subtitle: subtitle,
        })
      }
      return suggestions
    } catch (e) {
      const err = e as Error
      console.error(`Google place autocomplete request failed: ${err.message}`)
      return []
    } finally {
      httpRequest.destroy()
    }
  }

  static async fetchPlaceDetail(placeId: string): Promise<GooglePlaceDetail | null> {
    const id: string = placeId.trim()
    if (id.length === 0 || !GoogleMapService.hasApiKey()) {
      return null
    }

    const fields: string = 'place_id,name,formatted_address,geometry,types,opening_hours,editorial_summary'
    const url: string = `${GOOGLE_PLACE_DETAILS_ENDPOINT}?place_id=${encodeURIComponent(id)}&fields=${encodeURIComponent(fields)}&language=zh-CN&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())}`
    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000,
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return null
      }
      const body: string = response.result as string
      const parsed: GooglePlaceDetailsResponse = JSON.parse(body) as GooglePlaceDetailsResponse
      if (parsed.status !== 'OK' || parsed.result === undefined) {
        console.error(`Google place details failed: ${parsed.status} ${parsed.error_message ? parsed.error_message : ''}`)
        return null
      }
      const result: GooglePlaceDetailsResult = parsed.result!
      if (result.geometry === undefined || result.geometry.location === undefined) {
        return null
      }
      const geometry: GooglePlaceGeometry = result.geometry!
      const location: GooglePlaceLocation = geometry.location!
      const types: string[] = result.types === undefined ? [] : result.types
      const openingHours: string = GoogleMapService.resolveOpeningHours(result.opening_hours)
      const detail: GooglePlaceDetail = {
        placeId: result.place_id === undefined ? id : result.place_id,
        title: result.name === undefined ? '' : result.name,
        address: result.formatted_address === undefined ? '' : result.formatted_address,
        summary: result.editorial_summary === undefined || result.editorial_summary.overview === undefined ? '' : result.editorial_summary.overview,
        latitude: location.lat,
        longitude: location.lng,
        category: GoogleMapService.resolvePlaceCategory(types),
        openingHours: openingHours,
      }
      return detail
    } catch (e) {
      const err = e as Error
      console.error(`Google place details request failed: ${err.message}`)
      return null
    } finally {
      httpRequest.destroy()
    }
  }

  static async fetchPlacePhoto(query: string, photoIndex: number = 0): Promise<GooglePlacePhotoResult | null> {
    const keyword: string = query.trim()
    if (keyword.length === 0 || !GoogleMapService.hasApiKey()) {
      return null
    }

    const key: string = GOOGLE_MAPS_API_KEY.trim()
    const url: string = `${GOOGLE_FIND_PLACE_ENDPOINT}?input=${encodeURIComponent(keyword)}&inputtype=textquery&fields=photos&language=zh-CN&key=${encodeURIComponent(key)}`
    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000,
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return null
      }
      const body: string = response.result as string
      const parsed: GoogleFindPlaceResponse = JSON.parse(body) as GoogleFindPlaceResponse
      const candidates: GoogleFindPlaceCandidate[] = parsed.candidates === undefined ? [] : parsed.candidates
      if (parsed.status !== 'OK' || candidates.length === 0 || candidates[0].photos === undefined || candidates[0].photos!.length === 0) {
        return null
      }
      const photos: GooglePlacePhoto[] = candidates[0].photos!
      const normalizedIndex: number = Math.abs(photoIndex) % photos.length
      const photo: GooglePlacePhoto = photos[normalizedIndex]
      if (photo.photo_reference === undefined || photo.photo_reference.length === 0) {
        return null
      }
      const imageUrl: string = `${GOOGLE_PLACE_PHOTO_ENDPOINT}?maxwidth=960&photo_reference=${encodeURIComponent(photo.photo_reference)}&key=${encodeURIComponent(key)}`
      const attribution: string = GoogleMapService.resolvePhotoAttribution(photo.html_attributions)
      return { imageUrl, attribution }
    } catch (e) {
      const err = e as Error
      console.error(`Google place photo request failed: ${err.message}`)
      return null
    } finally {
      httpRequest.destroy()
    }
  }

  static buildPlaceMapCoverUrl(latitude: number, longitude: number): string {
    if (!GoogleMapService.hasApiKey() || latitude !== latitude || longitude !== longitude) {
      return ''
    }
    const center: string = `${latitude},${longitude}`
    const marker: string = `color:0x237C7A|${center}`
    return `${GOOGLE_STATIC_MAP_ENDPOINT}?center=${encodeURIComponent(center)}&zoom=16&size=640x400&scale=2&maptype=terrain&markers=${encodeURIComponent(marker)}&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())}`
  }

  private static resolvePhotoAttribution(attributions?: string[]): string {
    if (attributions === undefined || attributions.length === 0) {
      return '图片来源：Google Places'
    }
    const plainText: string = attributions[0].replace(/<[^>]+>/g, '').trim()
    return plainText.length > 0 ? `图片：${plainText}` : '图片来源：Google Places'
  }

  private static resolveOpeningHours(openingHours?: GooglePlaceOpeningHours): string {
    if (openingHours === undefined) {
      return '营业时间待确认'
    }
    if (openingHours.weekday_text !== undefined && openingHours.weekday_text.length > 0) {
      return openingHours.weekday_text[0]
    }
    if (openingHours.open_now !== undefined) {
      return openingHours.open_now ? '当前营业' : '当前未营业'
    }
    return '营业时间待确认'
  }

  private static resolvePlaceCategory(types: string[]): TravelPlaceCategory {
    if (types.indexOf('restaurant') >= 0 || types.indexOf('food') >= 0 || types.indexOf('meal_takeaway') >= 0) {
      return 'restaurant'
    }
    if (types.indexOf('cafe') >= 0 || types.indexOf('bakery') >= 0) {
      return 'cafe'
    }
    if (types.indexOf('museum') >= 0 || types.indexOf('art_gallery') >= 0) {
      return 'museum'
    }
    if (types.indexOf('shopping_mall') >= 0 || types.indexOf('store') >= 0) {
      return 'shopping'
    }
    return 'landmark'
  }

  static buildExplorePoiMapUrl(region: SelectedRegion): string {
    if (!GoogleMapService.hasApiKey()) {
      return GoogleMapService.buildGoogleMapsEmbedPageUrl(region, [])
    }

    const regionPayload: GoogleMapRegionPayload = {
      centerLat: region.centerLat,
      centerLng: region.centerLng,
      zoom: region.zoom,
    }
    const regionJson: string = GoogleMapService.escapeScriptJson(JSON.stringify(regionPayload))
    const key: string = encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())
    const html: string = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html, body, #map {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
      background: #eef3f7;
      font-family: sans-serif;
    }
    .poi-card {
      width: 248px;
      color: #111827;
      font-size: 12px;
      line-height: 1.45;
    }
    .poi-photo {
      width: 248px;
      height: 118px;
      object-fit: cover;
      display: block;
      margin: -8px -8px 10px -8px;
      border-radius: 10px 10px 0 0;
      background: #e5e7eb;
    }
    .poi-title {
      font-size: 15px;
      font-weight: 700;
      margin-bottom: 6px;
    }
    .poi-summary {
      color: #374151;
      margin-top: 6px;
    }
    .poi-meta {
      color: #4b5563;
      margin-top: 4px;
    }
    button.gm-ui-hover-effect {
      display: none !important;
    }
    #error {
      display: none;
      position: absolute;
      left: 16px;
      right: 16px;
      bottom: 16px;
      z-index: 3;
      padding: 12px 14px;
      border-radius: 14px;
      background: rgba(255,255,255,0.96);
      color: #7f1d1d;
      font-size: 12px;
      box-shadow: 0 8px 26px rgba(15,23,42,0.16);
    }
${GoogleMapService.buildWeatherControlStyle()}
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="error"></div>
  <script>
    const region = ${regionJson};
    let map;
    let infoWindow;
    let placesService;
    let autoPoiMarkers = [];
    let knownPlaceIds = {};

    function showError(message) {
      const el = document.getElementById('error');
      el.textContent = message;
      el.style.display = 'block';
    }

    function escapeHtml(value) {
      if (!value) {
        return '';
      }
      return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }

    function cleanAddress(value) {
      if (!value) {
        return '';
      }
      return String(value)
        .replace(/,?\\s*\\d{5,6}\\s*$/, '')
        .replace(/\\s{2,}/g, ' ')
        .trim();
    }

    function placeAddress(place) {
      return cleanAddress(place.vicinity || place.formatted_address || '');
    }

    function placePhoto(place) {
      if (!place.photos || place.photos.length === 0) {
        return '';
      }
      return place.photos[0].getUrl({
        maxWidth: 496,
        maxHeight: 236
      });
    }

    function placeMapCover(place) {
      if (!place || !place.geometry || !place.geometry.location) {
        return '';
      }
      const location = place.geometry.location;
      const lat = typeof location.lat === 'function' ? location.lat() : location.lat;
      const lng = typeof location.lng === 'function' ? location.lng() : location.lng;
      if (typeof lat !== 'number' || typeof lng !== 'number') {
        return '';
      }
      const center = lat + ',' + lng;
      const marker = 'color:0x237C7A|' + center;
      return '${GOOGLE_STATIC_MAP_ENDPOINT}?center=' + encodeURIComponent(center) +
        '&zoom=16&size=496x236&scale=2&maptype=terrain&markers=' + encodeURIComponent(marker) + '&key=${key}';
    }

    function placeTypesText(place) {
      if (!place.types || place.types.length === 0) {
        return '';
      }
      const labels = [];
      const map = {
        tourist_attraction: '景点',
        museum: '博物馆',
        park: '公园',
        restaurant: '餐厅',
        cafe: '咖啡',
        bakery: '烘焙',
        shopping_mall: '购物',
        art_gallery: '展览',
        point_of_interest: '兴趣点'
      };
      for (let i = 0; i < place.types.length; i++) {
        const label = map[place.types[i]];
        if (label && labels.indexOf(label) < 0) {
          labels.push(label);
        }
      }
      return labels.slice(0, 3).join(' · ');
    }

    function fallbackSummary(place) {
      if (place.editorial_summary && place.editorial_summary.overview) {
        return String(place.editorial_summary.overview);
      }
      const typeText = placeTypesText(place);
      const rating = place.rating ? '评分 ' + place.rating : '';
      const address = placeAddress(place);
      const parts = [typeText, rating].filter(Boolean).join('，');
      if (parts && address) {
        return parts + '。位于' + address + '，可作为附近游玩或休息点参考。';
      }
      if (parts) {
        return parts + '。可作为附近游玩或休息点参考。';
      }
      if (address) {
        return '位于' + address + '，可作为附近游玩或休息点参考。';
      }
      return '';
    }

    function openStatusText(place) {
      if (!place.opening_hours) {
        return '';
      }
      if (typeof place.opening_hours.isOpen === 'function') {
        return place.opening_hours.isOpen() ? '营业中' : '';
      }
      if (place.opening_hours.open_now === true) {
        return '营业中';
      }
      return '';
    }

    function placeCard(place) {
      const title = escapeHtml(place.name || '地点详情');
      const address = escapeHtml(placeAddress(place));
      const photo = placePhoto(place) || placeMapCover(place);
      const summaryText = fallbackSummary(place);
      const summary = escapeHtml(summaryText);
      const rating = place.rating ? '评分 ' + place.rating : '';
      const open = openStatusText(place);
      const parts = [rating, open].filter(Boolean).join(' · ');
      return '<div class="poi-card">' +
        (photo ? '<img class="poi-photo" src="' + escapeHtml(photo) + '">' : '') +
        '<div class="poi-title">' + title + '</div>' +
        '<div class="poi-summary">' + (summary ? summary : 'Google 暂时没有返回详细介绍，但可以继续查看地址、营业状态和评分。') + '</div>' +
        (address ? '<div>' + address + '</div>' : '') +
        (parts ? '<div class="poi-meta">' + escapeHtml(parts) + '</div>' : '') +
      '</div>';
    }

    function showCoordinateFallback(position) {
      const fallbackPlace = {
        name: '附近探索',
        geometry: { location: position },
        types: []
      };
      infoWindow.setContent(placeCard(fallbackPlace));
      infoWindow.setPosition(position);
      infoWindow.open(map);
    }

    function openPlace(placeId, position, fallbackPlace) {
      if (!placeId) {
        return;
      }
      if (window.WanderSketchMap && window.WanderSketchMap.selectPlace) {
        window.WanderSketchMap.selectPlace(placeId);
      }
      infoWindow.close();
      if (fallbackPlace) {
        infoWindow.setContent(placeCard(fallbackPlace));
        infoWindow.setPosition(position);
        infoWindow.open(map);
      }
      placesService.getDetails({
        placeId: placeId,
        fields: ['name', 'formatted_address', 'vicinity', 'rating', 'opening_hours', 'geometry', 'photos', 'types', 'editorial_summary']
      }, (place, status) => {
        if (status !== google.maps.places.PlacesServiceStatus.OK || !place) {
          if (!fallbackPlace) {
            searchNearbyFallback(position);
          }
          return;
        }
        infoWindow.setContent(placeCard(place));
        if (place.geometry && place.geometry.location) {
          infoWindow.setPosition(place.geometry.location);
        } else {
          infoWindow.setPosition(position);
        }
        infoWindow.open(map);
      });
    }

    function searchNearbyFallback(position) {
      function openNearbyResult(results, status) {
        if (status === google.maps.places.PlacesServiceStatus.OK && results && results.length > 0) {
          let result = results[0];
          for (let i = 0; i < results.length; i++) {
            if (placePhoto(results[i])) {
              result = results[i];
              break;
            }
          }
          const resultPosition = result.geometry && result.geometry.location ? result.geometry.location : position;
          if (result.place_id) {
            openPlace(result.place_id, resultPosition, result);
          } else {
            infoWindow.setContent(placeCard(result));
            infoWindow.setPosition(resultPosition);
            infoWindow.open(map);
          }
          return true;
        }
        return false;
      }

      function searchKeywordFallback(keyword, radius, onDone) {
        placesService.nearbySearch({
          location: position,
          radius: radius,
          keyword: keyword
        }, (results, status) => {
          onDone(openNearbyResult(results, status));
        });
      }

      placesService.nearbySearch({
        location: position,
        rankBy: google.maps.places.RankBy.DISTANCE
      }, (results, status) => {
        if (openNearbyResult(results, status)) {
          return;
        }
        const searchQueue = [
          { keyword: 'tourist_attraction', radius: 1200 },
          { keyword: 'museum', radius: 1200 },
          { keyword: 'park', radius: 1200 },
          { keyword: 'restaurant', radius: 900 },
          { keyword: 'cafe', radius: 900 },
          { keyword: 'shopping_mall', radius: 1200 },
          { keyword: '景点', radius: 1500 },
          { keyword: '餐厅', radius: 1200 },
          { keyword: '咖啡', radius: 1000 },
          { keyword: '购物', radius: 1200 }
        ];

        function runSearch(index) {
          if (index >= searchQueue.length) {
            showCoordinateFallback(position);
            return;
          }
          const entry = searchQueue[index];
          searchKeywordFallback(entry.keyword, entry.radius, (found) => {
            if (!found) {
              runSearch(index + 1);
            }
          });
        }

        runSearch(0);
      });
    }

    function addAutoPoiMarkersByType(type, markerColor) {
      placesService.nearbySearch({
        location: { lat: region.centerLat, lng: region.centerLng },
        radius: 4200,
        type: type
      }, (results, status) => {
        if (status !== google.maps.places.PlacesServiceStatus.OK || !results) {
          return;
        }
        const maxCount = Math.min(results.length, 12);
        for (let i = 0; i < maxCount; i++) {
          const place = results[i];
          if (!place.geometry || !place.geometry.location || !place.place_id) {
            continue;
          }
          if (knownPlaceIds[place.place_id]) {
            continue;
          }
          knownPlaceIds[place.place_id] = true;
          const marker = new google.maps.Marker({
            map: map,
            position: place.geometry.location,
            title: place.name,
            icon: {
              path: google.maps.SymbolPath.CIRCLE,
              scale: 10,
              fillColor: markerColor,
              fillOpacity: 0.86,
              strokeColor: '#ffffff',
              strokeWeight: 2
            },
            zIndex: 20
          });
          marker.addListener('click', () => {
            openPlace(place.place_id, place.geometry.location, place);
          });
          autoPoiMarkers.push(marker);
        }
      });
    }

    function addAutoPoiMarkers() {
      addAutoPoiMarkersByType('tourist_attraction', '#111111');
      addAutoPoiMarkersByType('museum', '#2563eb');
      addAutoPoiMarkersByType('park', '#15803d');
      addAutoPoiMarkersByType('restaurant', '#dc2626');
      addAutoPoiMarkersByType('cafe', '#92400e');
    }

${GoogleMapService.buildWeatherLayerScript()}

    function initMap() {
      map = new google.maps.Map(document.getElementById('map'), {
        center: { lat: region.centerLat, lng: region.centerLng },
        zoom: region.zoom,
        mapTypeId: 'roadmap',
        clickableIcons: true,
        gestureHandling: 'greedy',
        fullscreenControl: false,
        streetViewControl: false,
        mapTypeControl: false,
        zoomControl: true,
        language: 'zh-CN'
      });
      installWeatherOverlay(map);
      infoWindow = new google.maps.InfoWindow({ headerDisabled: true });
      placesService = new google.maps.places.PlacesService(map);
      map.addListener('click', (event) => {
        if (event.placeId) {
          event.stop();
          openPlace(event.placeId, event.latLng, null);
          return;
        }
        if (infoWindow.getMap()) {
          infoWindow.close();
          return;
        }
        searchNearbyFallback(event.latLng);
      });
      addAutoPoiMarkers();
    }

    window.initMap = initMap;
    window.gm_authFailure = function() {
      showError('Google Maps API key 无法使用，请检查 Maps JavaScript API 和 Places API 是否已启用。');
    };
  </script>
  <script async defer src="${GOOGLE_MAPS_JS_ENDPOINT}?key=${key}&callback=initMap&libraries=places&v=weekly&language=zh-CN"></script>
</body>
</html>`
    return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`
  }

  static buildStaticMapUrl(request: GoogleStaticMapRequest): string {
    if (!GoogleMapService.hasApiKey()) {
      return ''
    }

    const region: SelectedRegion = request.region
    let url: string = `${GOOGLE_STATIC_MAP_ENDPOINT}?center=${region.centerLat},${region.centerLng}&zoom=${Math.round(region.zoom)}&size=${request.width}x${request.height}&scale=${request.scale}&maptype=roadmap&language=zh-CN&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())}`
    const points: GoogleMapPoint[] = GoogleMapService.toPoints(request.items)
    for (let i = 0; i < points.length; i++) {
      const point: GoogleMapPoint = points[i]
      url = `${url}&markers=${encodeURIComponent(`color:red|label:${point.label}|${point.lat},${point.lng}`)}`
    }
    const path: string = GoogleMapService.buildStaticPath(points)
    if (path.length > 0) {
      url = `${url}&path=${encodeURIComponent(path)}`
    }
    return url
  }

  static async fetchStaticMapBase64(request: GoogleStaticMapRequest): Promise<string> {
    const url: string = GoogleMapService.buildStaticMapUrl(request)
    if (url.length === 0) {
      return ''
    }

    const httpRequest: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 60000,
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return ''
      }

      const buffer: ArrayBuffer = response.result as ArrayBuffer
      const helper: util.Base64Helper = new util.Base64Helper()
      return helper.encodeToStringSync(new Uint8Array(buffer))
    } catch (e) {
      const err = e as Error
      console.error(`Google Static Maps request failed: ${err.message}`)
      return ''
    } finally {
      httpRequest.destroy()
    }
  }

  private static buildInteractiveMapHtml(region: SelectedRegion, items: TravelTimelineItem[]): string {
    const points: GoogleMapPoint[] = GoogleMapService.toPoints(items)
    const regionPayload: GoogleMapRegionPayload = {
      centerLat: region.centerLat,
      centerLng: region.centerLng,
      zoom: region.zoom,
    }
    const pointsJson: string = GoogleMapService.escapeScriptJson(JSON.stringify(points))
    const regionJson: string = GoogleMapService.escapeScriptJson(JSON.stringify(regionPayload))
    const key: string = encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())

    return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
    body { background: #f6f1e8; font-family: sans-serif; }
    button.gm-ui-hover-effect { display: none !important; }
    #error {
      display: none;
      position: absolute;
      left: 12px;
      right: 12px;
      bottom: 12px;
      padding: 10px 12px;
      border-radius: 8px;
      color: #7a251c;
      background: rgba(255,255,255,0.94);
      font-size: 12px;
      line-height: 1.45;
      box-shadow: 0 4px 18px rgba(0,0,0,0.14);
    }
${GoogleMapService.buildWeatherControlStyle()}
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="error"></div>
  <script>
    const points = ${pointsJson};
    const region = ${regionJson};
    let infoWindow;

    function showError(message) {
      const el = document.getElementById('error');
      el.textContent = message;
      el.style.display = 'block';
    }

    function latLng(point) {
      return { lat: point.lat, lng: point.lng };
    }

    function escapeHtml(value) {
      return String(value).replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }[char]));
    }

    function categoryLabel(value) {
      const map = {
        restaurant: '餐厅',
        landmark: '景点',
        shopping: '购物',
        museum: '展馆',
        cafe: '咖啡'
      };
      return map[value] || '地点';
    }

    function markerCard(point) {
      const time = point.arriveTime && point.leaveTime ? point.arriveTime + '-' + point.leaveTime : '';
      const meta = [time, categoryLabel(point.category), point.openStatus].filter(Boolean).join(' · ');
      const duration = point.durationMinutes ? '建议停留 ' + point.durationMinutes + ' 分钟' : '';
      return '<div style="min-width:220px;max-width:280px;color:#111827;font-family:sans-serif;line-height:1.45;">' +
        '<div style="font-size:16px;font-weight:800;margin-bottom:4px;">' + escapeHtml(point.name) + '</div>' +
        (meta ? '<div style="font-size:12px;color:#237C7A;font-weight:700;margin-bottom:6px;">' + escapeHtml(meta) + '</div>' : '') +
        (point.address ? '<div style="font-size:12px;color:#4B5563;margin-bottom:6px;">' + escapeHtml(point.address) + '</div>' : '') +
        (point.note ? '<div style="font-size:13px;color:#374151;margin-bottom:6px;">' + escapeHtml(point.note) + '</div>' : '') +
        (point.openingHours ? '<div style="font-size:12px;color:#6B7280;margin-bottom:4px;">营业时间：' + escapeHtml(point.openingHours) + '</div>' : '') +
        (duration ? '<div style="font-size:12px;color:#6B7280;margin-bottom:4px;">' + escapeHtml(duration) + '</div>' : '') +
        (point.transport ? '<div style="font-size:12px;color:#6B7280;border-top:1px solid #E5E7EB;margin-top:8px;padding-top:7px;">交通：' + escapeHtml(point.transport) + '</div>' : '') +
      '</div>';
    }

    function addMarkers(map) {
      points.forEach((point) => {
        const marker = new google.maps.Marker({
          position: latLng(point),
          map,
          label: point.label,
          title: point.name
        });
        marker.addListener('click', () => {
          infoWindow.setContent(markerCard(point));
          infoWindow.open(map, marker);
          if (window.WanderSketchMap && window.WanderSketchMap.selectPlace) {
            window.WanderSketchMap.selectPlace(point.id);
          }
        });
      });
    }

    function fitPoints(map) {
      if (points.length === 0) {
        return;
      }
      const bounds = new google.maps.LatLngBounds();
      points.forEach((point) => bounds.extend(latLng(point)));
      map.fitBounds(bounds, 56);
    }

    function drawFallbackPath(map) {
      addMarkers(map);
      fitPoints(map);
    }

    function routePointsSequentially(map, service) {
      let nextIndex = 1;
      let successfulRoutes = 0;
      function requestNext() {
        if (nextIndex >= points.length) {
          addMarkers(map);
          fitPoints(map);
          if (successfulRoutes === 0) {
            showError('Google route planning unavailable');
          }
          return;
        }
        const index = nextIndex;
        nextIndex += 1;
        const renderer = new google.maps.DirectionsRenderer({
          map,
          suppressMarkers: true,
          preserveViewport: true,
          polylineOptions: {
            strokeColor: '#7A7A7A',
            strokeOpacity: 0.48,
            strokeWeight: 5
          }
        });
        service.route({
          origin: latLng(points[index - 1]),
          destination: latLng(points[index]),
          travelMode: google.maps.TravelMode.DRIVING
        }, (response, status) => {
          if (status === 'OK') {
            successfulRoutes += 1;
            renderer.setDirections(response);
          }
          setTimeout(requestNext, 180);
        });
      }
      requestNext();
    }

${GoogleMapService.buildWeatherLayerScript()}

    function initMap() {
      const map = new google.maps.Map(document.getElementById('map'), {
        center: { lat: region.centerLat, lng: region.centerLng },
        zoom: region.zoom,
        mapTypeId: 'roadmap',
        gestureHandling: 'greedy',
        clickableIcons: false,
        fullscreenControl: false,
        streetViewControl: false,
        mapTypeControl: false,
        zoomControl: true
      });
      installWeatherOverlay(map);
      infoWindow = new google.maps.InfoWindow({ headerDisabled: true });
      map.addListener('click', () => {
        if (infoWindow.getMap()) {
          infoWindow.close();
        }
      });

      if (points.length < 2) {
        drawFallbackPath(map);
        return;
      }

      const service = new google.maps.DirectionsService();
      routePointsSequentially(map, service);
    }

    window.initMap = initMap;
  </script>
  <script async defer src="${GOOGLE_MAPS_JS_ENDPOINT}?key=${key}&callback=initMap&libraries=routes&v=weekly&language=zh-CN"></script>
</body>
</html>`
  }

  private static buildInteractiveDayMapHtml(region: SelectedRegion, days: TravelDayPlan[]): string {
    const dayPoints: GoogleMapPoint[][] = GoogleMapService.toDayPoints(days)
    const regionPayload: GoogleMapRegionPayload = {
      centerLat: region.centerLat,
      centerLng: region.centerLng,
      zoom: region.zoom,
    }
    const dayPointsJson: string = GoogleMapService.escapeScriptJson(JSON.stringify(dayPoints))
    const regionJson: string = GoogleMapService.escapeScriptJson(JSON.stringify(regionPayload))
    const key: string = encodeURIComponent(GOOGLE_MAPS_API_KEY.trim())

    return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
    body { background: #f6f1e8; font-family: sans-serif; }
    button.gm-ui-hover-effect { display: none !important; }
    #error {
      display: none;
      position: absolute;
      left: 12px;
      right: 12px;
      bottom: 12px;
      padding: 9px 11px;
      border-radius: 8px;
      color: #7a251c;
      background: rgba(255,255,255,0.94);
      font-size: 12px;
      line-height: 1.45;
      box-shadow: 0 4px 18px rgba(0,0,0,0.14);
    }
${GoogleMapService.buildWeatherControlStyle()}
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="error"></div>
  <script>
    const dayPoints = ${dayPointsJson};
    const region = ${regionJson};
    let infoWindow;

    function showError(message) {
      const el = document.getElementById('error');
      el.textContent = message;
      el.style.display = 'block';
    }

    function latLng(point) {
      return { lat: point.lat, lng: point.lng };
    }

    function escapeHtml(value) {
      return String(value).replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }[char]));
    }

    function categoryLabel(value) {
      const map = {
        restaurant: '餐厅',
        landmark: '景点',
        shopping: '购物',
        museum: '展馆',
        cafe: '咖啡'
      };
      return map[value] || '地点';
    }

    function markerCard(point) {
      const time = point.arriveTime && point.leaveTime ? point.arriveTime + '-' + point.leaveTime : '';
      const meta = [time, categoryLabel(point.category), point.openStatus].filter(Boolean).join(' · ');
      const duration = point.durationMinutes ? '建议停留 ' + point.durationMinutes + ' 分钟' : '';
      return '<div style="min-width:220px;max-width:280px;color:#111827;font-family:sans-serif;line-height:1.45;">' +
        '<div style="font-size:16px;font-weight:800;margin-bottom:4px;">' + escapeHtml(point.name) + '</div>' +
        (meta ? '<div style="font-size:12px;color:#237C7A;font-weight:700;margin-bottom:6px;">' + escapeHtml(meta) + '</div>' : '') +
        (point.address ? '<div style="font-size:12px;color:#4B5563;margin-bottom:6px;">' + escapeHtml(point.address) + '</div>' : '') +
        (point.note ? '<div style="font-size:13px;color:#374151;margin-bottom:6px;">' + escapeHtml(point.note) + '</div>' : '') +
        (point.openingHours ? '<div style="font-size:12px;color:#6B7280;margin-bottom:4px;">营业时间：' + escapeHtml(point.openingHours) + '</div>' : '') +
        (duration ? '<div style="font-size:12px;color:#6B7280;margin-bottom:4px;">' + escapeHtml(duration) + '</div>' : '') +
        (point.transport ? '<div style="font-size:12px;color:#6B7280;border-top:1px solid #E5E7EB;margin-top:8px;padding-top:7px;">交通：' + escapeHtml(point.transport) + '</div>' : '') +
      '</div>';
    }

    function addMarkers(map, points) {
      points.forEach((point) => {
        const marker = new google.maps.Marker({
          position: latLng(point),
          map,
          label: {
            text: point.label,
            color: '#ffffff',
            fontSize: '12px',
            fontWeight: '700'
          },
          title: point.name,
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            fillColor: point.color,
            fillOpacity: 1,
            strokeColor: '#ffffff',
            strokeWeight: 2,
            scale: 12
          }
        });
        marker.addListener('click', () => {
          infoWindow.setContent(markerCard(point));
          infoWindow.open(map, marker);
          if (window.WanderSketchMap && window.WanderSketchMap.selectPlace) {
            window.WanderSketchMap.selectPlace(point.id);
          }
        });
      });
    }

    function fitAll(map) {
      const bounds = new google.maps.LatLngBounds();
      let count = 0;
      dayPoints.forEach((points) => {
        points.forEach((point) => {
          bounds.extend(latLng(point));
          count += 1;
        });
      });
      if (count > 0) {
        map.fitBounds(bounds, 58);
      }
    }

    function drawFallbackPath(map, points, color) {
      addMarkers(map, points);
    }

    function routeDay(map, service, points, onDone) {
      if (points.length < 2) {
        drawFallbackPath(map, points, '#7A7A7A');
        onDone();
        return;
      }
      function routeSegmentsSequentially() {
        let nextIndex = 1;
        function requestNext() {
          if (nextIndex >= points.length) {
            addMarkers(map, points);
            onDone();
            return;
          }
          const index = nextIndex;
          nextIndex += 1;
          const renderer = new google.maps.DirectionsRenderer({
            map,
            suppressMarkers: true,
            preserveViewport: true,
            polylineOptions: {
              strokeColor: '#7A7A7A',
              strokeOpacity: 0.48,
              strokeWeight: 5
            }
          });
          service.route({
            origin: latLng(points[index - 1]),
            destination: latLng(points[index]),
            travelMode: google.maps.TravelMode.DRIVING
          }, (response, status) => {
            if (status === 'OK') {
              renderer.setDirections(response);
            }
            setTimeout(requestNext, 180);
          });
        }
        requestNext();
      }
      routeSegmentsSequentially();
    }

${GoogleMapService.buildWeatherLayerScript()}

    function initMap() {
      const map = new google.maps.Map(document.getElementById('map'), {
        center: { lat: region.centerLat, lng: region.centerLng },
        zoom: region.zoom,
        mapTypeId: 'roadmap',
        gestureHandling: 'greedy',
        clickableIcons: false,
        fullscreenControl: false,
        streetViewControl: false,
        mapTypeControl: false,
        zoomControl: true
      });
      installWeatherOverlay(map);
      infoWindow = new google.maps.InfoWindow({ headerDisabled: true });
      map.addListener('click', () => {
        if (infoWindow.getMap()) {
          infoWindow.close();
        }
      });
      const service = new google.maps.DirectionsService();
      fitAll(map);
      let nextDayIndex = 0;
      function routeNextDay() {
        if (nextDayIndex >= dayPoints.length) {
          return;
        }
        const points = dayPoints[nextDayIndex];
        nextDayIndex += 1;
        routeDay(map, service, points, () => {
          setTimeout(routeNextDay, 250);
        });
      }
      routeNextDay();
    }

    window.initMap = initMap;
  </script>
  <script async defer src="${GOOGLE_MAPS_JS_ENDPOINT}?key=${key}&callback=initMap&libraries=routes&v=weekly&language=zh-CN"></script>
</body>
</html>`
  }

  private static buildWeatherControlStyle(): string {
    return `
    .weather-card {
      min-width: 132px;
      max-width: 176px;
      margin: 10px 10px 0 0;
      padding: 10px 11px;
      border-radius: 12px;
      background: rgba(255,255,255,0.94);
      color: #111827;
      box-shadow: 0 8px 24px rgba(15,23,42,0.18);
      font-family: sans-serif;
      line-height: 1.25;
      backdrop-filter: blur(8px);
    }
    .weather-card .weather-label {
      color: #237C7A;
      font-size: 11px;
      font-weight: 700;
      margin-bottom: 5px;
    }
    .weather-card .weather-main {
      display: flex;
      align-items: center;
      gap: 7px;
      min-height: 30px;
    }
    .weather-card .weather-temp {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: 0;
    }
    .weather-card .weather-icon {
      width: 30px;
      height: 30px;
      flex: 0 0 30px;
    }
    .weather-card .weather-desc {
      margin-top: 3px;
      color: #374151;
      font-size: 12px;
      word-break: break-word;
    }
    .weather-card .weather-meta {
      margin-top: 5px;
      color: #6B7280;
      font-size: 11px;
    }`
  }

  private static buildWeatherLayerScript(): string {
    const weatherKey: string = encodeURIComponent(OPENWEATHER_API_KEY.trim())
    const tileEndpoint: string = OPENWEATHER_TILE_ENDPOINT
    const currentEndpoint: string = OPENWEATHER_CURRENT_ENDPOINT
    return `
    const openWeatherApiKey = '${weatherKey}';
    const openWeatherTileEndpoint = '${tileEndpoint}';
    const openWeatherCurrentEndpoint = '${currentEndpoint}';
    let weatherRequestSeq = 0;

    function escapeWeatherHtml(value) {
      if (value === undefined || value === null) {
        return '';
      }
      return String(value).replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }[char]));
    }

    function createWeatherTileLayer(layerName, opacity) {
      return new google.maps.ImageMapType({
        getTileUrl: function(coord, zoom) {
          if (zoom < 0 || zoom > 19) {
            return null;
          }
          const tileCount = Math.pow(2, zoom);
          if (coord.y < 0 || coord.y >= tileCount) {
            return null;
          }
          const wrappedX = ((coord.x % tileCount) + tileCount) % tileCount;
          return openWeatherTileEndpoint + '/' + layerName + '/' + zoom + '/' + wrappedX + '/' + coord.y + '.png?appid=' + openWeatherApiKey;
        },
        tileSize: new google.maps.Size(256, 256),
        opacity: opacity,
        name: layerName
      });
    }

    function setWeatherLoading(card) {
      card.innerHTML =
        '<div class="weather-label">当地天气</div>' +
        '<div class="weather-main"><div class="weather-temp">--°</div></div>' +
        '<div class="weather-desc">正在更新</div>' +
        '<div class="weather-meta">OpenWeather 图层</div>';
    }

    function updateWeatherCard(card, data) {
      const weather = data.weather && data.weather.length > 0 ? data.weather[0] : {};
      const temp = data.main && typeof data.main.temp === 'number' ? Math.round(data.main.temp) + '°' : '--°';
      const desc = weather.description ? weather.description : '天气实况';
      const icon = weather.icon ? '<img class="weather-icon" src="https://openweathermap.org/img/wn/' + escapeWeatherHtml(weather.icon) + '@2x.png">' : '';
      const place = data.name ? data.name : '当前区域';
      const humidity = data.main && data.main.humidity !== undefined ? '湿度 ' + data.main.humidity + '%' : '';
      const wind = data.wind && data.wind.speed !== undefined ? '风 ' + Math.round(data.wind.speed) + 'm/s' : '';
      const meta = [humidity, wind].filter(Boolean).join(' · ');
      card.innerHTML =
        '<div class="weather-label">' + escapeWeatherHtml(place) + '</div>' +
        '<div class="weather-main">' + icon + '<div class="weather-temp">' + escapeWeatherHtml(temp) + '</div></div>' +
        '<div class="weather-desc">' + escapeWeatherHtml(desc) + '</div>' +
        '<div class="weather-meta">' + escapeWeatherHtml(meta ? meta : 'OpenWeather 图层') + '</div>';
    }

    function refreshWeatherCard(map, card) {
      const center = map.getCenter();
      if (!center) {
        return;
      }
      const requestId = weatherRequestSeq + 1;
      weatherRequestSeq = requestId;
      const url = openWeatherCurrentEndpoint + '?lat=' + center.lat().toFixed(4) +
        '&lon=' + center.lng().toFixed(4) + '&appid=' + openWeatherApiKey +
        '&units=metric&lang=zh_cn';
      fetch(url)
        .then((response) => response.ok ? response.json() : null)
        .then((data) => {
          if (requestId !== weatherRequestSeq || !data) {
            return;
          }
          updateWeatherCard(card, data);
        })
        .catch(() => {
          if (requestId === weatherRequestSeq) {
            card.innerHTML =
              '<div class="weather-label">当地天气</div>' +
              '<div class="weather-main"><div class="weather-temp">--°</div></div>' +
              '<div class="weather-desc">天气暂不可用</div>' +
              '<div class="weather-meta">OpenWeather 图层已开启</div>';
          }
        });
    }

    function installWeatherOverlay(map) {
      if (!map || map.__wanderWeatherInstalled) {
        return;
      }
      map.__wanderWeatherInstalled = true;
      map.overlayMapTypes.insertAt(0, createWeatherTileLayer('precipitation_new', 0.58));
      map.overlayMapTypes.insertAt(1, createWeatherTileLayer('clouds_new', 0.35));
      const weatherCard = document.createElement('div');
      weatherCard.className = 'weather-card';
      setWeatherLoading(weatherCard);
      map.controls[google.maps.ControlPosition.RIGHT_TOP].push(weatherCard);
      refreshWeatherCard(map, weatherCard);
      map.addListener('idle', () => {
        refreshWeatherCard(map, weatherCard);
      });
    }`
  }

  private static toPoints(items: TravelTimelineItem[]): GoogleMapPoint[] {
    const points: GoogleMapPoint[] = []
    for (let i = 0; i < items.length; i++) {
      const item: TravelTimelineItem = items[i]
      if (GoogleMapService.isUsableCoordinate(item.place.latitude, item.place.longitude)) {
        points.push({
          id: item.place.id,
          label: `${i + 1}`,
          name: item.place.name,
          category: item.place.category,
          address: item.place.address,
          note: item.place.note,
          openingHours: item.place.openingHours,
          durationMinutes: item.place.recommendedDurationMinutes,
          arriveTime: item.arriveTime,
          leaveTime: item.leaveTime,
          openStatus: item.openStatus,
          lat: item.place.latitude,
          lng: item.place.longitude,
          color: '#237C7A',
          transport: item.commuteFromPrevious === undefined ? '' : item.commuteFromPrevious.transport,
        })
      }
    }
    return points
  }

  private static toDayPoints(days: TravelDayPlan[]): GoogleMapPoint[][] {
    const colors: string[] = ['#237C7A', '#3B82F6', '#7C3AED', '#F97316', '#E11D48', '#0891B2']
    const result: GoogleMapPoint[][] = []
    for (let i = 0; i < days.length; i++) {
      const day: TravelDayPlan = days[i]
      const points: GoogleMapPoint[] = []
      const color: string = colors[i % colors.length]
      for (let j = 0; j < day.items.length; j++) {
        const item: TravelTimelineItem = day.items[j]
        if (GoogleMapService.isUsableCoordinate(item.place.latitude, item.place.longitude)) {
          points.push({
            id: item.place.id,
            label: `${j + 1}`,
            name: item.place.name,
            category: item.place.category,
            address: item.place.address,
            note: item.place.note,
            openingHours: item.place.openingHours,
            durationMinutes: item.place.recommendedDurationMinutes,
            arriveTime: item.arriveTime,
            leaveTime: item.leaveTime,
            openStatus: item.openStatus,
            lat: item.place.latitude,
            lng: item.place.longitude,
            color,
            transport: item.commuteFromPrevious === undefined ? '' : item.commuteFromPrevious.transport,
          })
        }
      }
      if (points.length > 0) {
        result.push(points)
      }
    }
    return result
  }

  private static isUsableCoordinate(lat: number, lng: number): boolean {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && lat !== 0 && lng !== 0
  }

  private static buildWaypointText(points: GoogleMapPoint[]): string {
    if (points.length <= 2) {
      return ''
    }

    let value: string = ''
    for (let i = 1; i < points.length - 1; i++) {
      const point: GoogleMapPoint = points[i]
      if (value.length > 0) {
        value = `${value}|`
      }
      value = `${value}${point.lat},${point.lng}`
    }
    return value
  }

  private static buildStaticPath(points: GoogleMapPoint[]): string {
    if (points.length <= 1) {
      return ''
    }

    let path: string = 'color:0x7A7A7Aff|weight:5'
    for (let i = 0; i < points.length; i++) {
      const point: GoogleMapPoint = points[i]
      path = `${path}|${point.lat},${point.lng}`
    }
    return path
  }

  private static escapeScriptJson(value: string): string {
    return value.split('</').join('<\\/')
  }

  private static escapeHtmlAttribute(value: string): string {
    return value
      .split('&').join('&amp;')
      .split('"').join('&quot;')
      .split('<').join('&lt;')
      .split('>').join('&gt;')
  }
}
