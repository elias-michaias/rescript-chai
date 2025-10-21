// WebSocket bindings
type t
type messageEvent = {data: string}
type messageEventHandler = messageEvent => unit
type eventHandler = unit => unit

@new external new_: string => t = "WebSocket"
@set external set_onmessage: (t, messageEventHandler) => unit = "onmessage"
@set external set_onopen: (t, eventHandler) => unit = "onopen"
@set external set_onclose: (t, eventHandler) => unit = "onclose"
@set external set_onerror: (t, eventHandler) => unit = "onerror"
@send external send: (t, string) => unit = "send"
@send external close: t => unit = "close"

external addEventListener: (t, string, 'a => unit) => unit = "addEventListener"
external removeEventListener: (t, string, 'a => unit) => unit = "removeEventListener"