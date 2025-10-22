# `rescript-chai`

## Example

```rescript
// Brew.res
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


// Counter.res
open Brew

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