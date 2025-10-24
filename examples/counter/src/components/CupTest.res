open Brew

@react.component
let make = () => {
    let (store, dispatch) = usePerson()

    Console.log("CupTest rendered --")

    let name = Chai.select(store, m => m.name)
    let age = Chai.select(store, m => m.age)

    <div>
        <h3 className="text-xl font-bold mb-4">
            {React.string("Cup Test Component")}
        </h3>
        <p className="text-lg">
            {React.string("Person Name: " ++ name)}
        </p>
        <p className="text-lg mb-4">
            {React.string("Person Age: " ++ string_of_int(age))}
        </p>
        <div className="flex flex-wrap">
            <Button onClick={_ => UpdateName("Alex")->dispatch}>
                {React.string("Set Name to Alex")}
            </Button>
            <Button onClick={_ => UpdateAge(20)->dispatch}>
                {React.string("Set Age to 20")}
            </Button>
        </div>
    </div>
}