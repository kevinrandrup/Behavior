// MIT License
//
// Copyright (c) 2016 Kevin Randrup
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Swift
import Foundation

/// This is a working implementation of behaviors using the existing protocol system.
/// It very easy to learn and matches what you would expect from the existing Swift standard library.
/// To create a new Behavior all you need to do is implement the Behavior protocol.
protocol Behavior {
    associatedtype Value
    /// InitializationValue can be used to require a different value on initialization.
    /// Ex. a closure which generates a default property or creates a database.
    associatedtype InitializationValue = Value
    
    init(_ initValue: InitializationValue)
    
    mutating func get() -> Value
    mutating func set(_ newValue: Value)
}

/// This extension gives the ability to initialize a behavior when the
/// InitializationValue can be created from nil (Eg. optional values).
/// `var myBehavior: BehaviorName<Type?> = BehaviorName()`
extension Behavior where InitializationValue : ExpressibleByNilLiteral {
    init() {
        self.init(nil)
    }
}

// Once condititional conformances are added to Swift the following will hopefully be possible.
// https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md
// extension Behavior : ExpressibleByNilLiteral where InitializationValue : ExpressibleByNilLiteral {}


/// The Lazy Behavior has an initial value that it falls back onto.
/// Lazy properties can be cleared to restore the initial value
struct Lazy<LazyValue> : Behavior {
    
    typealias Value = LazyValue
    
    var value: Value?
    let initialValue: Value
    
    init(_ initValue: Value) {
        initialValue = initValue
    }
    
    mutating func get() -> Value {
        if let value = value {
            return value
        }
        value = initialValue
        return initialValue
    }
    
    mutating func set(_ newValue: Value) {
        value = newValue
    }
    
    /// Lazy is just a struct so we can of course add our own methods.
    mutating func clear() {
        value = initialValue
    }
}
var lazyInt = Lazy(5)
lazyInt.get() // 5
lazyInt.set(2)
lazyInt.get() // 2
lazyInt.clear()
lazyInt.get() // 5


/// DelayedImmutable properties can only be set once but they aren't required to be set during initialization.
/// If behaviors get built into the compiler, this behavior could be added to IBOutlets to avoid using ImplicitlyUnwrappedOptional
struct DelayedImmutable<DelayedValue> : Behavior {
    typealias Value = DelayedValue
    // Provide an InitializationValue to allow DelayedImmutable to be initialized with an Optional.
    typealias InitializationValue = Value?
    
    var value: Value?
    
    init(_ initValue: InitializationValue) {
        value = initValue
    }
    
    func get() -> Value {
        guard let value = value else {
            fatalError("property accessed before being initialized")
        }
        return value
    }
    
    mutating func set(_ newValue: Value) {
        if value != nil {
            fatalError("property initialized twice")
        }
        value = newValue
    }
}

//Can initialize with nothing
var delayedImmutable: DelayedImmutable<Int> = DelayedImmutable()
//delayedImmutable.get() //Fatal error
delayedImmutable.set(1)
//delayedImmutable.set(2) //Also fatal error


/// Observer Behavior can notify others before or after a value is set
struct Observer<ObservedValue> : Behavior {
    typealias Value = ObservedValue
    
    var value: Value
    
    init(_ initValue: Value) {
        value = initValue
    }
    
    var willSet: ((_ newValue: Value) -> Void)?
    var didSet: ((_ newValue: Value) -> Void)?
    
    func get() -> Value {
        return value
    }
    
    mutating func set(_ newValue: Value) {
        willSet?(newValue)
        value = newValue
        didSet?(newValue)
    }
}


var observedInt = Observer(5)
/// This closure is stored in the Observer Behavior.
/// If Observer is a class then the closure would need to
/// capture observedInt as [unowned observedInt] to avoid the retain cycle.
observedInt.willSet = { (newValue) -> Void in
    let previous = observedInt.get()
    print("Previous Value: \(previous)\nNew Value: \(newValue)")
}
observedInt.set(2)  //Previous: 5, New: 2
observedInt.set(3) // Previous: 2, New: 3


/// Showcasing the Behavior initializer the behavior type is an Optional
var observedOptionalInt: Observer<Int?> = Observer()


/// Copying Behavior implements defensive copying.
/// This behavior implmented the `copy` attribute from Objective-C
struct Copying<CopyableValue : NSCopying> : Behavior {
    typealias Value = CopyableValue
    
    var value: Value
    
    init(_ initValue: Value) {
        value = initValue.copy() as! Value
    }
    
    func get() -> Value {
        return value
    }
    
    mutating func set(_ newValue: Value) {
        value = newValue.copy() as! Value
    }
}

let oldArray: NSArray = NSMutableArray(arrayLiteral: 1, 2)
var array = Copying(oldArray)
(oldArray as! NSMutableArray).add(3)
print("Old array - [\(oldArray.componentsJoined(by: ", "))]")       // [1, 2, 3]
print("New array - [\(array.get().componentsJoined(by: ", "))]")     // [1, 2]
