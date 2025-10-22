<div style="text-align: center; margin-bottom: 2rem;" align="center">
  <img src="./logo.png" alt="Chai Logo" style="width: 200px; height: auto;" />
</div>

<h1 style="text-align: center;" align="center"><code>rescript-chai</code></h1>
<p style="text-align: center;" align="center">The Elm Architecture - in ReScript - on React</p>

<div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; justify-content: center; margin-bottom: 4em;" align="center">

  [![npm version](https://img.shields.io/npm/v/rescript-chai)](https://www.npmjs.com/package/rescript-chai)
  [![GitHub top language](https://img.shields.io/github/languages/top/elias-michaias/rescript-chai)](https://github.com/elias-michaias/rescript-chai)
  [![GitHub last commit](https://img.shields.io/github/last-commit/elias-michaias/rescript-chai)](https://github.com/elias-michaias/rescript-chai)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
</div>
<br/>

>[!WARNING]
>Chai is an experimental project and is currently in early development. Most APIs are incomplete, unstable, and subject to change. Do not use Chai in production.
<br/>
<h2>What is Chai? 🍵</h2>
<a href="https://github.com/elias-michaias/rescript-chai">Chai</a> is an implementation of <a href="https://guide.elm-lang.org/architecture/">The Elm Architecture</a> (TEA) in <a href="https://rescript-lang.org/">ReScript</a> - built on <a href="https://react.dev/">React</a>. Chai wants to make the React ecosystem accessible to the Model-View-Update paradigm, without sacrificing on the comforts you're used to. Model your state, clearly define all state transformations, and represent side effects as data structures.
<br/>
<br/>

```rescript
// Define your model - the state of your component
type model = { count: int }

// Define your messages - events that can change state
type msg = Increment | Decrement | Set(int)

// Define your commands - effects that interact with the world
type cmd = NoOp | Log(Cmd.Log.t)

// The update function - pure, handles all state changes
let update = (model, msg) => switch msg {
  | Increment => ({ count: model.count + 1 }, NoOp)
  | Decrement => ({ count: model.count - 1 }, NoOp)
  | Set(n) => ({ count: n }, Log("Set count to" ++ string_of_int(n)))
}

// Handle your side effects (HTTP, storage, timers, etc.)
let run = async (cmd, dispatch) => switch cmd {
  | NoOp => ()
  | Log(c) => await c->Cmd.Log.run
}

// Subscriptions for external events (WebSocket, timers, etc.)
let subs = (_model) => [
    Sub.Time.every(1000, _ => Decrement)
]

// Describe the initial state and effects
let init = (count) => ({
    count: count
}, Log("Counter initialized"))

// In your React component - use Chai's useKettle hook
@react.component
let make = (~count=12) => {
  let (model, dispatch) = Chai.useKettle({
    update: update,
    run: run,
    subs: subs,
    init: init(count),
  })

  <div>
    <p>{React.string("Count: " ++ string_of_int(model.count))}</p>
    <button onClick={_ => Increment->dispatch}>
      {React.string("Increment")}
    </button>
  </div>
}
```

<h2>Installation</h2>

```bash
npm install rescript-chai
```

<h2>Reference</h2>

<h3>
<a href="https://github.com/elias-michaias/rescript-chai/blob/main/reference/philosophy.md">
    Philosophy →
</a>
</h3>

<h3>
<a href="https://github.com/elias-michaias/rescript-chai/blob/main/reference/structure.md">
    Structure →
</a>
</h3>

<h3>
<a href="https://github.com/elias-michaias/rescript-chai/tree/main/examples/counter">
    Examples →
</a>
</h3>

<h3>
<a href="https://github.com/elias-michaias/rescript-chai/blob/main/LICENSE">
    License →
</a>
</h3>