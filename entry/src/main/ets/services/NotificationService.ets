import { common } from '@kit.AbilityKit'
import { notificationManager } from '@kit.NotificationKit'

const WEATHER_NOTIFICATION_BASE_ID: number = 260616

export class NotificationService {
  static async ensureEnabled(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled()
      if (enabled) {
        return true
      }
      await notificationManager.requestEnableNotification(context)
      return await notificationManager.isNotificationEnabled()
    } catch (e) {
      const err = e as Error
      console.error(`Enable notification failed: ${err.message}`)
      return false
    }
  }

  static async publishWeatherAdvice(title: string, text: string): Promise<boolean> {
    await NotificationService.ensureSlot()
    const request: notificationManager.NotificationRequest = {
      id: NotificationService.nextNotificationId(),
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text,
        },
      },
    }
    try {
      await notificationManager.publish(request)
      return true
    } catch (e) {
      const err = e as Error
      console.error(`Publish weather notification failed: ${err.message}`)
      return false
    }
  }

  static async openSettings(context: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.openNotificationSettings(context)
    } catch (e) {
      const err = e as Error
      console.error(`Open notification settings failed: ${err.message}`)
    }
  }

  private static async ensureSlot(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION)
    } catch (e) {
      const err = e as Error
      console.error(`Add notification slot failed: ${err.message}`)
    }
  }

  private static nextNotificationId(): number {
    return WEATHER_NOTIFICATION_BASE_ID + Math.floor(Date.now() % 100000)
  }
}
