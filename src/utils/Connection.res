module Manager = {
  type connection = {
    ws: WebSocket_.t,
    mutable isConnected: bool,
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
    let conn = { ws: ws, isConnected: false }

    let onOpen = () => {
      conn.isConnected = true
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
}