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
  | Some(p) =>
      /* If the runtime plugin object stores its created API under the
         `api` key (set by `toPluginSpec` / `makeRuntime`), prefer
         returning that API so consumers get the typed runtime surface.
         Otherwise fall back to returning the stored value directly. */
      switch Js.Dict.get(Obj.magic(p), "api") {
      | Some(apiVal) => Some(Obj.magic(apiVal))
      | None => Some(Obj.magic(p))
      }
  | None => None
  }
}

let get = (rawStore: Zustand_.rawStore, name: string) : option<'p> => {
  let s: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(Zustand_.getState(Obj.magic(rawStore)))
  getPluginFromState(s, name)
}

/* Helper to convert a typed plugin value into the opaque runtime plugin type
   used by the storr. This centralizes Obj.magic usage for plugin authors. */
let toPlugin = (v: 'a) : Zustand_.plugin<'m,'msg,'cmd> => Obj.magic(v)

/* Lifecycle invokers for opaque plugin objects stored at runtime.
   These helpers centralize Obj.magic usage so the runtime can call
   optional lifecycle callbacks exported by plugin instances. */
let callOnUse = (p) => {
  switch Js.Dict.get(Obj.magic(p), "onUse") {
  | Some(f) => Obj.magic(f)()
  | None => ()
  }
}

let callOnDispatch = (p, msg) => {
  switch Js.Dict.get(Obj.magic(p), "onDispatch") {
  | Some(f) => Obj.magic(f)(msg)
  | None => ()
  }
}

let callOnSet = (p, model) => {
  switch Js.Dict.get(Obj.magic(p), "onSet") {
  | Some(f) => Obj.magic(f)(model)
  | None => ()
  }
}

let callOnRun = (p, cmd) => {
  switch Js.Dict.get(Obj.magic(p), "onRun") {
  | Some(f) => Obj.magic(f)(cmd)
  | None => ()
  }
}

let callOnUnmount = (p) => {
  switch Js.Dict.get(Obj.magic(p), "onUnmount") {
  | Some(f) => Obj.magic(f)()
  | None => ()
  }
}

let callOnChange = (p, init) => {
  switch Js.Dict.get(Obj.magic(p), "onChange") {
  | Some(f) => Obj.magic(f)(init)
  | None => init
  }
}

/* Typed plugin spec for plugin authors. Plugin authors construct this
   record and call `toPluginSpec` to convert to the opaque runtime plugin
   object. This keeps all untyped interop inside `Plugin.res`. */
type pluginSpec<'model,'msg,'cmd,'api> = {
  api?: 'api,
  onUse?: unit => unit,
  onSet?: 'model => unit,
  onDispatch?: 'msg => unit,
  onRun?: 'cmd => unit,
  onUnmount?: unit => unit,
  onChange?: (Zustand_.initializer<Zustand_.reduxStoreState<'model,'msg,'cmd>> => Zustand_.initializer<Zustand_.reduxStoreState<'model,'msg,'cmd>>),
  apiFactory?: (pluginContext<'model,'msg,'cmd> => 'api),
}

type pluginEntry<'m,'msg,'cmd> = { name: string, plugin: Zustand_.plugin<'m,'msg,'cmd> }

let toPluginSpec = (name: string, spec: pluginSpec<'m,'msg,'cmd,'api>) : pluginEntry<'m,'msg,'cmd> => {
  let d = Js.Dict.empty()
  /* store the public API under `api` */
  Js.Dict.set(d, "api", Obj.magic(spec.api))
  switch spec.onUse { | Some(f) => Js.Dict.set(d, "onUse", Obj.magic(f)) | None => () }
  switch spec.onDispatch { | Some(f) => Js.Dict.set(d, "onDispatch", Obj.magic(f)) | None => () }
  switch spec.onSet { | Some(f) => Js.Dict.set(d, "onSet", Obj.magic(f)) | None => () }
  switch spec.onRun { | Some(f) => Js.Dict.set(d, "onRun", Obj.magic(f)) | None => () }
  switch spec.onUnmount { | Some(f) => Js.Dict.set(d, "onUnmount", Obj.magic(f)) | None => () }
  switch spec.onChange { | Some(f) => Js.Dict.set(d, "onChange", Obj.magic(f)) | None => () }
  switch spec.apiFactory { | Some(f) => Js.Dict.set(d, "apiFactory", Obj.magic(f)) | None => () }
  { name: name, plugin: Obj.magic(d) }
}

/* Create the runtime API for a plugin (if it provided an apiFactory).
   This must be called inside a Zustand initializer where `set`, `get`, `api`
   are available. It will call the typed factory and store the resulting
   runtime API into the opaque plugin object under the `api` key. */
