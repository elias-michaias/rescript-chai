# `rescript-chai`

## Philosophy

Chai wants to give developers the ability to utilize all of the application hygiene that The Elm Architecture provides for building user interfaces: pure functions handling updates, centralized state transformations, and declarative side-effects represented as data structures. This approach eliminates many common sources of bugs and makes applications easier to reason about and test. On the other hand, React has a vast ecosystem of incredibly high-quality component libraries and specialized SDKs.

Chai seeks to bridge this gap by solving two issues:
1. Building the MVU loop's reactivity around React as a base.
2. Allowing the core MVU loop to seamlessly embed React components. 

The `useKettle` hook provides the MVU loop and state transformation mechanism, while `useCup` enables the Kettle to "pour" out segregated portions of its model and message-passing, similar to the traditional `lens` in Elm. Since React remains under the hood, developers retain the flexibility to use traditional React patterns when needed.

ReScript seems to be an excellent host language for this approach. The combination of first-class React support, JSX as a language-level syntax, and a strong preference for immutability and pattern matching, leads to an ideal environment for concocting such an experiment. 

Furthermore, ReScript provides a unique angle to facilitate adoption compared to some compile-to-JS languages because of its very tight integration into the JS ecosystem. Building TEA on top of something as ubiquitous React should hopefully help to facilitate adoption, compared to a "raw" implementation of TEA. Other packages exist in the ReScript world to implement TEA from scratch - these packages are wonderful, and may be a much better solution for you - but that vision is not what Chai seeks to fulfill. If you are interested in a "from scratch" implementation of TEA in ReScript without additional mental and runtime overhead from React, please check out [darklang/rescript-tea](https://github.com/darklang/rescript-tea). 