open Fetch

type person = {
    name: string,
    age: int,
}

type personMsg =
    | UpdateName(string)
    | UpdateAge(int)

module Spec = {

    type model = {
        count: int,
        title: string,
        person: person,
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
        | PersonMsg(personMsg)

    type rec cmd = 
        | NoOp
        | Batch(Cmd.Batch.t<cmd>)
        | Log(Cmd.Log.t)
        | Delay(Cmd.Time.Delay.t<msg>)
        | Http(Cmd.Http.t<msg>)
        | LocalStorageSet(Cmd.LocalStorage.Set.t)
        | LocalStorageGet(Cmd.LocalStorage.Get.t<msg>)
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
            LocalStorageSet({
                key: "count",
                value: string_of_int(n),
            })
        )
        | LoadCount => (
            model,
            LocalStorageGet({
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
        | PersonMsg(personMsg) => switch personMsg {
            | UpdateName(newName) => (
                { ...model, person: { ...model.person, name: newName } },
                NoOp
            )
            | UpdateAge(newAge) => (
                { ...model, person: { ...model.person, age: newAge } },
                NoOp
            )
        }
    }

    let rec run = async (cmd, dispatch) => switch cmd {
        | NoOp => ()
        | Batch(c) => await c->Cmd.Batch.run(dispatch, run)
        | Log(c) => await c->Cmd.Log.run
        | Delay(c) => await c->Cmd.Time.Delay.run(dispatch)
        | Http(c) => await c->Cmd.Http.run(dispatch)
        | LocalStorageSet(c) => await c->Cmd.LocalStorage.Set.run(dispatch)
        | LocalStorageGet(c) => await c->Cmd.LocalStorage.Get.run(dispatch)
        | IndexedDBSet(c) => await c->Cmd.IndexedDB.Set.run(dispatch)
        | IndexedDBGet(c) => await c->Cmd.IndexedDB.Get.run(dispatch)
        | WebSocket(c) => await c->Cmd.WebSocket.run(dispatch)
    }

}

open Spec

/* 
 In ReScript v12 this syntax will work:
--------------------------------------
let rec run = async (cmd, dispatch) => switch cmd {
    | ...cmd as c => await c->Cmd.Base.run(dispatch)
}
*/

let subs = (_model) => [
    Sub.WebSocket.listen("wss://echo.websocket.org", s => Response("WS Message: " ++ s)),
    Sub.Time.every(1000, _ => Increment)
]

let init = (count) => {
    ({
        count: count,
        title: "Counter Component",
        person: { name: "Alice", age: 30 }
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