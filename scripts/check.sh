#!/usr/bin/env bash
# SwagBag local CI (spec 11.2). Run from anywhere; exits non-zero on any failure.
#   1 syntax  luac -p (Lua 5.5) and luajit -bl (Lua 5.1 rules, like WoW)
#   2 lint    luacheck with .luacheckrc
#   3 rules   forbidden tokens (spec 5.3), C_*/Enum only in Core/Adapter.lua, no goto
#   4 toc     scripts/toc_check.lua
#   5 tests   luajit spec/runner.lua spec/*_spec.lua
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
fail() { echo "FAIL: $*"; status=1; }

echo "== 1/5 syntax"
while IFS= read -r f; do
	luac -p "$f" || fail "luac -p $f"
	luajit -bl "$f" > /dev/null || fail "luajit parse $f"
done < <(find SwagBag spec scripts -name '*.lua' | sort)

echo "== 2/5 luacheck"
luacheck SwagBag spec scripts --formatter plain || fail "luacheck"

echo "== 3/5 forbidden tokens"
for tok in 'BankFrame:SetTab' 'BankFrame.SetTab' 'C_Bank.CloseBankFrame' 'CloseBankFrame(' 'OpenAllBags(' \
	'PurchaseBankTab' 'PreClick' 'PostClick'; do
	if grep -rnF -- "$tok" SwagBag; then fail "forbidden token: $tok"; fi
done
if grep -rnE '\.bankType[[:space:]]*=([^=]|$)' SwagBag; then fail "forbidden: writing .bankType"; fi
if grep -rnE '^[[:space:]]*_[[:space:]]*=([^=]|$)' SwagBag; then fail "forbidden: assignment to global _"; fi
if grep -rnE '(^|[^[:alnum:]_])goto[[:space:]]' SwagBag; then fail "forbidden: goto (not Lua 5.1)"; fi
# A C_* namespace is named only in the Adapter, comments included: a bare name with no dot after it counts too
# (week 7, ruling R5: a comment once named one). Enum is matched where it is used (Enum.).
if grep -rnE '(^|[^[:alnum:]_])(C_[A-Z][A-Za-z]*|Enum\.)' SwagBag | grep -v '^SwagBag/Core/Adapter.lua:'; then
	fail "C_* or Enum named outside SwagBag/Core/Adapter.lua (comments included)"
fi

echo "== 4/5 TOC"
luajit scripts/toc_check.lua || fail "TOC"

echo "== 5/5 unit tests"
luajit spec/runner.lua spec/*_spec.lua || fail "unit tests"

if [ "$status" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$status"
