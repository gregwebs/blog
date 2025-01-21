+++
title = "Classifying errors with error codes in Go"
date = 2025-01-20
[taxonomies]
tags = ["go", "programming"]
+++


## The neeed for Error Classification

Good error classification is important for error handling. It allows you to handle errors in a way that is specific to the error type. For example, you might want to retry a transient error, but not a permanent error.

This occurs both within a single code base and across network boundaries.
In a single code base, in the database layer we might return an error indicating data was not found or an error indicating an internal failiure, possibly a transient database error. In the application layer we will want to translate that to the apropriate HTTP (or GRPC, etc) code.

The client should alter its behavior based on the HTTP code. In some cases, the HTTP Code may not be enough. We might give an HTTP code of 400, but there might be multiple different reasons for a 400 and different apropriate behaviors for the client- we may want to send an application specific error code to the client. The code can represent an error type corresponding to specific error fields, and thus also allows the client to intelligently understand the response.

Returning an ErrorCode helps modularize code- a function that is not written in the context of an (HTTP) handler can encode an HTTP code.
Code can also be made neutral to the transport- a code can correspond to both an HTTP code and also to a GRPC code, etc.

## Desiging an Error Code package

This need has been met with many different error code packages.
I will review the design and unique benefits of the package that I maintain: [github.com/gregwebs/errcode](https://github.com/gregwebs/errcode).

### Strings rather than numeric

Traditionally error codes have been numeric. This helps with efficiency. However, numeric codes are not human readable in a meaninful way. This requires maintaining a mapping between numeric codes and human readable strings and performing that lookup. It's simpler to just use strings.

Hierarchy of codes is supported by using a dot notation as seen below.
Note that the codes and defined in a Golang DSL:

```go
var (
	InternalCode = NewCode("internal").SetHTTP(http.StatusInternalServerError)
	UnimplementedCode = InternalCode.Child("internal.unimplemented").SetHTTP(http.StatusNotImplemented)
	UnavailableCode = InternalCode.Child("internal.unavailable").SetHTTP(http.StatusServiceUnavailable)
)
```

### Metadata

In the prior example, the HTTP code is set as metadata on the error code.
SetHTTP is available as a pre-defined method on `Code` shown below, but it is possible to define any kind of metadata (using functions).

```go
func (code Code) SetHTTP(httpCode int) Code {
	if err := code.SetMetaData(httpMetaData, httpCode); err != nil {
		panic(errors.Wrap(err, "SetHTTP"))
	}
	return code
}
```

When defining codes hierarchically, metadata is inherited from the parent code but can be over-written.

### Error Code structure

Other Go implementations of error classification that I have seen use a single struct.  The approach I have taken is to use wrapping and interfaces- it can be used to provide great extensibility and also to provide guarantees about what data is available to a client.


### Error Code Interface

This package extends go errors via interfaces to have error codes.

```go
type ErrorCode interface {
	error
	Code() Code
}
```

There are existing generic error codes and constructors for them such as `NewNotFoundErr`.

The package also provides `UserCode` designed to provide a user-facing message for end users rather than technical error messages.


```go
type UserCode interface {
	ErrorCode
	HasUserMsg
}

type HasUserMsg interface {
	GetUserMsg() string
}
```

A `UserCode` can be created with `errcode.WithUserMsg` or `errcode.UserMsg`.

### Modularization

Golang HTTP handler code does not compose- it is based on side effects.
This if fine as long as you make the handler as small as possible.
As the handler grows, things can easily go awry.
Confusion about where HTTP responses should be generated can result in a double response or no response.
The code is more difficult to understand and test.

Lets see some example code:

```go
type ErrorResp struct {
	Error string
}

func (h *Handler) updateTag(c *gin.Context) {
    var reqTag tagFetch

    // Call BindJSON to bind the received JSON to
    // newTag.
    if err := c.BindJSON(&reqTag); err != nil {
        return // BindJSON already returns a 400
    }

	if err := reqTag.Validate(); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResp{Error: err.Error()})
		return
	}

	tag, err := app.DB.GetTag(reqTag.Name)
	if err != nil {
		if database.IsNotFound(err) {
			c.JSON(http.StatusNotFound, ErrorResp{Error: err.Error()})
		} else {
			tag, err := app.DB.UpdateTag(reqTag)
			if err != nil {
				c.JSON(http.StatusBadRequest, ErrorResp{Error: err.Error()})
			}
		}
		return
	}

    c.IndentedJSON(http.StatusCreated, tag)
}
```

We can see that returning from the handler is interleaved everywhere and creating some complications. Lets transition the db portion to using error codes.

```go
func (d *Database) UpdateTag(reqTag Tag) errcode.ErrorCode {
	tag, err := d.GetTag(reqTag.Name)
	if err != nil {
		if database.IsNotFound(err) {
			return errcode.NewNotFoundErr(err)
		} else {
			tag, err := app.DB.UpdateTag(reqTag)
			if err != nil {
				return errcode.NewBadRequestErr(err)
			}
		}
	}
	return nil
}
```

Now we have successfully abstracted out our DB code!
the handler code can transition to:

```go
func (h *Handler) updateTag(c *gin.Context) {
	// ...
			tag, errCode := app.DB.UpdateTag(reqTag)
			if errCode != nil {
				c.JSON(errcode.HTTPCode(errCode), ErrorResp{Error: err.Error()})
			}
	// ...
```

Depending on our use case, we might want to embed a user message with the codes that are returned.

```go
func (d *Database) UpdateTag(reqTag Tag) (Tag, errcode.UserCode) {
	tag, errGet := d.GetTag(reqTag.Name)
	if errGet != nil {
		if database.IsNotFound(errGet) {
			return errcode.WithUserMsg("tag not found", errcode.NewNotFoundErr(errGet))
		} else {
			var errUpdate error
			tag, errUpdate = d.updateTag(reqTag)
			if errUpdate != nil {
				return errcode.WithUserMsg("invalid tag", errcode.NewBadRequestErr(errUpdate))
			}
		}
	}
	return tag, nil
}
```

And now our handler can send both the HTTP code and message back to the client:

```go
func (h *Handler) updateTag(c *gin.Context) {
	// ...
			tag, errCode := app.DB.UpdateTag(reqTag)
			if errCode != nil {
				c.JSON(errcode.HTTPCode(errCode), ErrorResp{Error: err.GetUserMsg()})
			}
	// ...
```

Using the type `errcode.UserCode` as the return type ensures that if there is an error it will have all the information we need for the client.


## Conclusion

Error classificatgion is important to get right.
There are a lot of Go libraries and homegrown systems that do this.
We overview basic usage of a package [github.com/gregwebs/errcode](https://github.com/gregwebs/errcode) to show it's convenience for abstracting code and providing guarantees about client responses.
It's also possible to create custom error codes, send back error responses, and otherwise adapt it to more advanced needs.


This is part of a series on Golang errors.

* [stack traces and metadata](@/blog/go-errors-library.md)
* [multiple errors](@/blog/go-multiple-errors.md)