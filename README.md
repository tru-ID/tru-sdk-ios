# tru-sdk-ios

iOS SDK for tru.ID: Blazingly fast phone verification. Exposes APIs for instant, invisible strong authentication.

[![Swift Version][swift-image]][swift-url]
[![License][license-image]][license-url]


## Installation

Add this project on your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://gitlab.com/tru-id/tru-sdk-ios.git", majorVersion: 0, minor: 0)
    ]
)
```

## Usage example


```swift
import TruSDK

let tru: TruSDK = TruSDK()

tru.check(url: url) { error in 
...
}

tru.checkWithTrace(url: url) { error, trace in
...
}

tru.isReachable { result in
...
}
```


## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/tru-ID](https://github.com/tru-ID)

[swift-image]:https://img.shields.io/badge/swift-5.0-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