let makeRuntime = (
  pluginOpaque: Zustand_.plugin<'m,'msg,'cmd>,
  set: (Zustand_.reduxStoreState<'m,'msg,'cmd> => Zustand_.reduxStoreState<'m,'msg,'cmd>) => unit,
  get: unit => Zustand_.reduxStoreState<'m,'msg,'cmd>,
  api: Zustand_.storeApi<Zustand_.reduxStoreState<'m,'msg,'cmd>>,
) => {
  switch Js.Dict.get(Obj.magic(pluginOpaque), "apiFactory") {
  | Some(f) => {
      /* build a typed pluginContext to pass to the factory */
      let st: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(get())
      let initialModel = st.state
      let setSnapshot = (m: 'm) => set((curr: Zustand_.reduxStoreState<'m,'msg,'cmd>) => {...curr, state: m})
      let ctx: pluginContext<'m,'msg,'cmd> = { initialModel: initialModel, setSnapshot: setSnapshot, getState: get, setRaw: set, subscribe: api.subscribe }
      let apiVal = Obj.magic(f)(ctx)
      /* store the created API under `api` */
      Js.Dict.set(Obj.magic(pluginOpaque), "api", Obj.magic(apiVal))
      /* if the created API exposes a `dispose` (unsubscribe) function, register it
         as the plugin's onUnmount so the runtime can call it when unmounting */
      switch Js.Dict.get(Obj.magic(apiVal), "dispose") {
      | Some(disposeF) => Js.Dict.set(Obj.magic(pluginOpaque), "onUnmount", disposeF)
      | None => ()
      }
    }
  | None => ()
  }
  pluginOpaque
}

/* Convenience helper: convert a builder that returns a pluginEntry into a
   Zustand create-wrapper (pipeline) compatible function. This lets plugin
   authors write `let plugin = Plugin.make(opts => Plugin.toPluginSpec("name", spec))`
   and then apply the plugin in `brew` via the `plugins` pipeline. The wrapper
   will call the inner initializer, create the plugin entry, run `makeRuntime`
   (so apiFactory is executed inside the initializer), and merge the plugin
   into the returned state's plugins dict. */
let make = (builder: ('opts => pluginEntry<'m,'msg,'cmd>)) => (opts: 'opts) => (innerInit: Zustand_.initializer<Zustand_.reduxStoreState<'m,'msg,'cmd>>) => {
  (set, get, api) => {
    let base = innerInit(set, get, api)
    let baseTyped: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(base)
    /* create the plugin entry using the author's builder */
    let entry = builder(opts)
    /* create runtime API if factory present — pass a get that returns the baseTyped
       to avoid invoking the real `get` before the store is fully constructed. */
    let runtimePlugin = makeRuntime(entry.plugin, set, (() => baseTyped), api)
    /* merge existing plugins and register this plugin */
    let d = Js.Dict.empty()
    Js.Dict.entries(baseTyped.plugins)->Array.forEach(((k, v)) => Js.Dict.set(d, k, v))
    Js.Dict.set(d, entry.name, runtimePlugin)
    let mergeWithPlugins = %raw("(function(base, plugins){ var o = Object.assign({}, base); o.plugins = plugins; return o })")
    Obj.magic(mergeWithPlugins(Obj.magic(baseTyped), d))
  }
}

/* Create the runtime API for a plugin (if it provided an apiFactory).
   This must be called inside a Zustand initializer where `set`, `get`, `api`
   are available. It will call the typed factory and store the resulting
   runtime API into the opaque plugin object under the `api` key. */
let makeRuntime = (
  pluginOpaque: Zustand_.plugin<'m,'msg,'cmd>,
  set: (Zustand_.reduxStoreState<'m,'msg,'cmd> => Zustand_.reduxStoreState<'m,'msg,'cmd>) => unit,
  get: unit => Zustand_.reduxStoreState<'m,'msg,'cmd>,
  api: Zustand_.storeApi<Zustand_.reduxStoreState<'m,'msg,'cmd>>,
) => {
  switch Js.Dict.get(Obj.magic(pluginOpaque), "apiFactory") {
  | Some(f) => {
      /* build a typed pluginContext to pass to the factory */
      let st: Zustand_.reduxStoreState<'m,'msg,'cmd> = Obj.magic(get())
      let initialModel = st.state
      let setSnapshot = (m: 'm) => set((curr: Zustand_.reduxStoreState<'m,'msg,'cmd>) => {...curr, state: m})
      let ctx: pluginContext<'m,'msg,'cmd> = { initialModel: initialModel, setSnapshot: setSnapshot, getState: get, setRaw: set, subscribe: api.subscribe }
      let apiVal = Obj.magic(f)(ctx)
      /* store the created API under `api` */
      Js.Dict.set(Obj.magic(pluginOpaque), "api", Obj.magic(apiVal))
      /* if the created API exposes a `dispose` (unsubscribe) function, register it
         as the plugin's onUnmount so the runtime can call it when unmounting */
      switch Js.Dict.get(Obj.magic(apiVal), "dispose") {
      | Some(disposeF) => Js.Dict.set(Obj.magic(pluginOpaque), "onUnmount", disposeF)
      | None => ()
      }
    }
  | None => ()
  }
  pluginOpaque
}