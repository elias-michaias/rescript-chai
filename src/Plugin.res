/*
  Helper to retrieve the chrono API from a brewed or poured hook's raw store.
  Usage:
    let (_, _, raw) = useApp()
    let chrono = Chai.chronoFrom(raw)
  or when you have a public `store<'model>`: Chai.chronoFrom(Obj.magic(publicStore))
*/
/* Retrieve a plugin instance by name from a raw Zustand store. Returns option<plugin>. */
let getPlugin = (rawStore: Zustand_.rawStore, name: string) : option<Zustand_.plugin<'a,'b,'c>> => {
  let s: Zustand_.reduxStoreState<'a,'b,'c> = Obj.magic(Zustand_.getState(Obj.magic(rawStore)))
  switch Js.Dict.get(s.plugins, name) {
  | Some(p) => Some(Obj.magic(p))
  | None => None
  }
}


/* Typed API for plugin authors

   Plugin authors can use `createPluginWrapper` to build a typed create-wrapper
   without needing to use Obj.magic. The wrapper will be compatible with the
   `Chai.brew` `plugins` pipeline.
*/
type pluginContext<'model,'msg,'cmd> = {
  initialModel: 'model,
  setSnapshot: 'model => unit,
  getState: unit => Zustand_.reduxStoreState<'model,'msg,'cmd>,
  setRaw: (Zustand_.reduxStoreState<'model,'msg,'cmd> => Zustand_.reduxStoreState<'model,'msg,'cmd>) => unit,
  /* Subscribe to raw state changes (returns an unsubscribe function) */
  subscribe: (Zustand_.reduxStoreState<'model,'msg,'cmd> => unit) => (unit => unit),
}

/* Build a create-wrapper for a plugin named `name`.
   `makePlugin` receives a typed `pluginContext` and must return a plugin instance
   (opaque `Zustand_.plugin<...>`). The returned wrapper will call the inner
   initializer, build the plugin instance and inject it into the store's
   `plugins` Js.Dict under `name`.

   Example usage in Chrono.res:
     let chronoWrapper = Plugin.createPluginWrapper("chrono", ctx => Chrono.make(ctx))
     /* then applied: create => create -> chronoWrapper */
*/
let createPluginWrapper = (name: string, makePlugin: pluginContext<'m,'msg,'cmd> => Zustand_.plugin<'m,'msg,'cmd>) => (innerInit) => {
  (set, get, api) => {
  let base = innerInit(set, get, api)
  /* typed view of base so we can access fields safely */
  let baseTyped: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(base)
  /* typed initial model and helpers */
  let initialModel = baseTyped.state
    let setSnapshot = (m: 'm) => set((curr: Zustand_.reduxStoreState<'m,'msg,'cmd>) => {...curr, state: m})
  let ctx: pluginContext<'m,'msg,'cmd> = { initialModel: initialModel, setSnapshot: setSnapshot, getState: get, setRaw: set, subscribe: api.subscribe }

    let pluginInst = makePlugin(ctx)

    /* Merge existing plugins into a new dict and register this plugin */
    let d = Js.Dict.empty()
  Js.Dict.entries(baseTyped.plugins)->Array.forEach(((k, v)) => Js.Dict.set(d, k, v))
  Js.Dict.set(d, name, Obj.magic(pluginInst))

    /* Merge via raw Object.assign to avoid ReScript record checks */
    let mergeWithPlugins = %raw("
      (function(base, plugins){ var o = Object.assign({}, base); o.plugins = plugins; return o })
    ")
  Obj.magic(mergeWithPlugins(Obj.magic(baseTyped), d))
  }
}




/* Typed helpers to extract plugin instance from an already-typed state */
let getPluginFromState = (st: Zustand_.reduxStoreState<'m,'msg,'cmd>, name: string) : option<'p> => {
  switch Js.Dict.get(st.plugins, name) {
  | Some(p) => Some(Obj.magic(p))
  | None => None
  }
}

let getPluginFromRawStore = (rawStore: Zustand_.rawStore, name: string) : option<'p> => {
  let s: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(Zustand_.getState(Obj.magic(rawStore)))
  getPluginFromState(s, name)
}

/* Helper to convert a typed plugin value into the opaque runtime plugin type
   used by the store. This centralizes Obj.magic usage for plugin authors. */
let toPlugin = (v: 'a) : Zustand_.plugin<'m,'msg,'cmd> => Obj.magic(v)