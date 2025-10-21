// IndexedDB bindings
type t
type database
type openRequest
type idbTransaction
type objectStore
type request
type stringList

@val external indexedDB: t = "indexedDB"
@send external open_: (t, string, int) => openRequest = "open"
@set external set_onupgradeneeded: (openRequest, 'event => unit) => unit = "onupgradeneeded"
@set external set_onsuccess: (request, 'event => unit) => unit = "onsuccess"
@set external set_onsuccess_open: (openRequest, 'event => unit) => unit = "onsuccess"
@set external set_onerror_open: (openRequest, 'event => unit) => unit = "onerror"
@get external openRequestResult: openRequest => database = "result"
@get external openRequestError: openRequest => exn = "error"
@send external createObjectStore: (database, string) => objectStore = "createObjectStore"
@get external objectStoreNames: database => stringList = "objectStoreNames"
@send external transaction: (database, string, string) => idbTransaction = "transaction"
@send external objectStore: (idbTransaction, string) => objectStore = "objectStore"
@set external set_oncomplete: (idbTransaction, 'event => unit) => unit = "oncomplete"
@set external set_onerror_transaction: (idbTransaction, 'event => unit) => unit = "onerror"
@send external get: (objectStore, string) => request = "get"
@send external put: (objectStore, 'a, string) => request = "put"
@send external delete: (objectStore, string) => request = "delete"
@send external clear: (objectStore) => request = "clear"
@get external requestResult: request => option<'a> = "result"
@get external requestError: request => exn = "error"
@get external transactionError: idbTransaction => exn = "error"
@set external set_onerror: (request, 'event => unit) => unit = "onerror"
@get external length: stringList => int = "length"
@send external item: (stringList, int) => string = "item"

let contains = (list, str) => {
  let rec loop = i => {
    if i >= list->length {
      false
    } else if list->item(i) == str {
      true
    } else {
      loop(i + 1)
    }
  }
  loop(0)
}
