# TruSDK

iOS SDK for tru.ID: Blazingly fast phone verification. Exposes APIs for instant, invisible strong authentication.

[![Swift Version][swift-image]][swift-url]
[![License][license-image]][license-url]


![](head.png)

## Installation

Add this project on your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://gitlab.com/4auth/devx/tru-sdk-ios.git", majorVersion: 0, minor: 0)
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
    * Naming       

## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/yourname/github-link](https://github.com/dbader/)

[swift-image]:https://img.shields.io/badge/swift-5.0-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
