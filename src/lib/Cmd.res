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

module Time = {
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
  module Now = {
    type t<'msg> = {
      cons: float => 'msg,
    }
    let run = async (cmd, dispatch) => {
      dispatch(cmd.cons(Date.now()))
      ()
    }
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

module LocalStorage = {
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

module IndexedDB = {

  let contains = (list, str) => list->Array.some(item => item == str)

  module Get = {
    type t<'msg> = {
      db: string,
      store: string,
      key: string,
      cons: option<string> => 'msg,
    }

    let run = async (cmd, dispatch) => {
      try {
        let openRequest = IndexedDB_.indexedDB->IndexedDB_.open_(cmd.db, 1)
        openRequest->IndexedDB_.set_onupgradeneeded((event) => {
          let db = (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult
          if !(db->IndexedDB_.objectStoreNames->contains("keyvalue")) {
            let _ = db->IndexedDB_.createObjectStore(cmd.store)
          }
        })
        let db = await Js.Promise.make((~resolve, ~reject) => {
          openRequest->IndexedDB_.set_onsuccess_open((event) => resolve(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult))
          openRequest->IndexedDB_.set_onerror_open((event) => reject(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestError))
        })
        let transaction = db->IndexedDB_.transaction(cmd.store, "readonly")
        let store = transaction->IndexedDB_.objectStore(cmd.store)
        let getRequest = store->IndexedDB_.get(cmd.key)
        let value = await Js.Promise.make((~resolve, ~reject) => {
          getRequest->IndexedDB_.set_onsuccess((event) => resolve(. (event["target"] :> IndexedDB_.request)->IndexedDB_.requestResult))
          getRequest->IndexedDB_.set_onerror((event) => reject(. (event["target"] :> IndexedDB_.request)->IndexedDB_.requestError))
        })
        let result = value
        let msg = cmd.cons(result)
        dispatch(msg)
      } catch {
      | _ => {
          let msg = cmd.cons(None)
          dispatch(msg)
        }
      }
    }
  }

  module Set = {
    type t = {
      db: string,
      store: string,
      key: string,
      value: string,
    }

    let run = async (cmd, _dispatch) => {
      try {
        let openRequest = IndexedDB_.indexedDB->IndexedDB_.open_(cmd.db, 1)
        openRequest->IndexedDB_.set_onupgradeneeded((event) => {
          let db = (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult
          if !(db->IndexedDB_.objectStoreNames->contains(cmd.store)) {
            let _ = db->IndexedDB_.createObjectStore(cmd.store)
          }
        })
        let db = await Js.Promise.make((~resolve, ~reject) => {
          openRequest->IndexedDB_.set_onsuccess_open((event) => resolve(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult))
          openRequest->IndexedDB_.set_onerror_open((event) => reject(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestError))
        })
        let transaction = db->IndexedDB_.transaction(cmd.store, "readwrite")
        let store = transaction->IndexedDB_.objectStore(cmd.store)
        let _ = store->IndexedDB_.put(cmd.value, cmd.key)
        await Js.Promise.make((~resolve, ~reject) => {
          transaction->IndexedDB_.set_oncomplete((_event) => resolve(. ()))
          transaction->IndexedDB_.set_onerror_transaction((event) => reject(. (event["target"] :> IndexedDB_.idbTransaction)->IndexedDB_.transactionError))
        })
      } catch {
      | _ => ()
      }
    }
  }

  module Remove = {
    type t = {
      db: string,
      store: string,
      key: string,
    }

    let run = async (cmd, _dispatch) => {
      try {
        let openRequest = IndexedDB_.indexedDB->IndexedDB_.open_(cmd.db, 1)
        openRequest->IndexedDB_.set_onupgradeneeded((event) => {
          let db = (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult
          if !(db->IndexedDB_.objectStoreNames->contains(cmd.store)) {
            let _ = db->IndexedDB_.createObjectStore(cmd.store)
          }
        })
        let db = await Js.Promise.make((~resolve, ~reject) => {
          openRequest->IndexedDB_.set_onsuccess_open((event) => resolve(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult))
          openRequest->IndexedDB_.set_onerror_open((event) => reject(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestError))
        })
        let transaction = db->IndexedDB_.transaction(cmd.store, "readwrite")
        let store = transaction->IndexedDB_.objectStore(cmd.store)
        let _ = store->IndexedDB_.delete(cmd.key)
        await Js.Promise.make((~resolve, ~reject) => {
          transaction->IndexedDB_.set_oncomplete((_event) => resolve(. ()))
          transaction->IndexedDB_.set_onerror_transaction((event) => reject(. (event["target"] :> IndexedDB_.idbTransaction)->IndexedDB_.transactionError))
        })
      } catch {
      | _ => ()
      }
    }
  }

  module Clear = {
    type t = {
      db: string,
      store: string,
    }

    let run = async (cmd, _dispatch) => {
      try {
        let openRequest = IndexedDB_.indexedDB->IndexedDB_.open_(cmd.db, 1)
        openRequest->IndexedDB_.set_onupgradeneeded((event) => {
          let db = (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult
          if !(db->IndexedDB_.objectStoreNames->contains(cmd.store)) {
            let _ = db->IndexedDB_.createObjectStore(cmd.store)
          }
        })
        let db = await Js.Promise.make((~resolve, ~reject) => {
          openRequest->IndexedDB_.set_onsuccess_open((event) => resolve(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestResult))
          openRequest->IndexedDB_.set_onerror_open((event) => reject(. (event["target"] :> IndexedDB_.openRequest)->IndexedDB_.openRequestError))
        })
        let transaction = db->IndexedDB_.transaction(cmd.store, "readwrite")
        let store = transaction->IndexedDB_.objectStore(cmd.store)
        let _ = IndexedDB_.clear(store)
        await Js.Promise.make((~resolve, ~reject) => {
          transaction->IndexedDB_.set_oncomplete((_event) => resolve(. ()))
          transaction->IndexedDB_.set_onerror_transaction((event) => reject(. event["target"]->IndexedDB_.transactionError))
        })
      } catch {
      | _ => ()
      }
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
            conn.ws->WebSocket_.send(jsonString)
            // Don't close the connection - let it stay open for subscriptions
        }
        // If already connected, send immediately
        if conn.isConnected {
            let jsonString = Js.Json.stringify(cmd.data)
            conn.ws->WebSocket_.send(jsonString)
        } else {
            conn.ws->WebSocket_.addEventListener("open", onOpen)
        }
    }
}
