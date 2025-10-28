import { createTrackedSelector } from 'react-tracked'
import { useStore as zustandUseStore } from 'zustand'

// WeakMap from raw Zustand store instance -> tracked selector hook
const trackedHookMap = new WeakMap()

export function makeTrackedInstanceHook(useInstance) {
  return function useTrackedInstance() {
    const tuple = useInstance()
    // expect tuple to be [store, dispatch]
    const store = tuple[0]
    const dispatch = tuple[1]

    let trackedHook = trackedHookMap.get(store)
    if (!trackedHook) {
      const useStateFromStore = () => zustandUseStore(store, (s) => s.state)
      trackedHook = createTrackedSelector(useStateFromStore)
      trackedHookMap.set(store, trackedHook)
    }

    const state = trackedHook()
    return [state, dispatch]
  }
}

export default makeTrackedInstanceHook
