/* Chrono

   Lightweight typed Chrono tracker used by the MVU core. It stores a
   history of full model snapshots and exposes typed undo/redo/goto that
   perform in-place sets by calling the provided setter passed at creation.
*/

type chronoApi<'model> = {
  history: ref<array<'model>>,
  index: ref<int>,
  push: 'model => unit,
  undo: unit => unit,
  redo: unit => unit,
  goto: int => unit,
  clear: unit => unit,
  reset: unit => unit,
  getSnapshot: int => option<'model>,
  dispose: unit => unit,
}

let create = (initialModel: 'model, setSnapshot: 'model => unit): chronoApi<'model> => {
  let history: ref<array<'model>> = ref([initialModel])
  let index: ref<int> = ref(0)

  let push = (m: 'model) => {
    /* trim future when pushing new snapshot */
    if index.contents < Belt.Array.length(history.contents) - 1 {
      history.contents = Belt.Array.slice(history.contents, ~offset=0, ~len=index.contents + 1)
    }
    history.contents = Belt.Array.concat(history.contents, [m])
    index.contents = Belt.Array.length(history.contents) - 1
  }

  let getSnapshot = idx => if idx < 0 || idx >= Belt.Array.length(history.contents) { None } else { Belt.Array.get(history.contents, idx) }

  let undo = () => {
    if index.contents <= 0 { () } else { index.contents = index.contents - 1; switch getSnapshot(index.contents) { | Some(s) => setSnapshot(s) | None => () } }
  }

  let redo = () => {
    if index.contents >= Belt.Array.length(history.contents) - 1 { () } else { index.contents = index.contents + 1; switch getSnapshot(index.contents) { | Some(s) => setSnapshot(s) | None => () } }
  }

  let goto = idx => {
    if idx < 0 || idx >= Belt.Array.length(history.contents) { () } else { index.contents = idx; switch getSnapshot(idx) { | Some(s) => setSnapshot(s) | None => () } }
  }

  let clear = () => {
    history.contents = [initialModel]
    index.contents = 0
  }

  let reset = () => {
    setSnapshot(initialModel)
  }

  let dispose = () => clear()

  { history: history, index: index, push: push, undo: undo, redo: redo, goto: goto, clear: clear, reset: reset, getSnapshot: getSnapshot, dispose: dispose }
}

/* Create a chrono that records snapshots of a projected sub-model.
   `filter` projects the parent model into a snapshot value. `setProjected`
   is a closure provided by the caller that knows how to apply a sub-snapshot
   back into the parent model (for example by reading the current parent
   model and returning an updated parent). This keeps the Chrono module
   generic and avoids reading parent state itself.
*/
let createProjected = (
  initialModel: 'parent,
  filter: 'parent => 'snap,
  setProjected: 'snap => unit,
): chronoApi<'snap> => {
  let initialSnap = filter(initialModel)
  create(initialSnap, setProjected)
}


/* Chrono plugin factory

   Returns a create-time wrapper compatible with the Zustand-style
   createWrapper pipeline used by `Chai.brew`. The wrapper will call the
   inner initializer to obtain the initial store state, create a Chrono
   instance (projected when `filter`/`apply` are provided) and inject the
   plugin instance into the resulting state's `plugins` Js.Dict under the
   "chrono" key.

   Options: enabled?: bool, max?: int, filter?: parent => snap, apply?: snap => parent => parent
*/
type chronoPluginOpts<'parent,'snap> = {
  max?: int,
  filter?: 'parent => 'snap,
  apply?: 'snap => ('parent => 'parent),
}

