open Connection.Manager

type subscription<'msg> = {
  start: ('msg => unit) => (unit => unit),
}

let batch = (subscriptions: array<array<subscription<'msg>>>) => Belt.Array.concatMany(subscriptions)

// WebSocket types
type webSocket
type messageEvent = {data: string}

// WebSocket subscription
module WebSocket = {
  type t<'msg> = {
    url: string,
    cons: string => 'msg,
  }

  let listen = (_url, cons) => {
    start: dispatch => {
      let conn = getOrCreateConnection(_url)
      let messageHandler = (event: WebSocket.messageEvent) => {
        dispatch(cons(event.data))
      }
      conn.ws->WebSocket.set_onmessage(messageHandler)

      // Return cleanup function
      () => {
        // Clear the message handler
        conn.ws->WebSocket.set_onmessage(_ => ())
        // Don't close the connection here - let the manager handle it
      }
    }
  }
}

// Timer subscription
module Time = {
  type t<'msg> = {
    interval: int,
    cons: unit => 'msg,
  }

  let every = (interval, cons) => {
    start: dispatch => {
      let timerCallback = () => dispatch(cons())
      let id = Js.Global.setInterval(timerCallback, interval)
      () => Js.Global.clearInterval(id)
    }
  }
}

// Browser events subscription
module Browser = {
  module Events = {
    type t<'msg> = {
      eventName: string,
      cons: Dom.event => 'msg,
    }

    let on = (eventName, cons) => {
      start: dispatch => {
        let handler = event => dispatch(cons(event))
        let window: Js.t<{..}> = %raw("window")
        window["addEventListener"](eventName, handler)
        () => window["removeEventListener"](eventName, handler)
      }
    }
  }
}
