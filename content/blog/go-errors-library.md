+++
title = "Success with errors in Go: stack traces and metadata"
date = 2024-11-20
[taxonomies]
tags = ["go", "programming"]
+++

# Introduction: Problems and patterns with Go errors

There are several patterns for dealing with errors I encounter almost universally on Go projects:

* stack traces
* adding metadata to existing errors
* multiple errors
* error classification
* error reporting

The first two can be handled with the help of a light-weight error library. There are a lot of error libraries available that do mostly the same things.
I maintain [github.com/gregwebs/errors](https://github.com/gregwebs/errors).


# Stack traces

A Panic in Go produces a stack trace, but an error does not.

Adding a stack trace to your go code happens automatically with an error library that supports stack traces. If you use error creation functions:

```go
errors.New("message")
errors.Errorf("%s", message) // same as fmt.Errorf
```

These will create an error with a stack trace.
Wrapping functions (see next sections) will automatically add a stack trace as well.

I am told errors don't have traces because that this would have a negative performance impact.
However, in almost all of my usage of Go, when an error is returned performance is no longer a concern.
Sometimes when errors can alter performance that indicates an error is being returned for what is a normal condition rather than an error condition.
An example of this is read APIs returning EOF.
Certainly there are some cases where performance needs to be optimized on an error path. It's worth noting that the Zig language has figured out how to further [minimize the impact of collecting error traces](https://ziglang.org/documentation/master/#Error-Return-Traces) and allows them to be turned off in release builds.
Below we also see an example where a stack trace would not be helpful.
In these cases, one can still use standard APIs that don't add stack traces:

```go
import stderrors "errors"
var sentinelErr = stderrors.New("sentinel")
```

Additionally, the [github.com/gregwebs/errors](https://github.com/gregwebs/errors) library provides a 'WrapNoStack' function that can be used to wrap an error without adding a stack trace.

From the [github.com/gregwebs/errors](https://github.com/gregwebs/errors) library I separated out a tiny library for creating and formatting stack traces: [github.com/gregwebs/stackfmt](https://github.com/gregwebs/stackfmt) that can be used independently of the errors library.

## Adding metadata

The standard way of adding metadata to Go errors is to wrap them in format strings:

```go
fmt.Errorf("message: %w", err)
```

I think that adding a new formatting verb for errors was a pragmatic choice to avoid dependency issues and match what users were currently doing, but I think the API is cryptic and limited compared to the library approach of:

```go
errors.Wrap(err, "message")
```

There is also a `Wrapf` function for using formatting strings. However, as I have shifted towards structured logging I want all my metadata structured, including for errors.
The errors library features an slog compatible API for adding metadata called `Wraps` where "s" stands for "structured".

```go
errors.Wraps(err, "message", slog.Int("id", 5)) // with slog typing
errors.Wraps(err, "message", "id", 5) // without slog typing
```

A common pattern supported by the library is to accumulate attributes that can be used both with slog and for annotating errors:

```go
attrs := []slog.Attr{slog.Int("id", 5), slog.String("key", "value")}
errors.Wraps(err, "message", attrs)
```

A structured error can be converted into an slog record with `GetSlogRecord()`.
From the [github.com/gregwebs/errors](https://github.com/gregwebs/errors) library I have separated out structured wrapping functionality as a seprate package [github.com/gregwebs/slogerr](https://github.com/gregwebs/slogerr) for those just interested in structured errors.


## Conclusion

With a stack trace and relevant metadata annotating an error, I can frequently open up a bug report just from seeing the error report without having to dig into logs. When I do need to dig into the logs, having metadata on the error helps greatly with tracking things down. If you have a request id/trace id you can attach that to the error to help find it in the logs.

Future maintainers of your code base will thank you when they can quickly track down errors.

Future posts will discuss approaches to:

* [multiple errors](@/blog/go-multiple-errors.md)
* [error classification](@/blog/go-error-codes.md)
* error reporting