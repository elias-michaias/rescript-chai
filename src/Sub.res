type subscription<'msg> = {
  start: ('msg => unit) => (unit => unit),
}

module WebSocket = {
  type t<'msg> = {
    url: string,
    cons: string => 'msg,
  }

  let listen = (_url, cons) => {
    start: dispatch => {
      let conn = Connection.Manager.getOrCreateConnection(_url)
      let messageHandler = (event: WebSocket_.messageEvent) => {
        dispatch(cons(event.data))
      }
      conn.ws->WebSocket_.set_onmessage(messageHandler)

      // Return cleanup function
      () => {
        // Clear the message handler
        conn.ws->WebSocket_.set_onmessage(_ => ())
        // Don't close the connection here - let the manager handle it
      }
    }
  }
}

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

module Browser = {
  module Events = {
    type t<'msg> = {
      on: string,
      cons: Dom.event => 'msg,
    }

    let on = (on, cons) => {
      start: dispatch => {
        let handler = event => dispatch(cons(event))
        let window: Js.t<{..}> = %raw("window")
        window["addEventListener"](on, handler)
        () => window["removeEventListener"](on, handler)
      }
    }
  }
}
