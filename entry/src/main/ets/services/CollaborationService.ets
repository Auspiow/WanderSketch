import { http } from '@kit.NetworkKit'
import { TravelPlan } from '../model/Types'

const COLLABORATION_ENDPOINTS: string[] = [
  'http://10.196.35.142:3000/api/collaboration/sessions',
  'http://10.0.2.2:3000/api/collaboration/sessions',
  'http://127.0.0.1:3000/api/collaboration/sessions',
]

export type CollaborationAccess = 'edit' | 'view'

export interface CollaborationMemberRecord {
  id: string
  name: string
  permission: CollaborationAccess
  status: string
}

export interface CollaborationSession {
  code: string
  revision: number
  updatedAt: string
  plan: TravelPlan
  members: CollaborationMemberRecord[]
}

interface CreateSessionPayload {
  plan: TravelPlan
  ownerName: string
}

interface AddMemberPayload {
  name: string
  permission: CollaborationAccess
}

interface SavePlanPayload {
  plan: TravelPlan
  revision: number
  editorName: string
}

interface UpdateMemberPermissionPayload {
  permission: CollaborationAccess
}

export class CollaborationService {
  // A short, deterministic code lets the owner share an already-created plan without exposing a separate secret locally.
  static codeForPlan(planId: string): string {
    const normalized: string = planId.trim().toUpperCase()
    return normalized.length > 8 ? normalized.substring(normalized.length - 8) : normalized
  }

  static async createOrLoad(plan: TravelPlan, ownerName: string): Promise<CollaborationSession> {
    const payload: CreateSessionPayload = { plan, ownerName }
    return CollaborationService.request(http.RequestMethod.POST, '', payload)
  }

  static async join(code: string, memberName: string): Promise<CollaborationSession> {
    const payload: AddMemberPayload = {
      name: memberName,
      permission: 'edit',
    }
    return CollaborationService.request(http.RequestMethod.POST, `/${encodeURIComponent(code)}/members`, payload)
  }

  static async addMember(code: string, memberName: string, permission: CollaborationAccess): Promise<CollaborationSession> {
    const payload: AddMemberPayload = {
      name: memberName,
      permission,
    }
    return CollaborationService.request(http.RequestMethod.POST, `/${encodeURIComponent(code)}/members`, payload)
  }

  static async load(code: string): Promise<CollaborationSession> {
    return CollaborationService.request(http.RequestMethod.GET, `/${encodeURIComponent(code)}`, undefined)
  }

  static async savePlan(code: string, plan: TravelPlan, revision: number, editorName: string): Promise<CollaborationSession> {
    const payload: SavePlanPayload = {
      plan,
      revision,
      editorName,
    }
    return CollaborationService.request(http.RequestMethod.PUT, `/${encodeURIComponent(code)}/plan`, payload)
  }

  static async updateMemberPermission(code: string, memberId: string, permission: CollaborationAccess): Promise<CollaborationSession> {
    const payload: UpdateMemberPermissionPayload = {
      permission,
    }
    return CollaborationService.request(http.RequestMethod.PUT,
      `/${encodeURIComponent(code)}/members/${encodeURIComponent(memberId)}`, payload)
  }

  private static async request(method: http.RequestMethod, suffix: string, payload: Object | undefined): Promise<CollaborationSession> {
    const errors: string[] = []
    for (let index: number = 0; index < COLLABORATION_ENDPOINTS.length; index++) {
      const endpoint: string = `${COLLABORATION_ENDPOINTS[index]}${suffix}`
      const request: http.HttpRequest = http.createHttp()
      try {
        const response: http.HttpResponse = await request.request(endpoint, {
          method,
          header: { 'Content-Type': 'application/json' },
          extraData: payload === undefined ? '' : JSON.stringify(payload),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 5000,
          readTimeout: 15000,
        })
        const body: string = response.result as string
        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error(`HTTP ${response.responseCode}: ${body}`)
        }
        return JSON.parse(body) as CollaborationSession
      } catch (error) {
        const err: Error = error as Error
        errors.push(`${endpoint}: ${err.message}`)
      } finally {
        request.destroy()
      }
    }
    throw new Error(`Collaboration service is unavailable: ${errors.join('; ')}`)
  }
}
