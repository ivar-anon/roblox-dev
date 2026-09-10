--!strict
--[[
	Pure argument validators for remote payloads — no Roblox API dependencies,
	so they run (and are tested) under standalone Luau/Lune as well as Roblox.

	These implement the type/range steps of the validation ladder from the
	roblox-dev security guidance: reject NaN, ±infinity, non-integers,
	out-of-range values and wrong types before any handler logic runs.
]]

export type Validator = (value: unknown) -> boolean

local Validators = {}

function Validators.isString(value: unknown): boolean
	return type(value) == "string"
end

function Validators.isBoolean(value: unknown): boolean
	return type(value) == "boolean"
end

--- A finite number (rejects NaN and ±infinity).
function Validators.isFiniteNumber(value: unknown): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge
end

--- An integer within [min, max] inclusive.
function Validators.isIntegerIn(min: number, max: number): Validator
	return function(value: unknown): boolean
		if not Validators.isFiniteNumber(value) then
			return false
		end
		local n = value :: number
		return n == math.floor(n) and n >= min and n <= max
	end
end

--- A string that is a key of the given map (e.g. an item id in a catalog).
function Validators.isKeyOf(map: { [string]: unknown }): Validator
	return function(value: unknown): boolean
		return type(value) == "string" and map[value :: string] ~= nil
	end
end

--- A string with length in [1, maxLength] (e.g. chat/nickname input).
function Validators.isStringUpTo(maxLength: number): Validator
	return function(value: unknown): boolean
		return type(value) == "string"
			and #(value :: string) >= 1
			and #(value :: string) <= maxLength
	end
end

return Validators