/* Chrono.plugin: pipeline-compatible function

   Zustand-style middleware uses the form `create ->devtools(opts)` which
   desugars to `devtools(create, opts)`. To be compatible with that pattern
   we expose `Chrono.plugin` as a two-argument function that accepts the
   initializer first and the options second, returning a new initializer.

   Example usage (in a create-wrapper pipeline):
     let plugins = create => create
       ->Chrono.plugin({ max: 10 })

   The pipeline call becomes Chrono.plugin(create, {max:10}), which this
   function handles by creating the plugin wrapper and applying it to the
   provided initializer.
*/
let plugin = (innerInit, opts: chronoPluginOpts<'parent,'snap>) => {
  /* Create the plugin spec and wrapper inside the function so types are
     monomorphic per call (avoids let-generalization issues). */
  let builder = (opts2: chronoPluginOpts<'parent,'snap>) => {
    let apiFactory = (ctx: Plugin.pluginContext<'parent,'msg,'cmd>) => {
      let setSnapshot = (m: 'parent) => ctx.setRaw((curr: Zustand_.reduxStoreState<'parent,'msg,'cmd>) => {...curr, state: m})
      let suppressPush: ref<bool> = ref(false)

      let makeProjected = (filter: 'parent => 'snap, apply: 'snap => ('parent => 'parent)) => {
        let setProjected = (snap: 'snap) => {
          let parentNow = ctx.getState().state
          let updated = apply(snap)(parentNow)
          suppressPush.contents = true
          setSnapshot(updated)
          suppressPush.contents = false
        }
        createProjected(ctx.initialModel, filter, setProjected)
      }

      let baseChrono = switch (opts2.filter, opts2.apply) {
      | (Some(f), Some(a)) => makeProjected(f, a)
      | _ => create(ctx.initialModel, s => { suppressPush.contents = true; setSnapshot(s); suppressPush.contents = false })
      }

      /* subscribe to future state changes and push snapshots into the chrono
         history unless a suppress flag is set (used by programmatic restores) */
      let unsubscribeRef: ref<option<unit => unit>> = ref(None)

      let subscribeToChanges = (isProjected: bool, filterFn: option<'parent => 'snap>) => {
        let unsub = ctx.subscribe(st => {
          if !suppressPush.contents {
            let current = st.state
            let snap = if isProjected {
              switch filterFn { | Some(f) => f(current) | None => Obj.magic(current) }
            } else {
              Obj.magic(current)
            }
            /* push the new snapshot into history */
            baseChrono.push(snap)
          } else {
            ()
          }
        })
        unsubscribeRef.contents = Some(unsub)
      }

      /* subscribe according to whether we're in projected mode */
      switch (opts2.filter, opts2.apply) {
      | (Some(_), Some(_)) => subscribeToChanges(true, opts2.filter)
      | _ => subscribeToChanges(false, None)
      }

      let chronoWithMax = switch opts2.max {
      | Some(max) => {
          let origPush = baseChrono.push
          let wrappedPush = (m: 'snap) => {
            origPush(m)
            let len = Belt.Array.length(baseChrono.history.contents)
            let keep = max + 1
            if len > keep {
              baseChrono.history.contents = Belt.Array.slice(baseChrono.history.contents, ~offset=len - keep, ~len=keep)
              baseChrono.index.contents = Belt.Array.length(baseChrono.history.contents) - 1
            } else {
              ()
            }
          }
          {...baseChrono, push: wrappedPush}
        }
      | None => baseChrono
      }

      let dispose = () => {
        /* unsubscribe if subscribed */
        switch unsubscribeRef.contents { | Some(u) => u() | None => () }
        chronoWithMax.clear()
      }

      let api = {
        history: chronoWithMax.history,
        index: chronoWithMax.index,
        push: chronoWithMax.push,
        undo: chronoWithMax.undo,
        redo: chronoWithMax.redo,
        goto: chronoWithMax.goto,
        clear: chronoWithMax.clear,
        reset: chronoWithMax.reset,
        getSnapshot: chronoWithMax.getSnapshot,
        dispose: dispose,
      }
      api
    }
    let spec: Plugin.pluginSpec<'parent,'msg,'cmd, chronoApi<'snap>> = { apiFactory: apiFactory }
    Plugin.toPluginSpec("chrono", spec)
  }
  let wrapper = Plugin.make(builder)(opts)
  wrapper(innerInit)
}

let get = (store): option<chronoApi<'snap>> => {
  switch Plugin.get(store, "chrono") {
    | Some(p) => Some(p)
    | None => None
  }
}