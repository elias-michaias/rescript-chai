open Brew

@react.component
let make = (~count=0) => {

    let (model, dispatch) = Chai.useKettle({ 
        update: update, 
        run: run, 
        subs: subs,
        init: init(count),
    })

    let (cupModel, cupDispatch) = Chai.useCup({
        model: model,
        dispatch: dispatch,
        filter: model => model.person,
        infuse: msg => PersonMsg(msg),
    })

    <div>
        <h2 className="text-2xl font-bold mb-4">
            {React.string(model.title)}
        </h2>
        <p className="text-lg mb-4">
            {React.string("Count: " ++ string_of_int(model.count))}
        </p>
        <div className="flex flex-wrap">
            <Button onClick={_ => Increment->dispatch}>
                {React.string("Increment")}
            </Button>
            <Button onClick={_ => SetAfterDelay(1000, 12)->dispatch}>
                {React.string("Set to 12 after 1 second")}
            </Button>
            <Button onClick={_ => SetLogCount(10)->dispatch}>
                {React.string("Set count to 10 and log")}
            </Button>
            <Button onClick={_ => SendWebSocketData(Js.Json.string("Boop"))->dispatch}>
                {React.string("Send WebSocket Message")}
            </Button>
        </div>
        <div className="flex flex-wrap">
            <Button onClick={_ => SaveCount(model.count)->dispatch}>
                {React.string("Save count to storage")}
            </Button>
            <Button onClick={_ => LoadCount->dispatch}>
                {React.string("Load count from storage")}
            </Button>
            <Button onClick={_ => SaveCountIDB(model.count)->dispatch}>
                {React.string("Save count to IndexedDB")}
            </Button>
            <Button onClick={_ => LoadCountIDB->dispatch}>
                {React.string("Load count from IndexedDB")}
            </Button>
        </div>
        <CupTest model=cupModel dispatch=cupDispatch />
    </div>
}