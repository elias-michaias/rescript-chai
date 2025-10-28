/* createTrackedSelector expects a selector-taking hook (like zustand's useStore)
   and returns a hook that returns a proxied state object. The JS type is
   (useSelectorHook) => useTrackedHook. We express it as taking a function that
   accepts a selector and returns the selected value, and returning a hook
   which when called returns the selected/proxied value. */

@module("react-tracked")
external createTrackedSelector: ((('state => 'selected) => 'selected) => (unit => 'selected)) = "createTrackedSelector"