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

/* No-op chrono used when chrono is disabled. Provides the same API but
   performs no operations and keeps minimal empty history. */
let noop = (_initialModel: 'model, _setSnapshot: 'model => unit): chronoApi<'model> => {
  let history: ref<array<'model>> = ref([])
  let index: ref<int> = ref(-1)
  let push = (_m: 'model) => ()
  let undo = () => ()
  let redo = () => ()
  let goto = (_idx: int) => ()
  let clear = () => { history.contents = []; index.contents = -1 }
  let reset = () => ()
  let getSnapshot = (_idx: int) => None
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

let noopProjected = (
  _initialModel: 'parent,
  _filter: 'parent => 'snap,
  _setProjected: 'snap => unit,
): chronoApi<'snap> => {
  let history: ref<array<'snap>> = ref([])
  let index: ref<int> = ref(-1)
  let push = (_m: 'snap) => ()
  let undo = () => ()
  let redo = () => ()
  let goto = (_idx: int) => ()
  let clear = () => { history.contents = []; index.contents = -1 }
  let reset = () => ()
  let getSnapshot = (_idx: int) => None
  { history: history, index: index, push: push, undo: undo, redo: redo, goto: goto, clear: clear, reset: reset, getSnapshot: getSnapshot }
}
