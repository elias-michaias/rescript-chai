# `rescript-chai`

## Structure

Chai does not srictly enforce any particular module pattern, but the below application structure is the vision that Chai has in mind for optimally reducing tension between The Elm Architecture and React's Component Model:

```
src/
-> Brew.res
-> Kettle.res
-> components/
    -> Cup.res 
    -> ...
```

>[!WARNING]
>Leaving the core logic for the main MVU loop outside of the top-level component is necessary. When you instantiate a child component from a Kettle, that Kettle will need to reference types from the main MVU loop. If it is in the same file as the Kettle, the ReScript compiler will fail due to a dependency cycle.


### Brew
The `Brew` is the home of the MVU loop's core logic. Here lies the traditional TEA staples:
`model`, `msg`, `cmd`, `subs`, etc. A Brew can have multiple peer Brews, such as for handling multiple routes, but one Brew should never be dependent upon another.

### Kettle
The `Kettle` is the "mother component" at the top-level (or second to a minimal "App" root component). It can have peer Kettles, such as for handling multiple routes, but a Kettle is never a child of another Kettle. The Kettle is responsible for reifying the Brew core logic, for rendering the top-level view, as well as instantiating all child components. 

### Cup
The `Cup` is a "sub-component" for all intents and purposes. A Cup only receives a segregated portion of the model and message-passing from its parent Kettle. This eliminates errors in which a Cup rendering a sidebar could accidentally alter the state for a navbar. If you were going to import a React component library that exposes all intra-component state as props, such as `shadcn/ui` or `mui`, all of these components would be Cups.