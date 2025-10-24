# `rescript-chai`

## Philosophy

Chai wants to give developers the ability to utilize all of the application hygiene that The Elm Architecture (TEA) provides for building user interfaces: pure functions handling updates, centralized state transformations, and declarative side-effects represented as data structures. This approach eliminates many common sources of bugs and makes applications easier to reason about and test. On the other hand, React has a vast ecosystem of incredibly high-quality component libraries and specialized SDKs.

Chai seeks to bridge this gap by solving two issues:
1. Building the MVU loop's reactivity around React as a base.
2. Allowing the core MVU loop to seamlessly embed React components. 

Chai is built on [zustand 🐻](https://github.com/pmndrs/zustand) which means its internal state management mechanism lies outside of any component and exists at the app-level. This is key to synergizing TEA with React's Component Model, because it eliminates prop-drilling and complex parent/child relationships with dependency cycles or convoluted stateful props. Chai's `Chai.brew()` function produces idempotent hooks that can be called from any React component to access the core MVU-loop without re-running effects or messing with fine-grained reactivity. You can further scope down your hooks by passing them to `Chai.pour()` which can isolate specific pieces of the `model` and `msg` respectively to produce a narrowed-down idempotent hook:

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

ReScript is to be an excellent host language for this approach. The combination of first-class React support, JSX as a language-level syntax, and a strong preference for immutability and pattern matching, is ideal.  ReScript provides a unique angle to facilitate adoption compared to some compile-to-JS languages because of its very tight integration into the JS ecosystem. Building TEA on top of something as ubiquitous as React should hopefully facilitate adoption compared to a raw implementation of TEA. Other packages exist in the ReScript world to implement TEA from scratch - these packages are wonderful, and may be a much better solution for you - but that vision is not what Chai seeks to fulfill. If you are interested in a "from scratch" implementation of TEA in ReScript without the additional mental and runtime overhead from React, please check out [darklang/rescript-tea](https://github.com/darklang/rescript-tea) and give the developers there some love. 

When it comes to ReScript's spirit of integration with the JS-world, Chai follows suit. Chai wants to make the React ecosystem accessible in every way, from the component libraries to the developer experience. You can seamlessly bind and import your favorite components, or load up the [Redux DevRools](https://github.com/reduxjs/redux-devtools).