/* ReactGlue: small adapter that centralizes React usage for the library.
   Exposes Glue-prefixed opaque types and functions so higher-level code
   can depend on `Glue.*` without importing React directly.
*/

type glueRef<'a> = React.ref<'a>

let useRef: unit => glueRef<option<'a>> = () => React.useRef(None)

/* The above placeholder for refGet/refSet must be implemented as small wrappers
   because ReScript's React.ref type is `React.ref` which doesn't map 1:1 to an
   opaque typed value. We'll implement simple helpers using Obj.magic where
   required but keep the conversion in one place. */

let refGet = (r: glueRef<option<'a>>) : option<'a> => r.current

let refSet = (r: glueRef<option<'a>>, v: 'a) : unit => r.current = Some(v)

let useEffect0 = (f: unit => option<unit => unit>) => React.useEffect0(f)

/* Tracked selector adapter: we expect a function that, given a `useStore`-like
   function, returns a factory for tracked selection usage. The simplest approach
   is to delegate to `createTrackedSelector` which uses the React
   implementation (proxy-compare + hooks). */

@module("../utils/proxy-react.js")
external createTrackedSelector: ((('state => 'selected) => 'selected) => (unit => 'selected)) = "createTrackedSelector"

let createTrackedSelectorFromUseStore = (useStoreLike: ('selector => 'sel) => 'sel) => createTrackedSelector(useStoreLike)
