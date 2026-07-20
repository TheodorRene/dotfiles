import { spawn } from "node:child_process"

const notifiedPermissions = new Set()
const notifiedQuestions = new Set()
const busySessions = new Set()

function notify(summary, body, urgency = "normal") {
  const child = spawn(
    "notify-send",
    [
      "--app-name=opencode",
      "--urgency",
      urgency,
      "--expire-time=5000",
      summary,
      body,
    ],
    {
      detached: true,
      stdio: "ignore",
    },
  )
  child.unref()
}

function permissionBody(permission) {
  const target = permission.pattern
    ? Array.isArray(permission.pattern)
      ? permission.pattern.join(", ")
      : permission.pattern
    : permission.type

  return [permission.title, target].filter(Boolean).join("\n")
}

function notifyPermission(permission) {
  if (!permission?.id || notifiedPermissions.has(permission.id)) return
  notifiedPermissions.add(permission.id)
  notify("OpenCode needs permission", permissionBody(permission) || "Action required", "critical")
}

function questionBody(request) {
  return request.questions
    ?.map((question) => question.header || question.question)
    .filter(Boolean)
    .join("\n")
}

function notifyQuestion(request) {
  if (!request?.id || notifiedQuestions.has(request.id)) return
  notifiedQuestions.add(request.id)
  notify("OpenCode needs input", questionBody(request) || "Action required", "critical")
}

export const MakoNotifyPlugin = async () => {
  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.status":
          if (event.properties?.status?.type === "busy") {
            busySessions.add(event.properties.sessionID)
          }
          break
        case "session.idle":
          if (busySessions.delete(event.properties?.sessionID)) {
            notify("OpenCode done", "Session finished working")
          }
          break
        case "session.error":
          notify("OpenCode error", event.properties?.error?.message || "Session failed", "critical")
          break
        case "permission.updated":
        case "permission.asked":
          notifyPermission(event.properties)
          break
        case "question.asked":
          notifyQuestion(event.properties)
          break
      }
    },
    "permission.ask": async (input) => {
      notifyPermission(input)
    },
  }
}
