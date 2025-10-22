# Chai

<div style="text-align: center; margin-bottom: 2rem;" align="center">
  <img src="./chai.png" alt="logo" style="width: 200px; height: auto;" />
</div>

<h2 style="text-align: center;"><code>rescript-chai</code></h2>

<p style="text-align: center; max-width: 600px; margin: 0 auto 2rem auto;">
<a href="https://github.com/elias-michaias/rescript-chai">Chai</a> is an implementation of <a href="https://guide.elm-lang.org/architecture/">The Elm Architecture</a> (TEA) in <a href="https://rescript-lang.org/">ReScript</a> - built on <a href="https://react.dev/">React</a>. Chai wants to make the React ecosystem accessible to the Model-View-Update paradigm, without sacrificing on the comforts you're used to.
</p>

>[!WARNING]
>Chai is an experimental project and is currently in early and development. Most APIs are incomplete, unstable, and subject to change.

## Example

```rescript
// Counter.res
type model = {
    count: int
}

type msg = 
  | Increment 
  | Decrement
  | Set(option<int>)
  | SendData(string)

type cmd = 
  | NoOp 
  | Log(Cmd.Log.t) 
  | WebSocket(Cmd.WebSocket.t<msg>)

let update = (model, msg) => switch msg {
  | Increment => ({count: model.count + 1}, NoOp)
  | Decrement => ({count: model.count - 1}, NoOp)
  | Set(Some(n)) => ({count: n}, NoOp)
  | Set(None) => (model, NoOp)
  | SendData(data) => (model, WebSocket({
    url: "wss://echo.websocket.org",
    data: data,
  }))
}

let run = async (cmd, dispatch) => switch cmd {
  | NoOp => ()
  | Log(c) => await c->Cmd.Log.run
  | WebSocket(c) await c->Cmd.WebSocket.run(dispatch)
}

let init = (count) => {
    ({
        count: count
    }, 
        Log("Counter initialized")
    )
}

let subs = (_model) => [
    Sub.WebSocket.listen(
        "wss://echo.websocket.org", 
        s => s
            ->int_of_string
            ->Set
    )
]

@react.component
let make = (~count=0) => {

  let (model, dispatch) = Chai.useKettle({
    update: update,
    run: run,
    subs: subs,
    init: init(count),
  })

  <div>
    <p>{("Count: " ++ string_of_int(model.count))->React.string}</p>
    <button onClick={_ => Increment->dispatch}>
      {"+"->React.string}
    </button>
    <button onClick={_ => Decrement->dispatch}>
      {"-"->React.string}
    </button>
    <button onClick={_ => SendData(9)->dispatch}>
      {"Set to 9 via WebSocket"->React.string}
    </button>
  </div>
}
```
