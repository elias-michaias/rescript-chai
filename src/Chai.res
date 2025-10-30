/**
  Kettle signature.
  Lightweight MVU contract used for internal composition.

  ```rescript
  /* Minimal runnable Kettle implementation */
  module MyKettle = {
    let update = (model, msg) => switch msg {
      | Increment => ({...model, count: model.count + 1}, ())
      | Decrement => ({...model, count: model.count - 1}, ())
    }

    let run = (_cmd, _dispatch) => Js.Promise.resolve()
  }
  ```
*/
module type Kettle = {
  /** Application model.

  ```rescript
  type model = { count: int }
  ```
  */
  type model
  /** Messages dispatched by the view.

  ```rescript
  type msg = Increment | Decrement
  ```
  */
  type msg
  /** Command descriptor produced by the reducer.

  ```rescript
  type cmd = unit
  ```
  */
  type cmd

  /** Pure reducer from model and message to model and command.

  ```rescript
  let update = (model, msg) => switch msg {}
  ```
  */
  let update: (model, msg) => (model, cmd)

  /** Optional runner that executes a command and may dispatch messages.

  ```rescript
  let run = (cmd, dispatch) => switch cmd {}
  ```
  */
  let run: (cmd, msg => unit) => promise<unit>
}

/**
  Low-level initializer shape used to build the underlying Zustand store.
  Converts an MVU initializer into a runtime store.
  Private. Typed so middleware wrappers can be composed.

  ```rescript
  let init: baseCreate<MyModel,MyMsg,MyCmd> = (update, model, cmd) => Zustand_.create(...)
  ```
*/
type baseCreate<'model,'msg,'cmd> = (('model, 'msg) => ('model, 'cmd), 'model, 'cmd) => Zustand_.rawStore

/** Transforms a Zustand initializer into a store.

  ```rescript
  let makeCreate = init => Zustand_.create(init)
  ```
*/
type createFn<'s> = (Zustand_.initializer<'s> => Zustand_.rawStore)

/**
  Pipelineable wrapper for store creation.
  Use to compose create-time middleware such as `persist` and `devtools`.

  ```rescript
  /* Example: wrap a create function with persistence */
  let withPersist = create => persist(create)
  ```
*/
type createWrapperForCreate<'s> = createFn<'s> => createFn<'s>


type brewConfigOpts<'model, 'sub> = {}

/** Configuration record for `Chai.brew`.

  ```rescript
  /* Example brew configuration and usage */
  let cfg = {
    update: (model, msg) => switch msg {
      | Increment => ({...model, count: model.count + 1}, ())
      | Decrement => ({...model, count: model.count - 1}, ())
    },
    init: ({count: 0}, ())
  }

  let useApp = brew(cfg)
  ```
*/
type brewConfig<'model, 'sub, 'msg, 'cmd> = {
  /** Pure reducer that returns a new model and a command.

  ```rescript
  /* Example update producing a command */
  (model, msg) => switch msg {
  | Increment => ({...model, count: model.count + 1}, MyCmd)
  | Decrement => ({...model, count: model.count - 1}, MyCmd)
  }
  ```
  */
  update: ('model, 'msg) => ('model, 'cmd),
  /** Optional runner invoked when the store command changes.

  ```rescript
  /* Example run that inspects cmd and dispatches messages */
  (cmd, dispatch) => {
    switch cmd {
    | DoFetch(url) => {
        Js.Global.fetch(url)
        ->Js.Promise.then_(resp => resp.text())
        ->Js.Promise.then_(text => { dispatch(Fetched(text)); Js.Promise.resolve() })
      }
    | _ => Js.Promise.resolve()
    }
  }
  ```
  */
  run?: ('cmd, 'msg => unit) => promise<unit>,
  /** Initial model and command pair.

  ```rescript
  /* Example initial model and no-op command value */
  let init = ({count: 0}, ())
  ```
  */
  init: ('model, 'cmd),
  /** Optional create-time middleware wrapper such as `Zustand_.persist`.

  ```rescript
  /* Example middleware wrapper returned to brew */
  let middleware = store => store
    ->Chai.persist({name: "app"})
    ->Chai.devtools({})
  ```
  */
  middleware?: Zustand_.createWrapper<Zustand_.reduxStoreState<'model,'msg,'cmd>>,
  /** Optional plugin pipeline similar to `middleware`. Plugins are create-time
      wrappers that can inject plugin instances into the store's `plugins` dict.

      Example:
        let plugins = create => create
          ->Chrono.plugin({enabled: true})
          ->Magus.plugin({})
        ... brew({ ..., plugins })
  */
  plugins?: Zustand_.createWrapper<Zustand_.reduxStoreState<'model,'msg,'cmd>>,
  /** Optional subscription factory that produces subscriptions (or options) from the model.

  Factories may now return option<subscription> when conditionally included — the runtime
  will automatically flatten Somes and ignore Nones.

  ```rescript
  /* Example subscription factory that emits Tick every second when enabled */
  let subs = model => [Sub.Time.every(model.count <= 300, {interval:1000, cons: _ => MyMsg.Tick})]
  ```
  */
  subs?: 'model => array<option<Sub.subscription<'model,'msg>>>,

  opts?: brewConfigOpts<'model, 'sub>,
}

/**
  Public store abstraction.
  The runtime Zustand store exposed only by model.

  ```rescript
  let s: store<{count:int}> = Obj.magic(Zustand_.create(...))
  ```
*/
type store<'model> = Zustand_.store<'model>

/* A brewed hook optionally accepts a named init callback `~init` which returns a
  `msg` to be dispatched when the component mounts. Shape:
  (~init: unit => msg)=? => (state, dispatch, rawStore) */
type storeHook<'model,'msg> = (~init: (unit => 'msg)=?) => ('model, 'msg => unit, Zustand_.rawStore)

/* Raw-use hook alias used by `getRawUse` */
type rawUseHook<'m,'d> = (~init: (unit => 'd)=?) => (store<'m>, 'd => unit, Zustand_.rawStore)

/* Typed accessor for the rawUse property attached by `track`.
   This keeps Obj.magic localized to this helper while allowing callers
   (like `pour`) to pass a properly-typed `storeHook` so type inference
   is preserved at the call site. */
let getRawUse = (hook: storeHook<'m,'d>) : option<rawUseHook<'m,'d>> => {
  switch Js.Dict.get(Obj.magic(hook), "rawUse") {
  | Some(r) => Some(Obj.magic(r))
  | None => None
  }
}

/** Options passed to the generated hook when scoping to a sub-model.

  ```rescript
  let opts: hookOptions<{a:int}, AppMsg, {a:int}, SubMsg> = {filter: Some(m => m.a), infuse: Some(sub => AppMsg.Sub(sub))}
  ```
*/
type hookOptions<'model, 'msg, 'subModel, 'subMsg> = {
  /** Optional projection from parent model to sub-model.

  ```rescript
  Some(model => model.dropdown)
  ```
  */
  filter: option<'model => 'subModel>,
  /** Optional injection from sub-message into parent message.

  ```rescript
  Some(sub => ParentMsg.Sub(sub))
  ```
  */
  infuse: option<'subMsg => 'msg>,
}

/** Read a projection from a store using `Zustand_.useStore`.

  ```rescript
  let count = select(store, s => s.count)
  ```
*/
let select = (store: store<'model>, selector) =>
  Zustand_.useStore(Obj.magic(store), (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => selector(storeState.state))

/* Helper proxy factory is implemented in JS helper `src/utils/proxify.js`.
  We expose the proxify function (default export) from that module below.
*/

/** Runtime shape for a filtered store used by `pour` and `makeFilteredStore`.

  ```rescript
  let fs: filteredStore<{count:int}, SubMsg, cmd> = makeFilteredStore(store, Some(m => m.sub), Some(sub => ParentMsg.Sub(sub)))
  let st = fs["getState"]()
  ```
*/
type filteredStore<'subModel, 'subMsg, 'cmd> = {. "getState": unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>, "subscribe": (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) }

/**
  Create a runtime filtered store object that projects a parent store into a typed sub-model view.
  Used by `pour` to provide statically-typed submodel accessors compatible with `Zustand_.useStore`.

  ```rescript
  let filtered = makeFilteredStore(store, Some(m => m.counter), Some(sub => AppMsg.Counter(sub)))
  let (s, dispatch) = (Obj.magic(filtered), filtered["getState"]())
  ```
*/
let makeFilteredStore = (origRawStore: Zustand_.rawStore, filterOpt: 'parentModel => 'subModel, infuseOpt: 'subMsg => 'parentMsg): filteredStore<'subModel,'subMsg,'cmd> => {
    /* getState returns a fully-typed reduxStoreState for the submodel/submsg */
  let getState: unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> = () => {
      /* read the underlying Zustand state from the raw store and coerce to the typed shape we need */
      let s: Zustand_.reduxStoreState<'parentModel, 'parentMsg, 'cmd> = Obj.magic(Zustand_.getState(origRawStore))
      let statePart: 'subModel = filterOpt(s.state)
      let dispatchPart: 'subMsg => unit = (subMsg) => s.dispatch(infuseOpt(subMsg))
      {state: statePart, dispatch: dispatchPart, command: s.command, plugins: s.plugins}
  }

    /* subscribe accepts a listener that receives the typed sub-model state */
  let subscribe: (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) = (listener) => {
    /* Keep last projected value and only notify listeners if the projected
       submodel identity changed. This prevents churn when unrelated parts of
       the parent model update. */
    let lastRef: ref<option<'subModel>> = ref(None)
      let unsub = Zustand_.subscribe(Obj.magic(origRawStore), (s: Zustand_.reduxStoreState<'parentModel, 'parentMsg, 'cmd>) => {
    let projected: 'subModel = filterOpt(s.state)
    let changed = switch lastRef.contents {
      | None => true
      | Some(prev) => {
          if prev === projected {
            false
          } else {
            not(prev == projected)
          }
        }
    }
    if changed {
      lastRef.contents = Some(projected)
      let dispatchPart: 'subMsg => unit = (subMsg) => s.dispatch(infuseOpt(subMsg))
      listener({state: projected, dispatch: dispatchPart, command: s.command, plugins: s.plugins})
    } else {
      ()
    }
    })
    unsub
  }

    {"getState": getState, "subscribe": subscribe}
}

/* Create a tracked instance hook from a brewed useInstance hook.
   useInstance: unit => (rawStore, dispatch)
   returns: unit => (state, dispatch)

   Implementation notes: we create a closure `useStateFromStore` that reads
   the `.state` from the raw Zustand store using the existing `Zustand_.useStore`
   binding. Then we pass that hook into `createTrackedSelector` to obtain
   a proxy-tracking hook that only re-renders when accessed properties change.
*/
let track = (useInstance: (~init: (unit => 'd)=?) => (store<'model>, 'd => unit, Zustand_.rawStore)) => {
  /* Return a hook that accepts an optional init callback which will be run once
     on mount; if provided it returns a `d` message which we dispatch. */
  let useTrackedInstance = (~init=?) => {
    let triple = switch init {
    | Some(cb) => useInstance(~init=cb)
    | None => useInstance()
    }
    let (_publicStore, dispatch, rawStore) = triple
    let rawToUse = Obj.magic(rawStore)
    let useStateFromStore = (selector) =>
      Zustand_.useStore(rawToUse, (storeState: Zustand_.reduxStoreState<'model, 'd, 'cmd>) => selector(storeState.state))
    let useTracked = Tracked_.createTrackedSelector(useStateFromStore)
    let state: 'model = useTracked()
    switch init {
    | Some(cb) => React.useEffect0(() => { dispatch(cb()); None })
    | None => ()
    }
    (state, dispatch, rawStore)
  }
  /* Attach the raw `useInstance` to the returned tracked hook so callers
     (like `pour`) can obtain the raw store without subscribing to the
     tracked parent hook. We store it as a JS property named "rawUse". */
  Js.Dict.set(Obj.magic(useTrackedInstance), "rawUse", Obj.magic(useInstance))
  useTrackedInstance
}

/**
  Create a lazily-initialized MVU-backed store and return a hook to access it.
  The returned hook creates the singleton store on first call and by default returns the tracked `(state, dispatch)` pair.
  If `config.run` is provided it is invoked whenever the store command value changes.
  If `config.subs` is provided subscriptions are evaluated and diffed by deterministic key to start and stop them.

  ```rescript
  let useApp = brew({update: (m, _)=> (m, ()), init: ({count:0}, ())})
  let (store, dispatch) = useApp()
  ```
*/
let brew: (brewConfig<'model, 'sub, 'msg, 'cmd>) => storeHook<'model,'msg> = (config: brewConfig<'model, 'sub, 'msg, 'cmd>) => {
  let storeRef: ref<option<Zustand_.rawStore>> = ref(None)

  let ensureStore = () => {
    switch storeRef.contents {
    | Some(s) => s
    | None => {
      let (initialModel, initialCmd) = config.init
      let initializer = ((set: (Zustand_.reduxStoreState<'model,'msg,'cmd> => Zustand_.reduxStoreState<'model,'msg,'cmd>) => unit), (_get: unit => Zustand_.reduxStoreState<'model,'msg,'cmd>), (_api: Zustand_.storeApi<Zustand_.reduxStoreState<'model,'msg,'cmd>>)) => {
    let storeState: Zustand_.reduxStoreState<'model,'msg,'cmd> = {
      state: initialModel,
      command: initialCmd,
      dispatch: (action) => set((current: Zustand_.reduxStoreState<'model,'msg,'cmd>) => {
        let (newState, newCmd) = config.update(current.state, action)
        {...current, state: newState, command: newCmd}
      }),
      plugins: Js.Dict.empty(),
    }
    storeState
      }

    let enhancedInit = switch config.middleware { | Some(ext) => ext(initializer) | None => initializer }
    let enhancedInit = switch config.plugins { | Some(pExt) => pExt(enhancedInit) | None => enhancedInit }
  let s = Zustand_.create(enhancedInit)

      switch config.run { | Some(runFn) => {
        let state0: Zustand_.reduxStoreState<'model,'msg,'cmd> = Obj.magic(Zustand_.getState(s))
        let prevCmdRef = ref(state0.command)
        runFn(state0.command, state0.dispatch)->ignore
        let _unsub = Zustand_.subscribe(s, st => {
          let stTyped: Zustand_.reduxStoreState<'model,'msg,'cmd> = Obj.magic(st)
          if stTyped.command != prevCmdRef.contents {
            prevCmdRef.contents = stTyped.command
            runFn(stTyped.command, stTyped.dispatch)->ignore
          }
        })
      }
      | None => () }

      switch config.subs {
      | Some(subsFn) => {
  let getModel = () => (Obj.magic(Zustand_.getState(s)): Zustand_.reduxStoreState<'model,'msg,'cmd>).state

        let prevMapRef: ref<Js.Dict.t<unit => unit>> = ref(Js.Dict.empty())

        let syncForModel = (model: 'model, dispatch) => {
          let nextRaw = subsFn(model)
          let next = nextRaw->Belt.Array.keepMap(x => x)
          let nextMap = Js.Dict.empty()
          next->Array.forEach(sub => {
            let key = sub.key(model)
            switch Js.Dict.get(prevMapRef.contents, key) {
            | Some(oldCleanup) => Js.Dict.set(nextMap, key, oldCleanup)
            | None => {
              /* startCancel checks the latest subs for this model and cancels
                 the running subscription if its key is no longer present. This
                 prevents one trailing tick that can occur due to JS timers
                 and event loop ordering when a subscription is removed. */
              let startCancel = (mArg: 'model) => {
                let raw = subsFn(mArg)
                let nextList = raw->Belt.Array.keepMap(x => x)
                /* if no subscription in nextList has the same key for this model, cancel */
                not(nextList->Array.some(s => s.key(mArg) == key))
              }

              let cleanup = sub.start(dispatch, getModel, Some(startCancel))
              Js.Dict.set(nextMap, key, cleanup)
            }
            }
          })

          Js.Dict.entries(prevMapRef.contents)->Array.forEach(((k, cleanup)) => {
            switch Js.Dict.get(nextMap, k) {
            | Some(_) => ()
            | None => cleanup()
            }
          })
          prevMapRef.contents = nextMap
        }

        let stateNow: Zustand_.reduxStoreState<'model,'msg,'cmd> = Obj.magic(Zustand_.getState(s))
        syncForModel(stateNow.state, stateNow.dispatch)

        let _unsub = Zustand_.subscribe(s, st => {
          let stTyped: Zustand_.reduxStoreState<'model,'msg,'cmd> = Obj.magic(st)
          syncForModel(stTyped.state, stTyped.dispatch)
        })
      }
      | None => ()
      }

      /* No global registry: callers receive the raw Zustand store directly
        from `brew` so helpers like `pour` can construct filtered stores. */
      storeRef.contents = Some(s)
      s
    }
    }
  }


  /* raw useInstance returns the public store object and the dispatch; we
     wrap that with `track` to return the proxied state by default. */
  let rawUseInstance = (~init=?) => {
   /* consume optional init to satisfy callers; the tracked wrapper will
      perform the actual dispatch-on-mount behavior */
   switch init { | Some(_cb) => () | None => () }
   let s = ensureStore()
   let publicStore: store<'model> = Obj.magic(s)
   let dispatch = Zustand_.useStore(s, (st: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => st.dispatch)
   /* Return the public proxied store plus the underlying raw Zustand store for advanced use */
    (publicStore, dispatch, s)
  }

  /* Tracked default: call `track` with the rawUseInstance hook. */
  let useInstance = track(rawUseInstance)

  useInstance
}

/** Options for `Chai.pour` to produce a sub-view of the core MVU loop from a brewed `useInstance` hook.

  ```rescript
  let opts: pourOptions<ParentModel,ParentMsg,SubModel,SubMsg> = {filter: model => model.sub, infuse: sub => ParentMsg.Sub(sub)}
  ```
*/
type pourOptions<'parentModel,'parentMsg,'subModel,'subMsg> = {
  /** Projection from parent model to the sub-model.

  ```rescript
  model => model.dropdown
  ```
  */
  filter: 'parentModel => 'subModel,
  /** Injection from sub-message into the parent message space.

  ```rescript
  msg => DropdownMsg(submsg)
  ```
  */
  infuse: 'subMsg => 'parentMsg,
}

/**
  Use on a brewed `useInstance` hook to scope it to a typed sub-model view.
  Returns a hook which produces `(state, dispatch, store)` where `state` is the
  tracked proxied sub-model, `dispatch` accepts `subMsg` values and `store` is
  the underlying raw parent Zustand store (exposed for advanced use).

  ```rescript
  let useCounter = pour(useApp, {filter: m => m.counter, infuse: msg => CounterMsg(msg)})
  let (state, dispatch, store) = useCounter()
  ```
*/
let pour = (useInstanceHook: storeHook<'parentModel,'parentMsg>) => (opts: pourOptions<'parentModel,'parentMsg,'subModel,'subMsg>) => {
  let useP = (~init=?) => {
   /* We map init via `infuse` only when dispatching on mount below; no
     need to precompute a parentInit value here (avoids unused-vars). */

  /* Call the parent instance. Prefer the raw hook (attached as "rawUse")
    when present so we don't subscribe to the parent's tracked hook and
    cause extra re-renders; otherwise fall back to the provided hook.

    To avoid labeled-argument type mismatches we always call the hook with
    no arguments and, if an init callback was provided, dispatch the
    infused init message via an effect after obtaining the dispatch. */
  let rawHookOpt = getRawUse(useInstanceHook)

  /* Normalize the two possible hook shapes so both branches return the same
     tuple shape. When we have a raw-use hook it yields a `store<'parentModel>`
     as the first element; when we only have the tracked hook we yield no
     store value (None) but still return the same tuple shape using an
     option. This keeps the switch types consistent for the compiler. */
  let (_, parentDispatch, rawStore) = switch rawHookOpt {
  | Some(rawUse) => {
      let (storeVal, d, rs) = rawUse()
      (Some(storeVal), d, rs)
    }
  | None => {
      let (_, d, rs) = useInstanceHook()
      (None, d, rs)
    }
  }

    /* Build a runtime filtered store that projects the parent store into the submodel.
       Cache the filtered store per rawStore using refs so the store identity stays
       stable across renders. This avoids recreating the filtered object each render
       (which would cause extra evaluations). */
    /* Keep a typed ref to the last raw store we've seen so we can reuse
       the filtered store object for identity stability. Use explicit option
       type so comparisons are between `Zustand_.rawStore` values without Obj.magic. */
    let lastRawRef: React.ref<option<Zustand_.rawStore>> = React.useRef(None)
    let filteredRef: React.ref<option<filteredStore<'subModel,'subMsg,'cmd>>> = React.useRef(None)
    let filtered = switch lastRawRef.current {
    | Some(r) when r == rawStore => switch filteredRef.current { | Some(f) => f | None => {
  let f = makeFilteredStore(rawStore, Obj.magic(opts.filter), Obj.magic(opts.infuse))
        filteredRef.current = Some(f)
        f
      }}
    | _ => {
  let f = makeFilteredStore(rawStore, Obj.magic(opts.filter), Obj.magic(opts.infuse))
        lastRawRef.current = Some(rawStore)
        filteredRef.current = Some(f)
        f
      }
    }

   let filteredToUse = Obj.magic(filtered)
    let useStateFromFiltered = (selector) =>
      Zustand_.useStore(filteredToUse, (storeState: Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>) => selector(storeState.state))

    let useTracked = Tracked_.createTrackedSelector(useStateFromFiltered)
    let state: 'subModel = useTracked()

    let dispatch: 'subMsg => unit = (subMsg) => parentDispatch(opts.infuse(subMsg))

  /* If the caller passed an onInit callback, dispatch the infused message on mount. */
  switch init {
  | Some(cb) => React.useEffect0(() => { parentDispatch(opts.infuse(cb())); None })
  | None => ()
  }

    (state, dispatch, rawStore)
  }

  useP
}

/** Re-export of `Zustand_.persist` for compose-friendly middleware use.

  ```rescript
  /* Adding persist middleware */
  let middleware = (store) => store
    ->Chai.persist({name: "app"})
  ```
*/
let persist = Zustand_.persist

/** Re-export of `Zustand_.devtools` for developer tooling.

  ```rescript
  /* Adding devtools middleware */
  let middleware = (store) => store
    ->Chai.devtools({})
  ```
*/
let devtools = Zustand_.devtools