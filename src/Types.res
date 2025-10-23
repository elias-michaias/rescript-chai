module type Kettle = {
    type model
    type msg
    type cmd
    let update: (model, msg) => (model, cmd)
    let run: (cmd, msg => unit) => promise<unit>
    let subs: model => array<Sub.subscription<msg>>
}