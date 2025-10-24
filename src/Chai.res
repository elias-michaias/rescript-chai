module type Kettle = {
    type model
    type msg
    type cmd

    let update: (model, msg) => (model, cmd)
    let run: (cmd, msg => unit) => promise<unit>
}

type kettleConfig<'model, 'msg, 'cmd> = {
    update: ('model, 'msg) => ('model, 'cmd),
    run?: ('cmd, 'msg => unit) => promise<unit>,
    init: ('model, 'cmd),
    subs?: 'model => array<Sub.subscription<'msg>>,
}

/* Options passed to the generated hook to scope the store to a sub-model and sub-message */
type hookOptions<'model, 'msg, 'subModel, 'subMsg> = {
    filter: option<'model => 'subModel>,
    infuse: option<'subMsg => 'msg>,
}

let useKettle = (config) => {
    // Extract initial state
    let (initialModel, initialCmd) = config.init

    let (store, dispatch) = Zustand_.useZustandRedux(
        config.update,
        initialModel,
        initialCmd
    )

    // Always get current command for potential use in effects
    let currentCmd = Obj.magic(store)((storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => storeState.command)

    // Handle commands
    switch config.run {
        | Some(runFn) => {
            React.useEffect(() => {
                runFn(currentCmd, dispatch)->ignore
                None
            }, [currentCmd])
        }
        | None => ()
    }

    // Handle subscriptions
    switch config.subs {
        | Some(subsFn) => {
            let currentModel = Obj.magic(store)((storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => storeState.state)
            React.useEffect(() => {
                let subscriptions = subsFn(currentModel)
                let cleanups = subscriptions->Array.map(sub => sub.start(dispatch))
                Some(() => cleanups->Array.forEach(cleanup => cleanup()))
            }, [currentModel])
        }
        | None => ()
    }

      (store, dispatch)
}

// Top-level selector helper kept polymorphic per-call to avoid inference collisions
let select = (store, selector) =>
  Zustand_.useStore(store, (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => selector(storeState.state))

/* A statically-typed JS-object shape for filtered stores. This lets us return an
   object that `Zustand_.useStore` accepts at runtime while keeping the wrapper's
   surface statically typed in ReScript. */
type filteredStore<'subModel, 'subMsg, 'cmd> = {. "getState": unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>, "subscribe": (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) }

let makeFilteredStore = (origStore: Zustand_.store, filterOpt: option<'model => 'subModel>, infuseOpt: option<'subMsg => 'msg>): filteredStore<'subModel,'subMsg,'cmd> => {
    /* getState returns a fully-typed reduxStoreState for the submodel/submsg */
    let getState: unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> = () => {
        let s: Zustand_.reduxStoreState<'model, 'msg, 'cmd> = Obj.magic(Zustand_.getState(origStore))
        let statePart: 'subModel = switch filterOpt { | Some(f) => f(s.state) | None => Obj.magic(s.state) }
        let dispatchPart: 'subMsg => unit = switch infuseOpt { | Some(inf) => (subMsg) => s.dispatch(inf(subMsg)) | None => (subMsg) => s.dispatch(Obj.magic(subMsg)) }
        {state: statePart, dispatch: dispatchPart, command: s.command}
    }

    /* subscribe accepts a listener that receives the typed sub-model state */
    let subscribe: (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) = (listener) => {
        let unsub = Zustand_.subscribe(origStore, (s: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => {
            let statePart: 'subModel = switch filterOpt { | Some(f) => f(s.state) | None => Obj.magic(s.state) }
            let dispatchPart: 'subMsg => unit = switch infuseOpt { | Some(inf) => (subMsg) => s.dispatch(inf(subMsg)) | None => (subMsg) => s.dispatch(Obj.magic(subMsg)) }
            listener({state: statePart, dispatch: dispatchPart, command: s.command})
        })
        unsub
    }

    {"getState": getState, "subscribe": subscribe}
}

// Brew: return a hook factory. The returned hook lazily creates and wires the underlying
// Zustand store on first use. Moving initialization into the returned function avoids
// doing top-level side-effects at brew time and prevents the value-restriction that
// forced callers to annotate types.
let brew: (kettleConfig<'model, 'msg, 'cmd>) => (unit => (Zustand_.store, 'msg => unit)) = (config: kettleConfig<'model, 'msg, 'cmd>) => {
    let storeRef: ref<option<Zustand_.store>> = ref(None)

    let ensureStore = () => {
        switch storeRef.contents {
        | Some(s) => s
        | None => {
            let (initialModel, initialCmd) = config.init
            let s = Zustand_.createZustandRedux(config.update, initialModel, initialCmd)

            /* wire run() once using the imperative subscribe/getState API */
            switch config.run {
            | Some(runFn) => {
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
                // note: unsub intentionally dropped for singleton lifetime
            }
            | None => ()
            }

            /* start subs once (app lifetime) */
            switch config.subs {
            | Some(subsFn) => {
                let stateNow: Zustand_.reduxStoreState<'model,'msg,'cmd> = Obj.magic(Zustand_.getState(s))
                let modelNow = stateNow.state
                let subscriptions = subsFn(modelNow)
                let _cleanups = subscriptions->Array.map(sub => sub.start(stateNow.dispatch))
            }
            | None => ()
            }

            storeRef.contents = Some(s)
            s
        }
        }
    }

    // Returned hook: creates store lazily and then uses Zustand_.useStore for per-component dispatch
    let useInstance = () => {
        let store = ensureStore()
        let dispatch = Zustand_.useStore(store, (st: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => st.dispatch)
        (store, dispatch)
    }

    useInstance
}

/* Pour helper: call this inside a component (it's a hook because it calls useInstance).
    It returns a filtered store and an infusing dispatch so components can opt-in to
    a submodel view safely and with static types. */
type pourOptions<'parentModel,'parentMsg,'subModel,'subMsg> = {filter: 'parentModel => 'subModel, infuse: 'subMsg => 'parentMsg}

let pour = (useInstanceHook: unit => (Zustand_.store, 'parentMsg => unit), opts: pourOptions<'parentModel,'parentMsg,'subModel,'subMsg>) => {
  let (store, dispatch) = useInstanceHook()
  let filtered: filteredStore<'subModel,'subMsg,'cmd> = makeFilteredStore(store, Some(opts.filter), Some(opts.infuse))
  let wrappedStore: Zustand_.store = Obj.magic(filtered)
  let wrappedDispatch = (subMsg) => dispatch(opts.infuse(subMsg))
  (wrappedStore, wrappedDispatch)
}
