@react.component
let make = () => {
    <div>
        <h1>{React.string("Nested Component")}</h1>
        <Counter.make count=20 />
    </div>
}

let default = make