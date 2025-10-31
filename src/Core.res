module type Kettle = {
    type model
    type msg
    type cmd
    let update: (model, msg) => (model, cmd)
    let run: (cmd, msg => unit) => promise<unit>
}

type baseCreate<'model,'msg,'cmd> = (('model, 'msg) => ('model, 'cmd), 'model, 'cmd) => Zustand_.rawStore

type createFn<'s> = (Zustand_.initializer<'s> => Zustand_.rawStore)

type createWrapperForCreate<'s> = createFn<'s> => createFn<'s>

type brewConfigOpts<'model, 'sub> = {}

type store<'model> = Zustand_.store<'model>

type storeHook<'model,'msg> = (~init: (unit => 'msg)=?) => ('model, 'msg => unit, Zustand_.rawStore)

type rawUseHook<'m,'d> = (~init: (unit => 'd)=?) => (store<'m>, 'd => unit, Zustand_.rawStore)

type hookOptions<'model, 'msg, 'subModel, 'subMsg> = {
    filter: option<'model => 'subModel>,
    infuse: option<'subMsg => 'msg>,
}

type filteredStore<'subModel, 'subMsg, 'cmd> = {. "getState": unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>, "subscribe": (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) }

let select = (store: store<'model>, selector) =>
  Zustand_.useStore(Obj.magic(store), (storeState: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => selector(storeState.state))

let makeFilteredStore = (origRawStore: Zustand_.rawStore, filterOpt: 'parentModel => 'subModel, infuseOpt: 'subMsg => 'parentMsg): filteredStore<'subModel,'subMsg,'cmd> => {
  let getState: unit => Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> = () => {
      let s: Zustand_.reduxStoreState<'parentModel, 'parentMsg, 'cmd> = Obj.magic(Zustand_.getState(origRawStore))
      let statePart: 'subModel = filterOpt(s.state)
      let dispatchPart: 'subMsg => unit = (subMsg) => s.dispatch(infuseOpt(subMsg))
      {state: statePart, dispatch: dispatchPart, command: s.command, plugins: s.plugins}
  }

  let subscribe: (Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd> => unit) => (unit => unit) = (listener) => {
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