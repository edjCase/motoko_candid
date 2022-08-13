#!/usr/bin/env bash

dir=build
if [[ ! -e $dir ]]; then
    mkdir -p $dir
fi
for filename in src/*.mo; do
    echo "Building $filename..."
    $(vessel bin)/moc $(vessel sources) -wasi-system-api "$filename" -o $dir/$(basename "$filename" .mo).wasm
    echo "Building $filename complete"
done