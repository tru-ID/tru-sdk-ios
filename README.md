# tru-sdk-ios

iOS SDK for tru.ID: Blazingly fast phone verification. Exposes APIs for instant, invisible strong authentication.

[![Swift Version][swift-image]][swift-url]
[![License][license-image]][license-url]


## Installation

Using Package Dependencies 

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/tru-ID/tru-sdk-ios.git, majorVersion: 0, minor: 0)
    ]
)
```
Using cocoapods 

```
  pod 'tru-sdk-ios', '~> x.y.z'

```

## Compatibility

```
Minimum iOS: TruSDK is compatible with iOS 12+
```

## Usage example


```swift
import TruSDK

let tru: TruSDK = TruSDK()

//check if device is eligible
tru.isReachable { result in
...           
}

//create a PhoneCheck with your backend 
//in order to get a checkURL
...

//trigger the check URL from the device
tru.checkUrlWithResponseBody(url: url) { error, body in 
...
}

tru.checkWithTrace(url: url) { error, trace in
...
}

//retrieve PhoneCheck result from backend

```


## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/tru-ID](https://github.com/tru-ID)

[swift-image]:https://img.shields.io/badge/swift-5.0-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
