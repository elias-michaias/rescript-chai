/* Raw opaque store type representing the actual Zustand instance (JS value).
  Use `rawStore` for low-level bindings that call into the runtime. */
type rawStore

/* Public typed store alias carrying the application model as `state`.
  This describes the shape exposed to ReScript consumers. At runtime the
  value is still the raw Zustand instance; Chai coerces the raw store into
  this public shape at the boundary so consumers can access `.state`. */
type store<'model> = {state: 'model}

type storeApi<'s> = {
  setState: ('s => 's) => unit,
  getState: unit => 's,
  subscribe: ('s => unit) => (unit => unit),
}

@module("zustand")
external create: (((('state => 'state) => unit, (unit => 'state), storeApi<'state>) => 'state) => rawStore) = "create"

@module("zustand/middleware")
external redux: (('state, 'action) => 'state, 'state) => ((('state => 'state) => unit, unit => 'state) => 'state) = "redux"

@module("zustand")
external useStore: (rawStore, 'state => 'selected) => 'selected = "useStore"

@send
external getState: (rawStore) => 'state = "getState"

@send
external subscribe: (rawStore, ('state => unit)) => (unit => unit) = "subscribe"

type plugin<'model, 'msg, 'cmd>

type reduxStoreState<'model, 'msg, 'cmd> = {
  state: 'model,
  dispatch: 'msg => unit,
  command: 'cmd,
  plugins: array<plugin<'model, 'msg, 'cmd>>,
}

/* state creator / initializer shape: (set, get, api) => state
  set has shape (updater: ('s => 's)) => unit */
type initializer<'s> = ((('s => 's) => unit), (unit => 's), storeApi<'s>) => 's
type createWrapper<'s> = initializer<'s> => initializer<'s>

type createFn<'s> = (initializer<'s> => rawStore)

type persistOptions<'state,'u> = {
  name: string,
  storage?: Js.Json.t,
  partialize?: 'state => 'u,
  onRehydrateStorage?: (option<'u> => unit),
  version?: int,
  migrate?: (Js.Json.t, int) => Js.Json.t,
  merge?: (Js.Json.t, Js.Json.t) => Js.Json.t,
  skipHydration?: bool,
}

type devtoolsOptions = {
  name?: string,
  enabled?: bool,
  anonymousActionType?: string,
  store?: string,
}

@module("zustand/middleware")
external persist: (initializer<'state>, persistOptions<'state, 'u>) => initializer<'state> = "persist"

@module("zustand/middleware")
external devtools: (initializer<'state>, devtoolsOptions) => initializer<'state> = "devtools"
