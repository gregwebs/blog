+++
title = "Success with errors in Go: handling multiple errors"
date = 2024-11-21
+++


## Multiple errors

When one function has multiple distinct errors to return, we now have multiple errors.
This often happens due to:
* concurrent processing (Go routines)
* accumulating errors instead of returning after the first error (validations)

## Dealing with Multiple errors

A common approach to dealing with multiple errors is to smush them into a single error.
Combining multiple errors with `errors.Join` is convenient since standard Go idioms expect a single `error`.

If the caller just needs to know whether there was a single error and doesn't need to deal with the individual errors, then this is a good approach.
However, if a caller needs to use or inspect individual errors this violates a principle of programming that I have long used- data in a program should be maintained in a structured form rather than de-structured and then later queried while attempting to recover that structure.
When there is a de-structured multi-error, querying for a particular error becomes a tree traversal rather than a simple linear unwrapping.
The approach that I take in these cases is to maintain the structure. This can be done by returning `[]error`.


```go
type Dog struct {
    Name string
    Owner string
}

type NameRequiredErr = errors.New("name is required")
type OwnerRequiredErr = errors.New("owner is required")

func (d Dog) Validate() []error {
    errs := []error{}
    if d.Name == "" {
        errs = append(errs, NameRequiredErr)
    }
    if d.Owner == "" {
        errs = append(errs, OwnerRequiredErr)
    }
    return errs
}

func (d Dog) ValidateUnstructured() error {
    return errors.Join(d.Validate()...)
}

func main() {
    d := Dog{}
    if errs := d.Validate(); len(errs) > 0 {
        for _, err := range errs { 
            // Each error can easily be handled separately if desired
            fmt.Println(err)
        }
    }

    if err := d.ValidateUnstructured(); err != nil {
        fmt.Println("how do I get my individual validation errors back now?")
    }
}
```

In the slice approach, the caller can handle each individual error without having to first re-structure the multiple errors. An error library is not required for this approach.

You might be tempted to wrap up the slice into a struct with an error interface and return that struct as a pointer. This would allow a caller to use the error slice directly and it would still be able to satisfy `error`:

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
A function `errors.IsNil` is provided by my errors libraray to help distinguish this case, but it is difficult to avoid this issue if the error gets passed around in any way.

## Conclusion

In my usage so far I am finding the slice of errors approach useful and easy to adapt to.
This is a newer approach for me- perhaps I will change my approach in the future.
I still default to error smushing if I don't think I need to examine individual errors since it is faster to just smush.

Think carefully about how you handle multi errors and let me know what approaches work for you.
