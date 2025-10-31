open Core

let track = (useInstance: (~init: (unit => 'd)=?) => (store<'model>, 'd => unit, Zustand_.rawStore)) => {
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
  Helpers.attachRawUse(useTrackedInstance, useInstance)
  useTrackedInstance
}

type brewConfig<'model, 'sub, 'msg, 'cmd> = {
  update: ('model, 'msg) => ('model, 'cmd),
  run?: ('cmd, 'msg => unit) => promise<unit>,
  init: ('model, 'cmd),
  middleware?: Zustand_.createWrapper<Zustand_.reduxStoreState<'model,'msg,'cmd>>,
  plugins?: Zustand_.createWrapper<Zustand_.reduxStoreState<'model,'msg,'cmd>>,
  subs?: 'model => array<option<Sub.subscription<'model,'msg>>>,
}

let brew: (brewConfig<'model, 'sub, 'msg, 'cmd>) => storeHook<'model,'msg> = (config: brewConfig<'model, 'sub, 'msg, 'cmd>) => {
  let storeRef: ref<option<Zustand_.rawStore>> = ref(None)

  let ensureStore = () => {
    switch storeRef.contents {
      | Some(s) => s
      | None => {
        let (initialModel, initialCmd) = config.init
        let initializer = ((set: (Zustand_.reduxStoreState<'model,'msg,'cmd> => Zustand_.reduxStoreState<'model,'msg,'cmd>) => unit), (_get: unit => Zustand_.reduxStoreState<'model,'msg,'cmd>), (_api: Zustand_.storeApi<Zustand_.reduxStoreState<'model,'msg,'cmd>>)) => {
          let setWithPluginNotify = (updater: (Zustand_.reduxStoreState<'model,'msg,'cmd> => Zustand_.reduxStoreState<'model,'msg,'cmd>)) => {
            set((curr) => {
              let next = updater(curr)
              Js.Dict.entries(next.plugins)->Array.forEach(((_, p)) => Plugin.callOnSet(p, next.state))
              next
            })
          }

          let pluginsDict: Js.Dict.t<Zustand_.plugin<'model,'msg,'cmd>> = Js.Dict.empty()

          let storeState: Zustand_.reduxStoreState<'model,'msg,'cmd> = {
            state: initialModel,
            command: initialCmd,
            dispatch: (action) => setWithPluginNotify((current: Zustand_.reduxStoreState<'model,'msg,'cmd>) => {
              let (newState, newCmd) = config.update(current.state, action)
              {...current, state: newState, command: newCmd}
            }),
            plugins: pluginsDict,
          }
          storeState
        }

        let enhancedInit = switch config.middleware { | Some(ext) => ext(initializer) | None => initializer }
        let enhancedInit = switch config.plugins { | Some(pExt) => pExt(enhancedInit) | None => enhancedInit }
        let enhancedInit = enhancedInit
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
                  let startCancel = (mArg: 'model) => {
                    let raw = subsFn(mArg)
                    let nextList = raw->Belt.Array.keepMap(x => x)
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

      storeRef.contents = Some(s)
      s
      }
    }
  }


  let rawUseInstance = (~init=?) => {
   switch init { | Some(_cb) => () | None => () }
   let s = ensureStore()
  let publicStore: store<'model> = Obj.magic(s)
  let stNow = Helpers.rawToTypedState(s)
  Js.Dict.entries(stNow.plugins)->Array.forEach(((_, p)) => Plugin.callOnUse(p))

   let rawDispatch = Zustand_.useStore(s, (st: Zustand_.reduxStoreState<'model, 'msg, 'cmd>) => st.dispatch)
   let dispatch = (msg: 'msg) => {
  let current = Helpers.rawToTypedState(s)
  Helpers.notifyPluginsOnDispatch(current.plugins, msg)
     rawDispatch(msg)
   }
    (publicStore, dispatch, s)
  }

  let useInstance = track(rawUseInstance)

  useInstance
}

type pourOptions<'parentModel,'parentMsg,'subModel,'subMsg> = {
  filter: 'parentModel => 'subModel,
  infuse: 'subMsg => 'parentMsg,
}

let pour = (useInstanceHook: storeHook<'parentModel,'parentMsg>, opts: pourOptions<'parentModel,'parentMsg,'subModel,'subMsg>) => {
  let useP = (~init=?) => {
  let rawHookOpt = Helpers.getRawUse(useInstanceHook)

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

  let lastRawRef: React.ref<option<Zustand_.rawStore>> = React.useRef(None)
  let filteredRef: React.ref<option<Core.filteredStore<'subModel,'subMsg,'cmd>>> = React.useRef(None)
  let filtered = Helpers.getOrCreateFilteredStore(lastRawRef, filteredRef, rawStore, opts.filter, opts.infuse)

   let filteredToUse = Obj.magic(filtered)
    let useStateFromFiltered = (selector) =>
      Zustand_.useStore(filteredToUse, (storeState: Zustand_.reduxStoreState<'subModel, 'subMsg, 'cmd>) => selector(storeState.state))

    let useTracked = Tracked_.createTrackedSelector(useStateFromFiltered)
    let state: 'subModel = useTracked()

    let dispatch: 'subMsg => unit = (subMsg) => parentDispatch(opts.infuse(subMsg))

  switch init {
  | Some(cb) => React.useEffect0(() => { parentDispatch(opts.infuse(cb())); None })
  | None => ()
  }

    (state, dispatch, rawStore)
  }

  useP
}

let persist = Zustand_.persist

let devtools = Zustand_.devtools