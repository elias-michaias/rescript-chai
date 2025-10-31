/* Small helper utilities used across the library.
   Keep these pure and free of side-effects so they can be reused
   and moved easily between modules. */

let rawToTypedState = (raw: Zustand_.rawStore) : Zustand_.reduxStoreState<'m,'msg,'cmd> => Obj.magic(Zustand_.getState(raw))

let attachRawUse = (trackedHook, rawUse) => Js.Dict.set(Obj.magic(trackedHook), "rawUse", Obj.magic(rawUse))

let getRawUse = (hook: Core.storeHook<'m,'d>) : option<Core.rawUseHook<'m,'d>> => {
  switch Js.Dict.get(Obj.magic(hook), "rawUse") {
  | Some(r) => Some(Obj.magic(r))
  | None => None
  }
}

let notifyPluginsOnSet = (plugins: Js.Dict.t<Zustand_.plugin<'m,'msg,'cmd>>, state: 'm) =>
  Js.Dict.entries(plugins)->Array.forEach(((_, p)) => Plugin.callOnSet(p, state))

let notifyPluginsOnDispatch = (plugins: Js.Dict.t<Zustand_.plugin<'m,'msg,'cmd>>, msg: 'msg) =>
  Js.Dict.entries(plugins)->Array.forEach(((_, p)) => Plugin.callOnDispatch(p, msg))

let getOrCreateFilteredStore = (
  lastRawRef: React.ref<option<Zustand_.rawStore>>,
  filteredRef: React.ref<option<Core.filteredStore<'subModel,'subMsg,'cmd>>>,
  rawStore: Zustand_.rawStore,
  filter: 'parentModel => 'subModel,
  infuse: 'subMsg => 'parentMsg,
) => {
  switch lastRawRef.current {
  | Some(r) when r == rawStore => switch filteredRef.current { | Some(f) => f | None => {
      let f = Core.makeFilteredStore(rawStore, Obj.magic(filter), Obj.magic(infuse))
      filteredRef.current = Some(f)
      f
    }}
  | _ => {
      let f = Core.makeFilteredStore(rawStore, Obj.magic(filter), Obj.magic(infuse))
      lastRawRef.current = Some(rawStore)
      filteredRef.current = Some(f)
      f
    }
  }
}
