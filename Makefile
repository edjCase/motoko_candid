BUILD=build



.PHONY: all
all: test

test: $(BUILD)/Tests.wasm
	wasmtime ./build/Tests.wasm

$(BUILD)/Tests.wasm: test/Tests.mo make_build_dir install_mops_sources
	$(shell vessel bin)/moc $(shell mops sources) -wasi-system-api $< -o $@

install_mops_sources:
	mops install

make_build_dir:
	mkdir -p $(BUILD)

.PHONY: clean
clean:
	rm -r ./build/*