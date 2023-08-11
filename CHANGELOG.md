# tru-sdk-ios

Change Log
==========
## Version 1.0.6
_2023-08-11_
**Bug Fix**
- `createHttpCommand` empty path handling

## Version 1.0.5
_2023-07-19_
**Bug Fix**
- device_info within `convertConnectionResponseToDictionary` and `convertNetworkErrorToDictionary` methods amended

## Version 1.0.4
_2023-07-03_
**Changes**
- Bug fix regarding relative redirects

## Version 1.0.4-preview
_2023-06-26_
**New**
- Convenience method `postWithDataCellular`

## Version 1.0.3
_2023-02-27_
**Changes**
- Target platform macOS removed

## Version 1.0.2
_2023-01-23_
**New**
- New method `openWithDataCellularAndAccessToken`

## Version 1.0.1
_2022-09-29_

**Changes**
- Bug fix related to MNO requiring cookies

## Version 1.0.0
_2022-09-26_

**Changes**
- Readme

## Version 1.0.0-preview1
_2022-09-16_

**Bug Fix**
- Missing debug info in case of error

## Version 1.0.0-preview
_2022-08-08_

**Changes**
- Breaking changes from 0.x.x, see README 

## Version 0.3.4
_2022-05-31_
**New**
- Default connection timeout set to 5s

## Version 0.3.3
_2022-04-22_
**New**
- ObjcTruSDK class for Kotlin MultiPlatform Compatibility

## Version 0.3.2
_2022-04-27_
**Bug Fix**
- Redirect handling

## Version 0.3.1
_2022-03-07_
**New**
- Simulator supports

**Bug Fix**
- `isReachable` error mapping

## Version 0.3.0
_2022-02-11_
**New**
- `checkUrlWithResponseBody` new method

**Changes**
- Method `check` is deprecated.

## Version 0.2.10
_2022-01-11_

**Changes**
- Internal refactoring

## Version 0.2.9
_2021-10-07_

**New**
- isReachable support for custom data residency

**Changes**
- Added device info to userAgent

## Version 0.2.8
_2021-09-27_

**Bug Fix**
- `isReachable` method product mapping
- Better custom port handling
- Accept header for navigation request

## Version 0.2.7
_2021-09-06_

**Bug Fix**
* Forcing data cellular connectivity in `isReachable` method.

## Version 0.2.6
_2021-08-06_

**Changes**
* Lower min iOS version to 12
## Version 0.2.5
_2021-07-14_

**Bug Fix**
 * SDK version number and provide a method to serialise ReachabilityDetails to json string

## Version 0.2.4
_2021-06-25_

**Bug Fix**
   * Decoding Reachability details
   
## Version 0.2.3
_2021-06-22_

**Bug Fix**
   * checkWithTrace(...) public interface
   * on iOS target
   **New**
   * Introducing a new API checkWithTrace(...), performs a check given a Tru.Id URL and provides trace information.
   
## Version 0.2.0
_2021-06-02_

**New**
* Introducing a new API isReachable(...), which provides information as to whether the network call was made over cellular,
   and if so the details about the mobile carrier.
   
## Version 0.1.1
_2021-04-20_

**Changes**
* Requests are made after NWConnection state is ready, is connection can not be made Timeout triggers a cancel.
* New method `check(url: URL, completion: @escaping (Error?) -> Void)` is will handle the new flow. Existing method  `check(url: URL, completion: @escaping (Any?, Error?) -> Void)` will be deprecated.

## Version 0.1.0
_2021-04-15_

**Changes**
* Now min target is iOS13 and macOS 10.14
* Better redirect handling
* Method `openCheckUrl` is now Deprecated and may be removed in future releases. Instead, use `check(url: URL, completion: @escaping (Any?, Error?) -> Void)`
* Method `getJsonResponse` is now Deprecated and may be removed in future releases. Instead, use `jsonResponse(...)`
* Method `getJsonPropertyValue` is now Deprecated and may be removed in future releases. Instead, use `jsonPropertyValue(...)`

## Version 0.0.12
* 303 See Other support

## Previous Versions
* 0.0.11
    * Helper method to fetch a JSON from a GET method over a cellular connection    
* 0.0.10
    * receive instead of receiveMessage
    * Custom User-Agent tru-sdk-ios/{version}
* 0.0.9
    * openCheckUrl completion changed 
* 0.0.8
    * 307 Temporary Redirect support
* 0.0.7
    * Removing Port  
* 0.0.6
    * Logging
* 0.0.5
    * Cleanup
* 0.0.4
    * Naming
* 0.0.3
    * Refactoring       
* 0.0.2
    * RedirectManager openCheckUrl completion support
* 0.0.1
    * Work in progress
