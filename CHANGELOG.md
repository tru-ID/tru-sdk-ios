# tru-sdk-ios

Change Log
==========

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
