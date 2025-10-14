# zig-test-project

## Useful Commands

Enter nix-shell:

```sh
nix-shell
```

Run zig tests and print out test results:

```sh
zig test src/main.zig 2>&1 | cat
```

Build C++ and run:

```sh
zig c++ c-src/torben.cpp -std=c++20 -o test && ./test
```

## Resources

https://github.com/grokkhub/zig-cheatsheet
