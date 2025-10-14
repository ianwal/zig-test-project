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

Build CLI program and run:

```sh
zig build run
./zig-out/bin/pdq-hash-image "original-512x512.rgb" 512 512
```

## Resources

https://github.com/grokkhub/zig-cheatsheet
