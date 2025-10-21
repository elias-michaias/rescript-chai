// Elm `Cmd` analog with cmd outside model
module type Kettle = {
    type model
    type msg
    type cmd

    let update: (model, msg) => (model, cmd)
    let run: (cmd, msg => unit) => promise<unit>
}

module type Cup = {
    type model
    type msg

    let update: (model, msg) => model
}


module Batch = {
    type t<'cmd> = array<'cmd>
    let run = async (cmds, dispatch, runner) => {
        let promises = cmds->Array.map(c => runner(c, dispatch))
        let _ = await Promise.all(promises)
    }
}

module Delay = {
  type t<'msg> = {
    ms: int,
    msg: 'msg
  }
  let run = async (cmd, dispatch) => {
    let _timeoutId = setTimeout(() => dispatch(cmd.msg), cmd.ms)
    ()
  }
}

module Log = {
  type t = string
  let run = async (cmd) => Console.log(cmd)
}


module Http = {
    type t<'msg> = {
        url: string,
        req: Fetch.Request.init, 
        cons: Fetch.Response.t => promise<'msg>,
    }
    let run = async (cmd, dispatch) => {
        let response = await Fetch.fetch(cmd.url, cmd.req)
        let msg = await cmd.cons(response)
        dispatch(msg)
    }
}

module Storage = {
  module Get = {
    type t<'msg> = {
      key: string,
      cons: option<string> => 'msg,
    }

    let run = async (cmd, dispatch) => {
      let result = try {
        let value = Dom.Storage.getItem(cmd.key)(Dom_storage2.localStorage)
        value
      } catch {
      | Js.Exn.Error(_) => None
      }
      let msg = cmd.cons(result)
      dispatch(msg)
    }
  }

  module Set = {
    type t = {
      key: string,
      value: string,
    }

    let run = async (_cmd, _dispatch) => {
      try {
        Dom.Storage.setItem(_cmd.key, _cmd.value, Dom_storage2.localStorage)
      } catch {
      | Js.Exn.Error(_) => ()
      }
      // Fire and forget - no message dispatched
    }
  }

  module Remove = {
    type t = {
      key: string,
    }

    let run = async (_cmd, _dispatch) => {
      try {
        Dom.Storage.removeItem(_cmd.key, Dom_storage2.localStorage)
      } catch {
      | Js.Exn.Error(_) => ()
      }
      // Fire and forget - no message dispatched
    }
  }

  module Clear = {
    type t = unit

    let run = async (_cmd, _dispatch) => {
      try {
        Dom.Storage.clear(Dom_storage2.localStorage)
      } catch {
      | Js.Exn.Error(_) => ()
      }
      // Fire and forget - no message dispatched
    }
  }
}

module WebSocket = {
    type t = {
        url: string,
        data: Js.Json.t,
    }
    let run = async (cmd, _dispatch) => {
        let conn = Connection.Manager.getOrCreateConnection(cmd.url)
        let onOpen = () => {
            let jsonString = Js.Json.stringify(cmd.data)
            conn.ws->WebSocket.send(jsonString)
            // Don't close the connection - let it stay open for subscriptions
        }
        // If already connected, send immediately
        if conn.isConnected {
            let jsonString = Js.Json.stringify(cmd.data)
            conn.ws->WebSocket.send(jsonString)
        } else {
            conn.ws->WebSocket.addEventListener("open", onOpen)
        }
    }
}
