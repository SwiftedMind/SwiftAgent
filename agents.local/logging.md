#  SwiftAgent Logging

## General

- Uses OSLog and the Logger type

## API

### Enable/Disable logging

- By default, logging is turned off (by initially setting the logger to `OSLog.disabled`)
- It can be turned on like this:

  ```swift
  SwiftAgent.setLoggingEnabled(true) // or false
  ```

## Accessing Logger (internal to the SDK)

- Accessing the logger happens through `SwiftAgent`

  ```swift
  Logger.main // Logger instance.
  ```
- The logger is available to the SDK, but not to the outside
