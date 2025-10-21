type model = {
    title: string,
    expanded: bool
}

type msg =
    | Toggle
    | Update(string)

let update = (model, msg) => switch msg {
    | Toggle => { ...model, expanded: !model.expanded }
    | Update(title) => { ...model, title: title }
}

@react.component
let make = (~title="Default Title", ~expanded=false, ~children=React.null) => {

    let (model, dispatch) = React.useReducer(update, {
        title: title,
        expanded: expanded,
    })

    <div 
        className="rescript-card" onClick={_ => Toggle->dispatch} 
        style={ReactDOM.Style.make(~cursor="pointer", ())}
    >
        <h2>{React.string(title)}</h2>
        {model.expanded ? children : React.null}
        <p style={ReactDOM.Style.make(~fontSize="0.8em", ~color="#666", ())}>
            {React.string(model.expanded ? "Click to collapse" : "Click to expand")}
        </p>
    </div>
}

let default = make