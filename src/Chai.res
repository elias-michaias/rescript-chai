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

/* Public store abstraction that hides the underlying Zustand.store and is
   generic only over the model type. Internally it's the same runtime value
   as `Zustand_.store` but callers won't see Zustand's extra type params. */
type store<'model> = Zustand_.store

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
let select = (store: store<'model>, selector) =>
    /* cast to the underlying runtime store and pass a typed selector that
         projects the model out of the reduxStoreState. We keep the cast local
         so callers never deal with Zustand's extra params. */
    Zustand_.useStore(Obj.magic(store), (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => selector(storeState.state))

/* A statically-typed JS-object shape for filtered stores. This lets us return an
   object that `Zustand_.useStore` accepts at runtime while keeping the wrapper's
   surface statically typed in ReScript. */
type filteredStore<'subModel, 'subMsg, 'cmd> = {. "getState": unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>, "subscribe": (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) }

let makeFilteredStore = (origStore: store<'model>, filterOpt: option<'model => 'subModel>, infuseOpt: option<'subMsg => 'msg>): filteredStore<'subModel,'subMsg,'cmd> => {
    /* getState returns a fully-typed reduxStoreState for the submodel/submsg */
    let getState: unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> = () => {
          /* get the underlying Zustand state; we don't know the parent's msg/cmd
              types here at the Chai API-level, so cast into the typed shape we need */
          let s: Zustand_.reduxStoreState<'model, 'msg, 'cmd> = Obj.magic(Zustand_.getState(Obj.magic(origStore)))
        let statePart: 'subModel = switch filterOpt { | Some(f) => f(s.state) | None => Obj.magic(s.state) }
        let dispatchPart: 'subMsg => unit = switch infuseOpt { | Some(inf) => (subMsg) => s.dispatch(inf(subMsg)) | None => (subMsg) => s.dispatch(Obj.magic(subMsg)) }
        {state: statePart, dispatch: dispatchPart, command: s.command}
    }

    /* subscribe accepts a listener that receives the typed sub-model state */
    let subscribe: (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) = (listener) => {
    let unsub = Zustand_.subscribe(Obj.magic(origStore), (s: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => {
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
let brew: (kettleConfig<'model, 'msg, 'cmd>) => (unit => (store<'model>, 'msg => unit)) = (config: kettleConfig<'model, 'msg, 'cmd>) => {
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
        /* expose the runtime store as our public `store<'model>` abstraction */
        let publicStore: store<'model> = Obj.magic(store)
        let dispatch = Zustand_.useStore(Obj.magic(store), (st: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => st.dispatch)
        (publicStore, dispatch)
    }

    useInstance
}

/* Pour helper: call this inside a component (it's a hook because it calls useInstance).
    It returns a filtered store and an infusing dispatch so components can opt-in to
    a submodel view safely and with static types. */
type pourOptions<'parentModel,'parentMsg,'subModel,'subMsg> = {filter: 'parentModel => 'subModel, infuse: 'subMsg => 'parentMsg}

let pour = (useInstanceHook: unit => (store<'parentModel>, 'parentMsg => unit), opts: pourOptions<'parentModel,'parentMsg,'subModel,'subMsg>) => {
    /* return a hook that components call */
    let useP = () => {
        let (store, dispatch) = useInstanceHook()
        let filtered: filteredStore<'subModel,'subMsg,'cmd> = makeFilteredStore(store, Some(opts.filter), Some(opts.infuse))
        /* present the filtered object as our public store<'subModel> */
        let wrappedStore: store<'subModel> = Obj.magic(filtered)
        let wrappedDispatch = (subMsg) => dispatch(opts.infuse(subMsg))
        (wrappedStore, wrappedDispatch)
    }
    useP
}
