import { TravelPlan } from '../model/Types'

interface PhotoSet {
  key: string
  urls: string[]
}

const DEFAULT_PHOTOS: string[] = [
  'https://commons.wikimedia.org/wiki/Special:FilePath/West%20Lake%20-%20Hangzhou,%20China.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Hangzhou%20West%20Lake%20at%20Night.jpg',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Shanghai%20skyline%20from%20the%20bund.jpg',
]

const PHOTO_SETS: PhotoSet[] = [
  {
    key: 'beijing',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Forbidden%20City%20Beijing%20(3019178959).jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Forbidden%20City%20Beijing%20(3019178959).jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Forbidden%20City%20Beijing%20(3019178959).jpg',
    ],
  },
  {
    key: 'shanghai',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Shanghai%20skyline%20from%20the%20bund.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Shanghai%20skyline%20from%20the%20bund.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/West%20Lake%20-%20Hangzhou,%20China.jpg',
    ],
  },
  {
    key: 'hangzhou',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/West%20Lake%20-%20Hangzhou,%20China.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sunset%20at%20West%20Lake%20(Xi%20Hu),%20Hangzhou%20(2790877585).jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Hangzhou%20West%20Lake%20at%20Night.jpg',
    ],
  },
  {
    key: 'wenzhou',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Wenzhou-city-in-Zhejiang-China.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Wenzhou-city-in-Zhejiang-China.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Wenzhou-city-in-Zhejiang-China.jpg',
    ],
  },
  {
    key: 'guangzhou',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Canton_Tower_20220626_%28cropped%29.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Canton%20Tower%20at%20night%2001.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Canton_Tower_20220626_%28cropped%29.jpg',
    ],
  },
  {
    key: 'shenzhen',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Shenzhen%20Nanshan%20district%20buildings%20view%20201612.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Shenzhen%2014.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/A%20spectacular%20view%20of%20Shenzhen%20Skyline.jpg',
    ],
  },
  {
    key: 'suzhou',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Lotus%20flower%20%28Suzhou,%20China%29.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Lotus%20flower%20%28Suzhou,%20China%29.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Lotus%20flower%20%28Suzhou,%20China%29.jpg',
    ],
  },
  {
    key: 'xiamen',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Xiamen%20night%20cityscape%202018%20-%20Flickr%20-%20Jaykhuang.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Gulangyu-4.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Xiamen%20night%20cityscape%202018%20-%20Flickr%20-%20Jaykhuang.jpg',
    ],
  },
  {
    key: 'chengdu',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Jinli%20Ancient%20Street%20at%20Night.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Giant%20Panda%202.JPG',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Jinli%20Ancient%20Street%20at%20Night.jpg',
    ],
  },
  {
    key: 'xian',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Terracotta%20Army%20Pit%201%201.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Terracotta%20Army%20Pit%201%201.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Terracotta%20Army%20Pit%201%201.jpg',
    ],
  },
  {
    key: 'wuhan',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Yellow%20Crane%20Tower%20in%20Wuhan.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Yellow%20Crane%20Tower%20in%20Wuhan.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Yellow%20Crane%20Tower%20in%20Wuhan.jpg',
    ],
  },
  {
    key: 'chongqing',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Hongya%20Cave%2031435-Chongqing%20%2844664174001%29.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/%E9%87%8D%E5%BA%86%E6%B4%AA%E5%B4%96%E6%B4%9E.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Hongya%20Cave%2031435-Chongqing%20%2844664174001%29.jpg',
    ],
  },
  {
    key: 'sanya',
    urls: [
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sanya%20Bay%20-%2002.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Holiday%20Beach,%20Haikou%20looking%20west%20-%2001.jpg',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sanya%20Bay%20-%2002.jpg',
    ],
  },
]

export class TravelPhotoService {
  static resolvePlanPhotos(plan: TravelPlan): string[] {
    const key: string = TravelPhotoService.resolveKey(plan)
    for (let i = 0; i < PHOTO_SETS.length; i++) {
      if (PHOTO_SETS[i].key === key) {
        return PHOTO_SETS[i].urls
      }
    }
    return DEFAULT_PHOTOS
  }

  private static resolveKey(plan: TravelPlan): string {
    const text: string = TravelPhotoService.collectSearchText(plan)
    if (text.indexOf('北京') >= 0) {
      return 'beijing'
    }
    if (text.indexOf('上海') >= 0) {
      return 'shanghai'
    }
    if (text.indexOf('广州') >= 0 || text.indexOf('广东') >= 0) {
      return 'guangzhou'
    }
    if (text.indexOf('深圳') >= 0) {
      return 'shenzhen'
    }
    if (text.indexOf('杭州') >= 0 || text.indexOf('西湖') >= 0 || text.indexOf('浙江') >= 0) {
      return 'hangzhou'
    }
    if (text.indexOf('温州') >= 0) {
      return 'wenzhou'
    }
    if (text.indexOf('苏州') >= 0 || text.indexOf('江苏') >= 0) {
      return 'suzhou'
    }
    if (text.indexOf('厦门') >= 0 || text.indexOf('福建') >= 0) {
      return 'xiamen'
    }
    if (text.indexOf('成都') >= 0 || text.indexOf('四川') >= 0) {
      return 'chengdu'
    }
    if (text.indexOf('西安') >= 0 || text.indexOf('陕西') >= 0) {
      return 'xian'
    }
    if (text.indexOf('武汉') >= 0 || text.indexOf('湖北') >= 0) {
      return 'wuhan'
    }
    if (text.indexOf('重庆') >= 0) {
      return 'chongqing'
    }
    if (text.indexOf('三亚') >= 0 || text.indexOf('海南') >= 0) {
      return 'sanya'
    }
    return 'default'
  }

  private static collectSearchText(plan: TravelPlan): string {
    let text: string = `${plan.title} ${plan.preference.attractionPreference} ${plan.preference.hotelPreference} ${plan.summary}`
    for (let i = 0; i < plan.places.length; i++) {
      text = `${text} ${plan.places[i].name} ${plan.places[i].address}`
    }
    return text
  }
}
