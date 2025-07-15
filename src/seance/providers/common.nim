import ../types

method dispatchChat*(provider: ChatProvider, messages: seq[ChatMessage], model: string): ChatResult {.base.} =
  raise newException(Defect, "chat() not implemented for this provider")

proc `$`*(role: MessageRole): string =
  case role:
  of system: "system"
  of user: "user"
  of assistant: "assistant"
