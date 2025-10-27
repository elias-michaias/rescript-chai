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

type brewConfigOptsChrono = {
  enabled?: bool,
  max?: int,
}

type brewConfigOpts = {
  chrono?: brewConfigOptsChrono
}

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
type brewConfig<'model, 'msg, 'cmd, 'chrono> = {
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
  middleware?: Zustand_.createWrapper<Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono>>,
  /** Optional subscription factory that produces subscriptions (or options) from the model.

  Factories may now return option<subscription> when conditionally included — the runtime
  will automatically flatten Somes and ignore Nones.

  ```rescript
  /* Example subscription factory that emits Tick every second when enabled */
  let subs = model => [Sub.Time.every(model.count <= 300, {interval:1000, cons: _ => MyMsg.Tick})]
  ```
  */
  subs?: 'model => array<option<Sub.subscription<'model,'msg>>>,

  opts?: brewConfigOpts,
}

/**
  Public store abstraction.
  The runtime Zustand store exposed only by model.

  ```rescript
  let s: store<{count:int}> = Obj.magic(Zustand_.create(...))
  ```
*/
type store<'model> = Zustand_.store<'model>

type storeHook<'model,'msg> = unit => (store<'model>, 'msg => unit)

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
  Zustand_.useStore(Obj.magic(store), (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd, 'chrono>) => selector(storeState.state))

let chrono = (store: store<'model>, selector): Chrono.chronoApi<'model> => {
   Zustand_.useStore(Obj.magic(store), (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd, 'chrono>) => selector(storeState.chrono))
}

/* Helper proxy factory is implemented in JS helper `src/utils/proxify.js`.
  We expose the proxify function (default export) from that module below.
*/

/** Runtime shape for a filtered store used by `pour` and `makeFilteredStore`.

  ```rescript
  let fs: filteredStore<{count:int}, SubMsg, cmd> = makeFilteredStore(store, Some(m => m.sub), Some(sub => ParentMsg.Sub(sub)))
  let st = fs["getState"]()
  ```
*/
type filteredStore<'subModel, 'subMsg, 'cmd, 'chrono> = {. "getState": unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd, 'chrono>, "subscribe": (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd, 'chrono> => unit) => (unit => unit) }

/**
  Create a runtime filtered store object that projects a parent store into a typed sub-model view.
  Used by `pour` to provide statically-typed submodel accessors compatible with `Zustand_.useStore`.

  ```rescript
  let filtered = makeFilteredStore(store, Some(m => m.counter), Some(sub => AppMsg.Counter(sub)))
  let (s, dispatch) = (Obj.magic(filtered), filtered["getState"]())
  ```
*/
let makeFilteredStore = (origStore: store<'model>, filterOpt: option<'model => 'subModel>, infuseOpt: option<'subMsg => 'msg>): filteredStore<'subModel,'subMsg,'cmd,'chrono> => {
  let getState: unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd, 'chrono> = () => {
    let s: Zustand_.reduxStoreState<'model, 'msg, 'cmd, 'chrono> = Obj.magic(Zustand_.getState(Obj.magic(origStore)))
    let statePart: 'subModel = switch filterOpt { | Some(f) => f(s.state) | None => Obj.magic(s.state) }
    let dispatchPart: 'subMsg => unit = switch infuseOpt { | Some(inf) => (subMsg) => s.dispatch(inf(subMsg)) | None => (subMsg) => s.dispatch(Obj.magic(subMsg)) }
    {state: statePart, dispatch: dispatchPart, command: s.command, chrono: s.chrono}
  }

  let subscribe: (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd, 'chrono> => unit) => (unit => unit) = (listener) => {
    let unsub = Zustand_.subscribe(Obj.magic(origStore), (s: Zustand_.reduxStoreState<'model, 'msg, 'cmd, 'chrono>) => {
      let statePart: 'subModel = switch filterOpt { | Some(f) => f(s.state) | None => Obj.magic(s.state) }
      let dispatchPart: 'subMsg => unit = switch infuseOpt { | Some(inf) => (subMsg) => s.dispatch(inf(subMsg)) | None => (subMsg) => s.dispatch(Obj.magic(subMsg)) }
      listener({state: statePart, dispatch: dispatchPart, command: s.command, chrono: s.chrono})
    })
    unsub
  }

  {"getState": getState, "subscribe": subscribe}
}

/**
  Create a lazily-initialized MVU-backed store and return a hook to access it.
  The returned hook creates the singleton store on first call and returns `(store<'model>, dispatch)`.
  If `config.run` is provided it is invoked whenever the store command value changes.
  If `config.subs` is provided subscriptions are evaluated and diffed by deterministic key to start and stop them.

  ```rescript
  let useApp = brew({update: (m, _)=> (m, ()), init: ({count:0}, ())})
  let (store, dispatch) = useApp()
  ```
*/
let brew: (brewConfig<'model, 'msg, 'cmd, 'chrono>) => (unit => (store<'model>, 'msg => unit)) = (config: brewConfig<'model, 'msg, 'cmd, 'chrono>) => {
  let storeRef: ref<option<Zustand_.rawStore>> = ref(None)

  let ensureStore = () => {
    switch storeRef.contents {
    | Some(s) => s
    | None => {
      let (initialModel, initialCmd) = config.init
      let initializer = ((set: (Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono> => Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono>) => unit), (_get: unit => Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono>), (_api: Zustand_.storeApi<Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono>>)) => {
      /* create a chrono tracker that can perform in-place sets by calling setSnapshotModel
        Respect brewConfig.opts.chrono: only push snapshots when enabled and honor `max` if provided */
      let setSnapshotModel = (m: 'model) => set((curr: Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono>) => {...curr, state: m})

      let chronoEnabled: bool = switch config.opts {
      | Some(opts) => switch opts.chrono { 
          | Some(c) => switch c.enabled { | Some(b) => b | None => false }
          | None => false 
        }
      | None => false
      }

      let chronoMax: option<int> = switch config.opts {
      | Some(opts) => switch opts.chrono { | Some(c) => c.max | None => None }
      | None => None
      }

      let chronoInstance = if chronoEnabled { Chrono.create(initialModel, setSnapshotModel) } else { Chrono.noop(initialModel, setSnapshotModel) }
      let chronoObj: Chrono.chronoApi<'model> = chronoInstance
        let storeState: Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono> = {
          state: initialModel,
          command: initialCmd,
          dispatch: (action) => set((current: Zustand_.reduxStoreState<'model,'msg,'cmd,'chrono>) => {
            let (newState, newCmd) = config.update(current.state, action)
            /* push snapshot to chrono and trim history to `max` when provided */
            chronoObj.push(newState)
            switch chronoMax {
            | Some(max) => {
              let len = Belt.Array.length(chronoObj.history.contents)
              if len > max {
                /* keep last `max` entries */
                chronoObj.history.contents = Belt.Array.slice(chronoObj.history.contents, ~offset=len - max, ~len=max)
                chronoObj.index.contents = Belt.Array.length(chronoObj.history.contents) - 1
              } else {
                ()
              }
            }
            | None => ()
            }
            {...current, state: newState, command: newCmd}
          }),
          chrono: chronoObj,
        }
        storeState
      }

      let enhancedInit = switch config.middleware { | Some(ext) => ext(initializer) | None => initializer }
  let s = Zustand_.create(enhancedInit)

      switch config.run { | Some(runFn) => {
        let state0: Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono> = Obj.magic(Zustand_.getState(s))
        let prevCmdRef = ref(state0.command)
        runFn(state0.command, state0.dispatch)->ignore
        let _unsub = Zustand_.subscribe(s, st => {
          let stTyped: Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono> = Obj.magic(st)
          if stTyped.command != prevCmdRef.contents {
            prevCmdRef.contents = stTyped.command
            runFn(stTyped.command, stTyped.dispatch)->ignore
          }
        })
      }
      | None => () }

      switch config.subs {
      | Some(subsFn) => {
        let getModel = () => (Obj.magic(Zustand_.getState(s)): Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono>).state

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

        let stateNow: Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono> = Obj.magic(Zustand_.getState(s))
        syncForModel(stateNow.state, stateNow.dispatch)

        let _unsub = Zustand_.subscribe(s, st => {
          let stTyped: Zustand_.reduxStoreState<'model,'msg,'cmd, 'chrono> = Obj.magic(st)
          syncForModel(stTyped.state, stTyped.dispatch)
        })
      }
      | None => ()
      }

      storeRef.contents = Some(s)
      s
    }
    }
  }

  let useInstance = () => {
   let store = ensureStore()
   /* Coerce the raw Zustand instance into the public typed store that exposes `.state`.
     This localized Obj.magic keeps the rest of the codebase ergonomic (store.state). */
   let publicStore: store<'model> = Obj.magic(store)
   let dispatch = Zustand_.useStore(store, (st: Zustand_.reduxStoreState<'model, 'msg, 'cmd, 'chrono>) => st.dispatch)
    (publicStore, dispatch)
  }

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
  Returns a hook which produces `(store<subModel>, dispatch)`.
  Dispatch accepts `subMsg` values.
  Useful for preventing components from accessing parts of the parent model or dispatching unrelated messages.

  ```rescript
  let useCounter = pour(useApp, {filter: m => m.counter, infuse: msg => CounterMsg(msg)})
  let (store, dispatch) = useCounter()
  ```
*/
let pour = (useInstanceHook: unit => (store<'parentModel>, 'parentMsg => unit), opts: pourOptions<'parentModel,'parentMsg,'subModel,'subMsg>) => {
  let useP = () => {
    let (store, dispatch) = useInstanceHook()
    let filtered: filteredStore<'subModel,'subMsg,'cmd, 'chrono> = makeFilteredStore(store, Some(opts.filter), Some(opts.infuse))
    let wrappedStore: store<'subModel> = Obj.magic(filtered)
    let wrappedDispatch = (subMsg) => dispatch(opts.infuse(subMsg))
    (wrappedStore, wrappedDispatch)
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
