--!strict
--[[
	Standalone test runner for the pure example modules.
	Runs under the Luau CLI (no Roblox required):

		luau tests/run.luau

	CI executes this on every push. The Roblox-dependent half of SafeRemote
	is covered by the TestEZ spec (examples/safe-remote/SafeRemote.spec.luau),
	which runs inside Roblox Studio.
]]

local Validators = require("../examples/safe-remote/Validators")

local passed = 0
local failed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print(`FAIL: {name}`)
	end
end

-- isFiniteNumber ------------------------------------------------------------
check("isFiniteNumber accepts 0", Validators.isFiniteNumber(0))
check("isFiniteNumber accepts negatives", Validators.isFiniteNumber(-3.5))
check("isFiniteNumber rejects NaN", not Validators.isFiniteNumber(0 / 0))
check("isFiniteNumber rejects +inf", not Validators.isFiniteNumber(math.huge))
check("isFiniteNumber rejects -inf", not Validators.isFiniteNumber(-math.huge))
check("isFiniteNumber rejects string", not Validators.isFiniteNumber("7"))
check("isFiniteNumber rejects nil", not Validators.isFiniteNumber(nil))
check("isFiniteNumber rejects boolean", not Validators.isFiniteNumber(true))

-- isIntegerIn ----------------------------------------------------------------
local oneToTen = Validators.isIntegerIn(1, 10)
check("isIntegerIn accepts lower bound", oneToTen(1))
check("isIntegerIn accepts upper bound", oneToTen(10))
check("isIntegerIn accepts middle", oneToTen(5))
check("isIntegerIn rejects below range", not oneToTen(0))
check("isIntegerIn rejects above range", not oneToTen(11))
check("isIntegerIn rejects non-integer", not oneToTen(2.5))
check("isIntegerIn rejects NaN payload", not oneToTen(0 / 0))
check("isIntegerIn rejects +inf payload", not oneToTen(math.huge))
check("isIntegerIn rejects -inf payload", not oneToTen(-math.huge))
check("isIntegerIn rejects numeric string", not oneToTen("5"))
check("isIntegerIn rejects nil", not oneToTen(nil))

-- isKeyOf --------------------------------------------------------------------
local catalog: { [string]: unknown } = { sword = true, bow = true }
local isItemId = Validators.isKeyOf(catalog)
check("isKeyOf accepts known key", isItemId("sword"))
check("isKeyOf rejects unknown key", not isItemId("shield"))
check("isKeyOf rejects number", not isItemId(1))
check("isKeyOf rejects nil", not isItemId(nil))

-- isStringUpTo ---------------------------------------------------------------
local isNickname = Validators.isStringUpTo(20)
check("isStringUpTo accepts short string", isNickname("Ivar"))
check("isStringUpTo accepts max length", isNickname(string.rep("a", 20)))
check("isStringUpTo rejects empty string", not isNickname(""))
check("isStringUpTo rejects overlong string", not isNickname(string.rep("a", 21)))
check("isStringUpTo rejects non-string", not isNickname(42))

-- isString / isBoolean ---------------------------------------------------------
check("isString accepts string", Validators.isString("x"))
check("isString rejects number", not Validators.isString(1))
check("isBoolean accepts false", Validators.isBoolean(false))
check("isBoolean rejects nil", not Validators.isBoolean(nil))

-- ------------------------------------------------------------------------------
print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} test(s) failed`)
end
