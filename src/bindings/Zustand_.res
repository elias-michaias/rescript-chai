// Zustand bindings for ReScript
type store

// The create function from Zustand
@module("zustand")
external create: (((('state => 'state) => unit, unit => 'state) => 'state) => store) = "create"

// Redux middleware from Zustand
@module("zustand/middleware")
external redux: (('state, 'action) => 'state, 'state) => ((('state => 'state) => unit, unit => 'state) => 'state) = "redux"

// Hook to use the store
@module("zustand")
external useStore: ('store, 'state => 'selected) => 'selected = "useStore"

// Type for Zustand redux store state with command
type reduxStoreState<'model, 'msg, 'cmd> = {
  state: 'model,
  dispatch: 'msg => unit,
  command: 'cmd,
}

// Create a useReducer-like hook using Zustand
let useZustandRedux = (update, initialModel, initialCmd) => {
  // Create the store only once per component using a ref
  let storeRef = React.useRef(None)
  if storeRef.current == None {
    let storeInstance = create((set, _get) => {
      let storeState = {
        state: initialModel,
        command: initialCmd,
        dispatch: (action) => set(current => {
          let (newState, newCmd) = update(current.state, action)
          {...current, state: newState, command: newCmd}
        })
      }
      storeState
    })
    storeRef.current = Some(storeInstance)
  }

  let store = storeRef.current->Option.getUnsafe

  // Get dispatch by calling the hook returned from create
  let dispatch = Obj.magic(store)(storeState => storeState.dispatch)

  (store, dispatch)
}