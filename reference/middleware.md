# `rescript-chai`

## Middleware

Chai builds stores using Zustand and supports applying Zustand middleware at create-time. This document shows how to write a simple middleware in ReScript (or bind an existing JS middleware) and then pipe it into `Chai.brew`'s `middleware` option.

Zustand middleware are wrappers with the shape:

```rescript
initializer<'s> => initializer<'s>
```

Where `initializer<'s>` is the state-creator function with the signature:

```rescript
(set, get, api) => initialState
```

In Chai the `brew` config accepts a `middleware` function which will be applied to the initializer before the final call to `Zustand.create`:

```rescript
let middleware = (store) => store
    ->Zustand_.persist({name: "counter"})
    ->Zustand_.devtools({})

let useCounter = Chai.brew({ 
    update, run, subs, init, middleware  
})
```


### Writing new middleware

This example showcases a simple tracing middleware that logs all state changes. Notice how ReScript's powerful type inference is able to let the following code compile without type signatures provided:

```rescript
// DevTraceMiddleware.res
let trace = (initializer, label) => (set, get, api) => {
  Js.log2("[dev-trace] initializing:", label)

  let wrappedSet = (updater) => {
    let before = get()
    let after = updater(before)
    Js.log2("[dev-trace] set:", label)
    Js.log2("before:", before)
    Js.log2("after:", after)
    set(_ => after)
  }

  initializer(wrappedSet, get, api)
}
```

Use it in your app when you call `Chai.brew`:

```rescript
let middleware = (store) => store
    // our custom zustand middleware
    ->DevTraceMiddleware.trace("Counter Store")

    // Chai's provided zustand middleware bindings
    ->Zustand_.persist({name: "counter"})
    ->Zustand_.devtools({})

let useCounter = Chai.brew({ 
    update, run, subs, init, middleware  
})
```

### Binding JS middleware

If you want to bind an existing JS middleware (for example from `zustand/middleware`), export a ReScript external that matches the native signature using Chai's `initializer<'s>` type. Here are the bindings that Chai provides for Zustand's built-in `persist` and `devtools` middlewares:

```rescript
type persistOptions<'state,'u> = {
  name: string,
  storage?: Js.Json.t,
  partialize?: 'state => 'u,
  onRehydrateStorage?: (option<'u> => unit),
  version?: int,
  migrate?: (Js.Json.t, int) => Js.Json.t,
  merge?: (Js.Json.t, Js.Json.t) => Js.Json.t,
  skipHydration?: bool,
}

@module("zustand/middleware")
external persist: (initializer<'state>, persistOptions<'state, 'u>) => initializer<'state> = "persist"

type devtoolsOptions = {
  name?: string,
  enabled?: bool,
  anonymousActionType?: string,
  store?: string,
}

@module("zustand/middleware")
external devtools: (initializer<'state>, devtoolsOptions) => initializer<'state> = "devtools"
```

### Redux DevTools

Chai provides Zustand's `devtools` middleware out of the box. In order to use it, you will need to set up the [Redux DevTools](https://github.com/reduxjs/redux-devtools). You are highly encouraged to set them up. The Redux DevTools provide an unmatched developer experience when developing with Chai.
