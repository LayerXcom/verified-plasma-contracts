# Settings
# --------

specs_dir:=specs
build_dir:=.build

.PHONY: all clean kevm clean-kevm

all: k-files split-proof-tests

clean:
	rm -rf $(specs_dir) $(build_dir)

pandoc_tangle_submodule:=$(build_dir)/pandoc-tangle
TANGLER:=$(pandoc_tangle_submodule)/tangle.lua
LUA_PATH:=$(pandoc_tangle_submodule)/?.lua;;
export LUA_PATH

$(TANGLER):
	git submodule update --init -- $(pandoc_tangle_submodule)

kevm_repo:=https://github.com/kframework/evm-semantics
kevm_repo_dir:=$(build_dir)/evm-semantics

kevm:
	git submodule update --init -- $(kevm_repo_dir)
	cd $(kevm_repo_dir) \
		&& make repo-deps \
		&& make build-java


# Definition Files
# ----------------

k_files:=lemmas.k

k-files: $(patsubst %, $(specs_dir)/%, $(k_files))

# Lemmas
$(specs_dir)/lemmas.k: resources/lemmas.md $(TANGLER)
	@echo >&2 "== tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:".k" $< > $@

# Spec Files
# ----------

plasma_mvp_files:=operator-spec.k \
              currentChildBlock-spec.k \
              currentDepositBlock-spec.k \
              currentFeeExit-spec.k \
              exitsQueues-spec.k \
			  addToken-success-spec.k \
			  addToken-failure-spec.k \
              submitBlock-success-spec.k \
              submitBlock-failure-spec.k \
              deposit-success-spec.k \
              deposit-failure-spec.k \
              hasToken-true-spec.k \
              hasToken-false-spec.k \
              getChildChain-spec.k \
              getDepositBlock-spec.k \
              getExit-spec.k


proof_tests:=plasma-mvp

plasma-mvp: $(patsubst %, $(specs_dir)/plasma-mvp/%, $(plasma_mvp_files)) $(specs_dir)/lemmas.k

#plasma
plasma_mvp_tmpls:=plasma-mvp/module-tmpl.k plasma-mvp/spec-tmpl.k

$(specs_dir)/plasma-mvp/%-spec.k: $(plasma_mvp_tmpls) plasma-mvp/plasma-mvp-spec.ini
	@echo >&2 "==  gen-spec: $@"
	mkdir -p $(dir $@)
	python3 resources/gen-spec.py $^ $* $* > $@
	cp plasma-mvp/abstract-semantics.k $(dir $@)
	cp plasma-mvp/verification.k $(dir $@)

# Testing
# -------

TEST:=$(kevm_repo_dir)/kevm prove

test_files:=$(wildcard specs/*/*-spec.k)

test: $(test_files:=.test)

specs/%-spec.k.test: specs/%-spec.k
	$(TEST) $< --z3-impl-timeout 500 --verbose
