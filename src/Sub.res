/** Subscription descriptor. */
type subscription<'model,'msg> = {
  /** Deterministic string function computed from the current model.
      The runtime calls this with the current model to decide identity for diffing
      (start/stop). */
  key: 'model => string,
  /** Start receives (dispatch, getModel, startCancel?) and returns a cleanup function
      (unit => unit). The optional startCancel predicate is evaluated at start and
      lets the runtime signal an immediate abort if the computed subscription set changed. */
  start: (('msg => unit), (unit => 'model), option<'model => bool>) => (unit => unit),
}

module WebSocket = {
  /** WebSocket subscription factory. */
  type t<'model,'msg> = {
    /** The WebSocket URL to connect to. */
    url: string,
    /** A function that converts incoming text frames into your app message. */
    cons: string => 'msg,
    /** Whether the connection should automatically reconnect when closed. */
    reconnect?: bool,
    /** Optional backoff delay (ms) used for reconnect attempts. */
    backoffMs?: int,
    /** Optional subprotocols to pass to the WebSocket constructor. */
    protocols?: array<string>,
    /** Optional headers (as a Js.Dict) to attach when establishing the connection. */
    headers?: Js.Dict.t<string>,
    /** Whether the connection should automatically open on subscription start. */
    autoOpen?: bool,
  }

  /** Create an optional WebSocket subscription.
      - `cond`: boolean guard; when false the factory returns None.
      - `opts.url`: string — the WebSocket URL to connect to (e.g. "wss://example/socket").
      - `opts.cons`: string => 'msg — convert incoming text frames into your app message.
      - `opts.reconnect?`: bool (optional) — whether to automatically reconnect when the socket closes.
      - `opts.backoffMs?`: int (optional) — base backoff delay in milliseconds used for reconnect attempts.
      - `opts.protocols?`: array<string> (optional) — optional subprotocols to pass to the WebSocket constructor.
      - `opts.headers?`: Js.Dict.t<string> (optional) — headers/metadata used when opening the connection (implementation-specific).
      - `opts.autoOpen?`: bool (optional) — whether to open automatically on subscription start; if false connection can be managed manually.

      ```rescript
      /* listen while model.count < 300 */
      Sub.WebSocket.listen(model.count < 300, {
        url: "wss://example/socket",
        cons: text => WebSocketMsg(text),
        reconnect: true,
        backoffMs: 500,
      })
      ```
  */
  let listen = (cond: bool, opts: t<'model,'msg>) => {
    if !cond {
      None
    } else {
      let keyFn = (_m) => "ws:" ++ opts.url
      Some({key: keyFn, start: (dispatch, getModel, startCancel) => {
        let cleanupRef: ref<option<unit => unit>> = ref(None)
        let wrapped = (raw: string) => {
          let m = getModel()
          let shouldCancelStart = switch startCancel { | Some(fn) => fn(m) | None => false }
          if shouldCancelStart {
            switch cleanupRef.contents { | Some(c) => c() | None => () }
          } else {
            dispatch(opts.cons(raw))
          }
        }

        let cleanup = Connection.Manager.addListener(~url=opts.url, ~fn=wrapped)
        cleanupRef.contents = Some(cleanup)

        () => switch cleanupRef.contents { | Some(c) => c() | None => () }
      }})
    }
  }
}

module Time = {
  /** Time subscription. */
  type t<'model,'msg> = {
    /** Interval in milliseconds between each tick. */
    interval: int,
    /** A zero-argument constructor that produces the message to dispatch on each tick. */
    cons: unit => 'msg,
  }

  /** Create an optional time-based subscription that dispatches periodically.
      - `cond`: boolean guard; when false the factory returns None.
      - `opts.interval`: milliseconds between ticks.
      - `opts.cons`: zero-arg constructor for the message to dispatch on each tick.

    ```rescript
    /* tick every second while model.count <= 30 */
    Sub.Time.every(model.count <= 30, {interval: 1000, cons: () => Increment})
    ```
  */
  let every = (cond: bool, opts: t<'model,'msg>) => {
    if !cond {
      None
    } else {
      let keyFn = (_m) => "time:" ++ string_of_int(opts.interval)
      Some({key: keyFn, start: (dispatch, getModel, startCancel) => {
        let idRef: ref<Js.Global.intervalId> = ref(Obj.magic(0))
        let timerCallback = () => {
          let m = getModel()
          let shouldCancelStart = switch startCancel { | Some(fn) => fn(m) | None => false }
          if shouldCancelStart {
            Js.Global.clearInterval(idRef.contents)
          } else {
            dispatch(opts.cons())
          }
        }
        let id = Js.Global.setInterval(timerCallback, opts.interval)
        idRef.contents = id
        () => Js.Global.clearInterval(idRef.contents)
      }})
    }
  }
}

module Browser = {
  module Events = {
    /** Browser event subscription. */
    type t<'model,'msg> = {
      /** DOM event name to listen for (e.g. "click"). */
      on: string,
      /** Convert the DOM event into your app-level message. */
      cons: Dom.event => 'msg,
    }

    /** Create an optional browser event subscription.
        `cond`: boolean guard; when false the factory returns None.
        `opts.on`: DOM event name (e.g. "click").
        `opts.cons`: map the DOM event to your app message.

      ```rescript
      /* in-example: listen for clicks while enabled */
      Sub.Browser.Events.on(model.enabled, {on: "click", cons: _ => Clicked})
      ```
    */
    let on = (cond: bool, opts: t<'model,'msg>) => {
      if !cond {
        None
      } else {
        let keyFn = (_m) => "event:" ++ opts.on
        Some({key: keyFn, start: (dispatch, getModel, startCancel) => {
          let cleanupRef: ref<option<unit => unit>> = ref(None)
          let handler = event => {
            let m = getModel()
            let shouldCancelStart = switch startCancel { | Some(fn) => fn(m) | None => false }
            if shouldCancelStart {
              switch cleanupRef.contents { | Some(c) => c() | None => () }
            } else {
              dispatch(opts.cons(event))
            }
          }
          let window: Js.t<{..}> = %raw("window")
          window["addEventListener"](opts.on, handler)
          cleanupRef.contents = Some(() => window["removeEventListener"](opts.on, handler))
          () => switch cleanupRef.contents { | Some(c) => c() | None => () }
        } })
      }
    }
  }
}
