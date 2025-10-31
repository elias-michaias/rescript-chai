/* createTrackedSelector expects a selector-taking hook (like zustand's useStore)
   and returns a hook that returns a proxied state object. The JS type is
   (useSelectorHook) => useTrackedHook. We express it as taking a function that
   accepts a selector and returns the selected value, and returning a hook
   which when called returns the selected/proxied value. */
/*
   This is code pulled from Daishi Kato's react-tracked library.
   We copied the code so that we don't have to add react-tracked as a dependency.
   The library contains a lot of code we don't need.
 */

@module("../utils/proxy-react.js")
external createTrackedSelector: ((('state => 'selected) => 'selected) => (unit => 'selected)) = "createTrackedSelector"