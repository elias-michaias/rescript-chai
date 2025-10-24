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

// Hook for selecting from store with proper typing
let select = (store, selector) => {
  let v = Obj.magic(store)((storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => selector(storeState.state))
  v
}

type cupConfig<'model, 'subModel, 'msg, 'subMsg> = {
    store: Zustand_.store,
    dispatch: 'msg => unit,
    filter: 'model => 'subModel,
    infuse: 'subMsg => 'msg,
}

let useCup = (config: cupConfig<'model, 'subModel, 'msg, 'subMsg>) => {
    let useSubSelector = (subSelector) => {
        select(config.store, model => subSelector(config.filter(model)))
    }
    let cupDispatch = (subMsg) => config.dispatch(config.infuse(subMsg))
    
    (useSubSelector, cupDispatch)
}