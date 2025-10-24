open Brew
open Chai

@react.component
let make = (~initCount=0) => {

    let (store, dispatch) = useCounter()

    let title = store->select(m => m.title)
    let count = store->select(m => m.count)

    Console.log("-- Counter rendered")

    <div>
        <h2 className="text-2xl font-bold mb-4">
            {React.string(title)}
        </h2>
        <p className="text-lg mb-4">
            {React.string("Count: " ++ Int.toString(count))}
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
            <Button onClick={_ => SaveCount(count)->dispatch}>
                {React.string("Save count to storage")}
            </Button>
            <Button onClick={_ => LoadCount->dispatch}>
                {React.string("Load count from storage")}
            </Button>
            <Button onClick={_ => SaveCountIDB(count)->dispatch}>
                {React.string("Save count to IndexedDB")}
            </Button>
            <Button onClick={_ => LoadCountIDB->dispatch}>
                {React.string("Load count from IndexedDB")}
            </Button>
        </div>
        <CupTest />
    </div>
}