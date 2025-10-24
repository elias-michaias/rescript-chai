/* Custom Zustand middleware that is immediately pipeable */
let trace = (initializer, label) => (set, get, api) => {
  Js.log2("[dev-trace] initializing:", label)

  let wrappedSet = (updater) => {
    let before = get()
    let after = updater(before)
    Js.log2("[dev-trace] set:", label)
    Js.log2("before:", before)
    Js.log2("after:", after)
    set(_ => after)
  }

  initializer(wrappedSet, get, api)
}
