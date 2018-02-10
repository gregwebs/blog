---
title: Haskell: Encapsulating unsafe IORefs
date: "2018-01-17T22:12:03.284Z"
---

In Haskell variables are constant in reference and value by default.
An IORef is a mutable variable: a normal variable in another language.
However, it has the benefit of having a thread-safe API and its effects are tracked in IO.

Initializing the variable in a main function and then passing it through the program can be a chore.
We can avoid that overhead with a pattern of using `unsafePerformIO` with `newIORef` to initialize the va
riable at the top-level of the program.

~~~haskell
data Expensive = Expensive

--- Cache existing Expensive so we don't keep doing expensive steps to review them
cachedExpensives :: IORef [Expensive]
cachedExpensives = unsafePerformIO (newIORef [])
{-# NOINLINE cachedExpensives #-}
~~~

But the code is scary on several counts:

* we could forget the NOINLINE pragma
* we haven't encapsulated the `IORef` to remove the possibility of unsafe access

Note that there are [packages](https://hackage.haskell.org/package/global-variables)
that help avoid the need for the `NOINLINE` pragma.

Unsafe access for example could come from using the `modifyIORef` function.
Generally it is better to pretend that that does not exist and to use the thread-safe `atomicModifyIORef'
` function.

An initial attempt at encapsulating will start like this:

``` haskell
cachedExpensives :: IORef [Expensive]
cachedExpensives = unsafePerformIO (newIORef [])
{-# NOINLINE cachedExpensives #-}

getCachedExpensives :: IO [Expensive]
getCachedExpensives = readIORef cachedExpensives
```

But at least within the current module there is no way to enforce that nobody touches `cachedExpensives`.
Andrew Gibiansky pointed out that Haskell allows arbitrary patterns at the top-level (try `5=3`).
We can leverage this to encapsulate the IORef. My first attempt looked like this:

``` haskell
getCachedExpensives :: IO [Expensive]
addCachedExpensives :: [Expensive] -> IO ()
addCachedExpensive  :: Expensive -> IO ()
(  getCachedExpensives
 , addCachedExpensives
 , addCachedExpensive
 ) = unsafePerformIO $ do
  cachedExpensives <- newIORef []
  return
    ( readIORef cachedExpensives
    , \new -> atomicModifyIORef' cachedExpensives (\old -> (new <> old, ()))
    , \new -> atomicModifyIORef' cachedExpensives (\old -> (new : old, ()))
    )
```

Thankfully [reddit](https://www.reddit.com/r/haskell/comments/40u69u/encapsulating_unsafe_iorefs/) pointed out that although this works fine in the current version of GHC, it is fundamentally unsafe and could break in any new release.
We still need a NOINLINE pragma, which will add more boilerplate. However, we still maintain our desired encapsulation.

``` haskell
makeCachedExpensiveInterface :: (IO [Expensive], [Expensive] -> IO (), Expensive -> IO ())
makeCachedExpensiveInterface = unsafePerformIO $ do
  cachedExpensives <- newIORef []
  return
    ( readIORef cachedExpensives
    , \new -> atomicModifyIORef' cachedExpensives (\old -> (new <> old, ()))
    , \new -> atomicModifyIORef' cachedExpensives (\old -> (new : old, ()))
    )
{-# NOINLINE makeCachedExpensiveInterface #-}

getCachedExpensives :: IO [Expensive]
addCachedExpensives :: [Expensive] -> IO ()
addCachedExpensive  :: Expensive -> IO ()
(  getCachedExpensives
 , addCachedExpensives
 , addCachedExpensive
 ) = makeCachedExpensiveInterface
```

