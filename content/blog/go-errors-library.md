+++
title = "Success with errors in Go"
date = 2024-11-20
+++

# Introduction: Problems and patterns with Go errors

There are several patterns for dealing with errors I encounter almost universally on Go projects:

* stack traces
* adding metadata (wrapping)
* multiple errors
* error classification
* error reporting

The first three can be handled with the help of a light-weight error library. There are a lot of libraries out there.
I maintain [github.com/gregwebs/errors](https://github.com/gregwebs/errors) which is based off a fork of one of the original libraries.


# Stack traces

A Panic in Go produces a stack trace, but an error does not.

Adding a stack trace to your go code happens automatically with an error library. If you use error creation functions:

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
Certainly there are some cases where performance needs to be optimized on an error path.
And below we see an example where a stack trace would not be helpful.
In these cases, one can still use standard APIs that don't add stack traces.

```go
import stderrors "errors"
var sentinelErr = stderrors.New("sentinel")
```

## Adding metadata

The standard way of adding metadata to Go errors is to wrap them in format strings:

```go
fmt.Errorf("context: %w", err)
```

I understand why it was pragmatic to add a new formatting verb for errors, but I think the API is cryptic and limited compared to the library approach of:

```go
errors.Wrap(err, "context")
```

There is also a `Wrapf` function for using formatting strings. However, as I have shifted towards structured logging I want all my metadata structured, including for errors.
The errors library features an slog compatible API for adding metadata called `Wraps` where "s" stands for "structured".

```go
errors.Wraps(err, "context", "id", 5)
```

A common pattern supported by the library is to accumulate attributes that can be used both with slog and for annotating errors:

```go
attrs := []slog.Attr{slog.Int("id", 5), slog.String("key", "value")}
errors.Wraps(err, "context", attrs)
```

A structured error can be converted into an slog record with `GetSlogRecord()`.


## Multiple errors

Combining multiple errors with `errors.Join` is convenient since standard Go idioms expect a single `error`.
If the caller just needs to know whether there was a single error and doesn't need to deal with the individual errors, then this is a good approach.
However, if a caller needs to use or inspect individual errors this violates a principle of programming that I have long used- data should be maintained in a structured form rather than de-structured and then queried for that structure.
When there is a de-structured multi-error, querying for an error becomes a tree traversal rather than a simple unwrapping.
The approach that I take is to maintain the structure. This can be done either by returning `[]error` or by returning a structured error struct rather than just an `error`.


```go
type Dog struct {
    Name string
    Owner string
}

func (d Dog) Validate() []error {
    errs := []error{}
    if d.Name == "" {
        errs = append(errs, errors.New("name is required"))
    }
    if d.Owner == "" {
        errs = append(errs, errors.New("owner is required"))
    }
    return errs
}

func (d Dog) ValidateUnstructured() error {
    return errors.Join(d.Validate()...)
}

func main() {
    d := Dog{}
    if errs := d.Validate(); len(errs) > 0 {
        for _, err := range errs { fmt.Println(err) }
    }

    if err := d.ValidateUnstructured(); err != nil {
        fmt.Println("hmm, remind me how to get my individual validation errors back from this?")
    }
}
```

In the slice approach, the caller can handle each individual error without having to first re-structure the multiple errors. An error library is not required for this approach.

You might be tempted to wrap up the slice into a struct with an error interface and return that struct as a pointer. This would allow a caller to use the error slice directly and still be able to satisfy `error`:

```go
type MultiErr []error

func (me MultiErr) Error() string {
	return stderrors.Join(me...).Error()
}

func (d Dog) ValidateStructured() *errors.MultiErr {
    if errs := d.Validate(); len(errs) > 0 {
        return &MultiErr(errs))
    }
    return nil
}
```

Unfortunately with this approach you will eventually come across an issue [with Go interfaces](https://go.dev/doc/faq#nil_error) where you will have an error with a nil value, but `err == nil` will still return false.
A function `errors.IsNil` is provided to help distinguish this case, but it is difficult to avoid this issue.


## Conclusion


With a stack trace and relevant metadata annotating an error, I can frequently open up a bug report just from seeing the error report without having to dig into logs.
Future maintainers of your code base will thank you when they can quickly track down errors.

Think carefully about how you handle multi errors and let me know what approaches work for you.

A discussion of error classification and reporting will wait for a future post.
