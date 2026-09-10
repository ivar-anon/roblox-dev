--!nonstrict
--[[
	TestEZ spec for SafeRemote's pure validators.

	Specs are --!nonstrict by convention: describe/it/expect are globals
	injected by the TestEZ runner at execution time, which the static checker
	cannot see. The module under test stays --!strict.

	The validators have no Roblox API dependencies beyond typeof, so they can
	also run under Lune with a TestEZ-compatible shim.
]]

return function()
	local SafeRemote = require(script.Parent.SafeRemote)

	describe("isFiniteNumber", function()
		it("accepts ordinary numbers", function()
			expect(SafeRemote.isFiniteNumber(0)).to.equal(true)
			expect(SafeRemote.isFiniteNumber(-3.5)).to.equal(true)
		end)

		it("rejects NaN", function()
			expect(SafeRemote.isFiniteNumber(0 / 0)).to.equal(false)
		end)

		it("rejects infinities", function()
			expect(SafeRemote.isFiniteNumber(math.huge)).to.equal(false)
			expect(SafeRemote.isFiniteNumber(-math.huge)).to.equal(false)
		end)

		it("rejects non-numbers", function()
			expect(SafeRemote.isFiniteNumber("7")).to.equal(false)
			expect(SafeRemote.isFiniteNumber(nil)).to.equal(false)
			expect(SafeRemote.isFiniteNumber(true)).to.equal(false)
		end)
	end)

	describe("isIntegerIn", function()
		local oneToTen = SafeRemote.isIntegerIn(1, 10)

		it("accepts in-range integers, including the boundaries", function()
			expect(oneToTen(1)).to.equal(true)
			expect(oneToTen(10)).to.equal(true)
			expect(oneToTen(5)).to.equal(true)
		end)

		it("rejects out-of-range and non-integer values", function()
			expect(oneToTen(0)).to.equal(false)
			expect(oneToTen(11)).to.equal(false)
			expect(oneToTen(2.5)).to.equal(false)
		end)

		it("rejects the classic exploit payloads", function()
			expect(oneToTen(0 / 0)).to.equal(false) -- NaN
			expect(oneToTen(math.huge)).to.equal(false)
			expect(oneToTen(-math.huge)).to.equal(false)
			expect(oneToTen("5")).to.equal(false)
			expect(oneToTen(nil)).to.equal(false)
		end)
	end)

	describe("isKeyOf", function()
		local catalog = { sword = { price = 100 }, bow = { price = 150 } }
		local isItemId = SafeRemote.isKeyOf(catalog)

		it("accepts known keys and rejects unknown or non-string keys", function()
			expect(isItemId("sword")).to.equal(true)
			expect(isItemId("shield")).to.equal(false)
			expect(isItemId(1)).to.equal(false)
			expect(isItemId(nil)).to.equal(false)
		end)
	end)
end
