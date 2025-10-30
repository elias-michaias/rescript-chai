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

  { history: history, index: index, push: push, undo: undo, redo: redo, goto: goto, clear: clear, reset: reset, getSnapshot: getSnapshot }
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
let plugin = (innerInit: Zustand_.initializer<Zustand_.reduxStoreState<'parent,'msg,'cmd>>, opts: chronoPluginOpts<'parent,'snap>) => {
  (set, get, api) => {
    /* call inner initializer to obtain base state */
    let base = innerInit(set, get, api)
    let baseTyped: Zustand_.reduxStoreState<'parent,'msg,'cmd> = Obj.magic(base)
    let initial = baseTyped.state

    /* helper to set the whole model snapshot */
    let setSnapshot = (m: 'parent) => set((curr: Zustand_.reduxStoreState<'parent,'msg,'cmd>) => {...curr, state: m})

    /* small guard to avoid recording snapshots produced by Chrono itself */
    let suppressPush: ref<bool> = ref(false)

    let makeProjected = (filter: 'parent => 'snap, apply: 'snap => ('parent => 'parent)) => {
      let setProjected = (snap: 'snap) => {
        let parentNow = (get() : Zustand_.reduxStoreState<'parent,'msg,'cmd>).state
        let updated = apply(snap)(parentNow)
        /* mark suppression so our subsequent set doesn't re-push */
        suppressPush.contents = true
        setSnapshot(updated)
        suppressPush.contents = false
      }
      createProjected(initial, filter, setProjected)
    }

    /* create chrono instance depending on whether projection is used */
    let baseChrono = switch (opts.filter, opts.apply) {
    | (Some(f), Some(a)) => {
        let c = makeProjected(f, a)
        /* subscribe to parent store changes and push projected snapshots */
        let _unsub = api.subscribe((st: Zustand_.reduxStoreState<'parent,'msg,'cmd>) => if suppressPush.contents { () } else { c.push(f(st.state)) })
        c
      }
    | _ => {
        let c = create(initial, s => { suppressPush.contents = true; setSnapshot(s); suppressPush.contents = false })
        /* subscribe to parent changes and push whole-model snapshots when parent changes */
        let _unsub = api.subscribe((st: Zustand_.reduxStoreState<'parent,'msg,'cmd>) => if suppressPush.contents { () } else { c.push(st.state) })
        c
      }
    }

    /* enforce max history length if requested */
    let chronoWithMax = switch opts.max {
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

    /* register plugin into plugins dict and return merged state */
    let d = Js.Dict.empty()
    Js.Dict.entries(baseTyped.plugins)->Array.forEach(((k, v)) => Js.Dict.set(d, k, v))
    Js.Dict.set(d, "chrono", Obj.magic(chronoWithMax))

    let mergeWithPlugins = %raw("(function(base, plugins){ var o = Object.assign({}, base); o.plugins = plugins; return o })")
    Obj.magic(mergeWithPlugins(Obj.magic(baseTyped), d))
  }
}


/* Convenience typed accessor: get chrono plugin from a typed redux state. */
let get = (store): option<chronoApi<'model>> => {
  Plugin.getPluginFromRawStore(store, "chrono")
}

