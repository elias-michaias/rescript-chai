type store

type storeApi<'s> = {
  setState: ('s => 's) => unit,
  getState: unit => 's,
  subscribe: ('s => unit) => (unit => unit),
}

@module("zustand")
external create: (((('state => 'state) => unit, (unit => 'state), storeApi<'state>) => 'state) => store) = "create"

@module("zustand/middleware")
external redux: (('state, 'action) => 'state, 'state) => ((('state => 'state) => unit, unit => 'state) => 'state) = "redux"

@module("zustand")
external useStore: ('store, 'state => 'selected) => 'selected = "useStore"

@send
external getState: ('store) => 'state = "getState"

@send
external subscribe: ('store, ('state => unit)) => (unit => unit) = "subscribe"

type reduxStoreState<'model, 'msg, 'cmd> = {
  state: 'model,
  dispatch: 'msg => unit,
  command: 'cmd,
}

let useZustandRedux = (update, initialModel, initialCmd) => {
  let storeRef = React.useRef(None)
  if storeRef.current == None {
    let storeInstance = create(((set: (reduxStoreState<'model,'msg,'cmd> => reduxStoreState<'model,'msg,'cmd>) => unit), _get, _api) => {
      let storeState = {
        state: initialModel,
        command: initialCmd,
        dispatch: (action) => set((current: reduxStoreState<'model,'msg,'cmd>) => {
          let (newState, newCmd) = update(current.state, action)
          {...current, state: newState, command: newCmd}
        })
      }
      storeState
    })
    storeRef.current = Some(storeInstance)
  }

  let store = storeRef.current->Option.getUnsafe

  let dispatch = useStore(store, storeState => storeState.dispatch)

  (store, dispatch)
}

let createZustandRedux = (update, initialModel, initialCmd) => {
  let storeInstance = create(((set: (reduxStoreState<'model,'msg,'cmd> => reduxStoreState<'model,'msg,'cmd>) => unit), _get, _api) => {
    let storeState = {
      state: initialModel,
      command: initialCmd,
      dispatch: (action) => set((current: reduxStoreState<'model,'msg,'cmd>) => {
        let (newState, newCmd) = update(current.state, action)
        {...current, state: newState, command: newCmd}
      })
    }
    storeState
  })
  storeInstance
}

/* state creator / initializer shape: (set, get, api) => state
  set has shape (updater: ('s => 's)) => unit */
type initializer<'s> = ((('s => 's) => unit), (unit => 's), storeApi<'s>) => 's
type createWrapper<'s> = initializer<'s> => initializer<'s>

type createFn<'s> = (initializer<'s> => store)

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
