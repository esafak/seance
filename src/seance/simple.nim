import options
import providers
import session
import types
import std/json

export Provider, Session

var globalSession: Session = newChatSession()

proc chat*(content: string, provider: Option[Provider] = none(Provider), model: Option[string] = none(string), systemPrompt: Option[string] = none(string), jsonMode: bool = false, schema: Option[string] = none(string)): string =
  ## Simple chat function - just pass a string and get a response
  ## Uses a global session to maintain conversation context
  if systemPrompt.isSome and globalSession.messages.len == 0:
    globalSession.messages.add(ChatMessage(role: system, content: systemPrompt.get))
  let llmProvider = newProvider(provider)
  var schemaJson: Option[JsonNode] = none(JsonNode)
  if schema.isSome:
    schemaJson = some(parseFile(schema.get))
  let chatResult = globalSession.chat(content, llmProvider, model, jsonMode, schemaJson)
  return chatResult.content

proc chat*(session: var Session, content: string, provider: Option[Provider] = none(Provider), model: Option[string] = none(string), systemPrompt: Option[string] = none(string), jsonMode: bool = false, schema: Option[string] = none(string)): string =
  ## Chat with a session - session.chat("message")
  if systemPrompt.isSome and session.messages.len == 0:
    session.messages.add(ChatMessage(role: system, content: systemPrompt.get))
  let llmProvider = newProvider(provider)
  var schemaJson: Option[JsonNode] = none(JsonNode)
  if schema.isSome:
    schemaJson = some(parseFile(schema.get))
  let chatResult = session.chat(content, llmProvider, model, jsonMode, schemaJson)
  return chatResult.content

proc newSession*(systemPrompt: Option[string] = none(string)): Session =
  ## Create a new chat session with optional system prompt
  var session = newChatSession()
  if systemPrompt.isSome:
    session.messages.add(ChatMessage(role: system, content: systemPrompt.get))
  return session

proc resetSession*(systemPrompt: Option[string] = none(string)) =
  ## Reset the global session (start a fresh conversation)
  globalSession = newChatSession()
  if systemPrompt.isSome:
    globalSession.messages.add(ChatMessage(role: system, content: systemPrompt.get))