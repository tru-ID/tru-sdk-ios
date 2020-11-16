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
tru.openCheckUrl(url: url, completion: completion)
```

## Release History

* 0.0.1
    * Work in progress
* 0.0.2
    * RedirectManager openCheckUrl completion support
* 0.0.3
    * Refactoring     
* 0.0.4
    * Naming   
* 0.0.5
    * Cleanup 
* 0.0.6
    * Logging  

## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/tru-ID](https://github.com/tru-ID)

[swift-image]:https://img.shields.io/badge/swift-5.0-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
