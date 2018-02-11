---
title: "Rust: Process Iterator"
date: "2018-02-10T12:12:03.284Z"
---

I published a crate [process-iterator](https://crates.io/crates/process-iterator)
that allows you to use an external process as an iterator (adaptor or consuer).

Some background on the usefulness of this functionality: I am compared a Rust re-implementation to its Python original.
My Rust program was more than 2x slower than the Python version.
The Rust code used a simple flate2 encoder/decoder.
The Python code streamed data through the pigz compression tool.
Streaming through pigz allows the Python to use multiple cores (pigz itself uses multiple cores, plus Python code can run while pigz is running).

After writing this library and using an external pigz process in my Rust program, Rust was around 2x faster than the Python code.
That number is not particularly impressive for Rust, but in this case almost all of the hard work of this program (Python or Rust) is done by external programs so there isn't a whole lot for Rust to improve upon.

My main problem with this library is the problem of handling errors that come up (on separate threads managing input/ouput) while streaming data on the main thread.
Any pointers on existing techniques for handling this in Rust are most welcome.

To see how the code works, take a look at the [test suite](https://github.com/gregwebs/rust-process-iterator/blob/master/tests/integration.rs)
