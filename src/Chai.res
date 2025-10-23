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

let useKettle = (config): (
    'model,
    'msg => unit
) => {
    let ((model, cmd), dispatch) = React.useReducer(
        ((model, _cmd), msg) => config.update(model, msg),
        config.init
    )

    // Handle commands
    switch config.run {
        | Some(runFn) => {
            React.useEffect(() => {
                runFn(cmd, msg => dispatch(msg))->ignore
                None
            }, [cmd])
        }
        | None => ()
    }

    // Handle subscriptions
    switch config.subs {
        | Some(subsFn) => {
            React.useEffect(() => {
                let subscriptions = subsFn(model)
                let cleanups = subscriptions->Array.map(sub => sub.start(dispatch))
                Some(() => cleanups->Array.forEach(cleanup => cleanup()))
            }, [subsFn])
        }
        | None => ()
    }

    (model, msg => dispatch(msg))
}

type cupConfig<'model, 'subModel, 'msg, 'subMsg> = {
    model: 'model,
    dispatch: 'msg => unit,
    filter: 'model => 'subModel,
    infuse: 'subMsg => 'msg,
}

let useCup = (config) => {
    let subModel = config.filter(config.model)
    let subDispatch = (subMsg) => config.dispatch(config.infuse(subMsg))
    
    (subModel, subDispatch)
}