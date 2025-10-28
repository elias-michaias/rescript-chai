@module("./registry.js")
external _register: (('a => unit), Js.t<{"raw": 'b, "chrono": 'c}>) => unit = "register"
@module("./registry.js")
external _lookup: (('a => unit)) => Js.Nullable.t<Js.t<{"raw": 'b, "chrono": 'c}>> = "lookup"
@module("./registry.js")
external _unregister: (('a => unit)) => bool = "unregister"

/* Typed wrappers that convert JS nullable into ReScript option and keep
   the unsafe casts localized here. `dispatch` is the registry key. */
let register = (dispatch: 'd => unit, raw: 'raw, chrono: 'chrono) => {
  /* pack raw + chrono into a JS object */
  let obj = Js.Obj.empty()
  Js.Obj.assign(obj, {"raw": Obj.magic(raw), "chrono": Obj.magic(chrono)})->ignore
  _register(dispatch, Obj.magic(obj))
}

let lookup = (dispatch: 'd => unit): option<('raw, 'chrono)> => {
  switch Js.Nullable.toOption(_lookup(dispatch)) {
  | None => None
  | Some(obj) => Some(obj["raw"], obj["chrono"])
  }
}

let unregister = (dispatch: 'd => unit) => _unregister(dispatch)
