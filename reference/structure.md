# `rescript-chai`

## Structure

This document explains the core types and functions used in Chai. 

### Model-View-Update  

If you've used TEA (The Elm Architecture) before, this should be familiar: you have a single source of truth (the model), messages that describe what happened, a pure update function, and a runner that interprets commands into effects that interact with the world.

### How Chai maps MVU to code

Chai exposes a single API to wire these pieces up: `Chai.brew(config)`.
The `config` contains `update`, `run`, `init`, optional `subs`, and a
`middleware` pipeline for the underlying Zustand store.

#### `Chai.brew(config)`

- `model`: the application state type.
- `msg`: the type of messages/actions that mutate the model.
- `cmd`: a data shape representing side-effect descriptions.
- `update`: `(model, msg) => (model, cmd)` - pure state transition.
- `run`: `(cmd, dispatch) => promise<unit>` - interpreter for side effects.
- `init`: `(model, cmd)` - initial model and initial command.
- `subs`: `model => array<Sub.subscription<'msg>>` - optional subscription generator.
- `middleware`: `initializer<'s> => initializer<'s>` - (see <a href="https://github.com/elias-michaias/rescript-chai/blob/main/reference/middleware.md">Middleware</a>).

### `useInstance`

`Chai.brew` returns a React hook (the `useInstance` hook). Calling that
hook returns a pair `(store, dispatch)` where:

- `store` is an opaque runtime reference to the Zustand store. You don't inspect it directly; instead use `store->select(...)` or
`Chai.pour` to view slices of the model.
- `dispatch` is a function you call with `msg` values to drive the
update function.

### Initialization process

1. First component calls the generated hook returned by `brew`.
2. Chai lazily creates the underlying store using an `initializer` that returns `{ state, dispatch, command }` (seeded from `init`).
3. If a `middleware` pipeline is provided, it's applied to the initializer so enhancers like `persist` or `devtools` are composed correctly.
4. The store is created with `Zustand.create(enhancedInitializer)`.
5. Chai subscribes to the store and calls your `run` for the initial command and whenever `command` updates.
6. Components use `store->select(selector)` or `Chai.pour` to get reactive slices and call `dispatch(msg)` to produce updates.

### Selectors and ergonomics

`store->select(m => m.someField)` is the recommended way to read a projection of the model from a component. It uses Zustand's selector mechanism so the component only re-renders when the selected value actually changes. Selectors can compute derived values such as `store->select(m => m.count + 1)`.

### Slices of state

`Chai.pour` helps you create a sub-hook that returns a `store<'subModel>` and a `dispatch` typed for `subMsg` — this is great for component modules responsible for a slice of the UI. Here's an example:

```rescript
let useApp = Chai.brew({
    update, run, subs, init, middleware  
})

// assuming your model has a sub-record named `dropdown`
// and your msg has a sub-variant named `DropdownMsg()`
let useDropdown = Chai.pour(useApp, {
    filter: model => model.dropdown,
    infuse: msg => DropdownMsg(msg)
})

// any component that uses `useDropdown` can never 
// 1. access state outside of the dropdown
// 2. dispatch messages unrelated to the dropdown
```

### Best practices 

- Develop your core application logic at the top-level, not inside of components.
- Keep `update` pure and free of side effects; represent effects as `cmd` values.
- Keep `run` focused: it should interpret only the `cmd` shape you defined.
- Use `subs` for long-lived event sources (sockets, intervals) and keep their handlers simple.
- Use `store->select` and `Chai.pour` to keep components focused on only the relevant pieces of state they need and minimize re-renders.