open Fetch

module Spec = {
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
        | SaveCountIDB(int)
        | LoadCountIDB
        | SendWebSocketData(Js.Json.t)

    type rec cmd = 
        | NoOp
        | Batch(Cmd.Batch.t<cmd>)
        | Log(Cmd.Log.t)
        | Delay(Cmd.Time.Delay.t<msg>)
        | Http(Cmd.Http.t<msg>)
        | StorageSet(Cmd.LocalStorage.Set.t)
        | StorageGet(Cmd.LocalStorage.Get.t<msg>)
        | IndexedDBSet(Cmd.IndexedDB.Set.t)
        | IndexedDBGet(Cmd.IndexedDB.Get.t<msg>)
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
        | SaveCountIDB(n) => (
            model,
            IndexedDBSet({
                db: "app",
                store: "counter",
                key: "count",
                value: string_of_int(n),
            })
        )
        | LoadCountIDB => (
            model,
            IndexedDBGet({
                db: "app",
                store: "counter",
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


    let subs = (_model) => [
        Sub.WebSocket.listen("wss://echo.websocket.org", s => Response("WS Message: " ++ s))
    ]

    let init = (count) => {
        ({
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
    }
}

module Runner = Cmd.Default(Spec)

@react.component
let make = (~count=0) => {

    let (model, dispatch) = Chai.useKettle({ 
        update: Spec.update, 
        subs: Spec.subs,
        init: Spec.init(count),
        run: Runner.run, 
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
            <Button onClick={_ => SendWebSocketData(Js.Json.string("Boop"))->dispatch}>
                {React.string("Send WebSocket Message")}
            </Button>
        </div>
        <div className="flex flex-wrap">
            <Button onClick={_ => SaveCount(model.count)->dispatch}>
                {React.string("Save count to storage")}
            </Button>
            <Button onClick={_ => LoadCount->dispatch}>
                {React.string("Load count from storage")}
            </Button>
            <Button onClick={_ => SaveCountIDB(model.count)->dispatch}>
                {React.string("Save count to IndexedDB")}
            </Button>
            <Button onClick={_ => LoadCountIDB->dispatch}>
                {React.string("Load count from IndexedDB")}
            </Button>
        </div>
    </div>
}