module Manager = {
  type connection = {
    ws: WebSocket_.t,
    mutable isConnected: bool,
    mutable subscribers: array<string => unit>,
    mutable outgoingQueue: array<Js.Json.t>,
  }

  let connections: Js.Dict.t<connection> = Js.Dict.empty()

  let getConnection = (url: string): option<connection> => {
    Js.Dict.get(connections, url)
  }

  let setConnection = (url: string, conn: connection) => {
    Js.Dict.set(connections, url, conn)
  }

  let removeConnection = (_url: string) => {
    // For now, don't remove - connections can be reused
    ()
  }

  let createConnection = (url: string): connection => {
    let ws = WebSocket_.new_(url)
  let conn = { ws: ws, isConnected: false, subscribers: [], outgoingQueue: [] }

    let onOpen = () => {
      conn.isConnected = true
      /* flush queued outgoing messages */
      for i in 0 to Array.length(conn.outgoingQueue) - 1 {
        let data = Array.getUnsafe(conn.outgoingQueue, i)
        let jsonString = Js.Json.stringify(data)
        conn.ws->WebSocket_.send(jsonString)
      }
  conn.outgoingQueue = []
    }

    let onClose = () => {
      conn.isConnected = false
      // Keep connection in dictionary for potential reuse
    }

    let onError = () => {
      conn.isConnected = false
      // Keep connection in dictionary for potential reuse
    }

    ws->WebSocket_.set_onopen(onOpen)
    /* onmessage: dispatch to registered subscribers */
    ws->WebSocket_.set_onmessage(event => {
      let data = event.data
      for i in 0 to Array.length(conn.subscribers) - 1 {
        let fn = Array.getUnsafe(conn.subscribers, i)
        fn(data)
      }
    })
    ws->WebSocket_.set_onclose(onClose)
    ws->WebSocket_.set_onerror(onError)

    setConnection(url, conn)
    conn
  }

  let getOrCreateConnection = (url: string): connection => {
    switch getConnection(url) {
    | Some(conn) if conn.isConnected => conn
    | _ => createConnection(url)
    }
  }

  /* Public API: options for sending and for listeners */
  /* internal send options used by the manager; callers pass labeled optional args instead */
  type sendOptions = {
    stringify: bool,
  }

  let defaultSendOptions = {stringify: true}

  type listenOptions = {
    // parser: raw string => option<string> (None to drop)
    parser: string => option<string>,
  }

  let defaultListenOptions = {parser: (s: string) => Some(s)}

  /* Enqueue or send immediately depending on connection state */
  /* public send: callers pass ~stringify=? directly */
  let send = (~url: string, ~data: Js.Json.t, ~stringify=? ) => {
    let opts = switch stringify { | Some(b) => {stringify: b} | None => defaultSendOptions }
    let conn = getOrCreateConnection(url)
    if conn.isConnected {
      let toSend = if opts.stringify { Js.Json.stringify(data) } else { Obj.magic(data) }
      conn.ws->WebSocket_.send(toSend)
    } else {
      /* queue the raw json; it will be stringified when flushed */
  conn.outgoingQueue = Array.concat(conn.outgoingQueue, Array.make(~length=1, data))
    }
  }

  /* Add a listener function; returns a cleanup function */
  let addListener = (~url: string, ~fn: string => unit, ~opts=? ) => {
    let opts = switch opts { | Some(o) => o | None => defaultListenOptions }
    let conn = getOrCreateConnection(url)
    /* wrap subscriber to apply parser */
    let wrapped = (raw: string) => {
      switch opts.parser(raw) {
      | Some(parsed) => fn(parsed)
      | None => ()
      }
    }
  conn.subscribers = Array.concat(conn.subscribers, Array.make(~length=1, wrapped))
    /* return cleanup */
    () => {
      /* remove the last occurrence of wrapped (simple approach) */
      let idx = Array.length(conn.subscribers) - 1
      if idx >= 0 {
        conn.subscribers = Array.slice(conn.subscribers, ~start=0, ~end=idx)
      }
    }
  }
}