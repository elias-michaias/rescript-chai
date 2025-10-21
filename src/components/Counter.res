open Fetch

type model = {
    count: int,
    title: string,
}

type msg =
    | Increment
    | Set(option<int>)
    | SetAfterDelay(int, int)
    | SetLogCount(int)
    | Response(string)
    | SaveCount(int)
    | LoadCount
    | SendWebSocketData(Js.Json.t)

type rec cmd =
    | NoOp
    | Batch(Cmd.Batch.t<cmd>)
    | Delay(Cmd.Delay.t<msg>)
    | Http(Cmd.Http.t<msg>)
    | Log(Cmd.Log.t)
    | StorageSet(Cmd.Storage.Set.t)
    | StorageGet(Cmd.Storage.Get.t<msg>)
    | WebSocket(Cmd.WebSocket.t)

let update = (model, msg) => switch msg {
    | Increment => (
        { ...model, count: model.count + 1 }, 
        NoOp
    )
    | Set(Some(n)) => (
        { ...model, count: n }, 
        NoOp
    )
    | Set(None) => (
        model,
        NoOp
    )
    | SetAfterDelay(ms, n) => (
        model, 
        Delay({ msg: Some(n)->Set, ms: ms })  
    )
    | SetLogCount(n) => (
        { ...model, count: n },
        Log("Setting count to " ++ string_of_int(n)),
    )
    | Response(res) => {
        ({ ...model, title: res }, NoOp)
    }
    | SaveCount(n) => (
        model,
        StorageSet({
            key: "count",
            value: string_of_int(n),
        })
    )
    | LoadCount => (
        model,
        StorageGet({
            key: "count",
            cons: r => r
                ->Option.map(x => int_of_string(x))
                ->Set
        })
    )
    | SendWebSocketData(data) => (
        model,
        WebSocket({
            url: "wss://echo.websocket.org",
            data: data,
        })
    )
}

let rec run = async (cmd, dispatch) => switch cmd {
    | NoOp => ()
    | Batch(c) => await c->Cmd.Batch.run(dispatch, run)
    | Log(c) => await c->Cmd.Log.run
    | Delay(c) => await c->Cmd.Delay.run(dispatch)
    | Http(c) => await c->Cmd.Http.run(dispatch)
    | StorageSet(c) => await c->Cmd.Storage.Set.run(dispatch)
    | StorageGet(c) => await c->Cmd.Storage.Get.run(dispatch)
    | WebSocket(c) => await c->Cmd.WebSocket.run(dispatch)

}

let subs = (_model) => [
    Sub.WebSocket.listen("wss://echo.websocket.org", s => Response("WS Message: " ++ s))
]

@react.component
let make = (~count=0) => {

    let (model, dispatch) = Chai.useKettle({ 
        update: update, 
        run: run, 
        subscriptions: subs,
        init: ({
            count: count,
            title: "Counter Component",
        }, 
            Batch([
                Log("Counter initialized"),
                Delay({ msg: Some(-5)->Set, ms: 1000}),
                Http({
                    url: "https://httpbin.org/base64/SGVsbG8gV29ybGQ=",
                    req: {
                        method: #GET
                    },
                    cons: async r => Response(await r->Response.text)
                })
            ])
        )
    })

    <div>
        <h2 className="text-2xl font-bold mb-4">
            {React.string(model.title)}
        </h2>
        <p className="text-lg mb-4">
            {React.string("Count: " ++ string_of_int(model.count))}
        </p>
        <div className="flex flex-wrap">
            <Button onClick={_ => Increment->dispatch}>
                {React.string("Increment")}
            </Button>
            <Button onClick={_ => SetAfterDelay(1000, 12)->dispatch}>
                {React.string("Set to 12 after 1 second")}
            </Button>
            <Button onClick={_ => SetLogCount(10)->dispatch}>
                {React.string("Set count to 10 and log")}
            </Button>
            <Button onClick={_ => SaveCount(model.count)->dispatch}>
                {React.string("Save count to storage")}
            </Button>
            <Button onClick={_ => LoadCount->dispatch}>
                {React.string("Load count from storage")}
            </Button>
            <Button onClick={_ => SendWebSocketData(Js.Json.string("Boop"))->dispatch}>
                {React.string("Send WebSocket Message")}
            </Button>
        </div>
    </div>
}