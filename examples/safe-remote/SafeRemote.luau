--!strict
--[[
	SafeRemote — example module produced by the roblox-dev plugin standards.

	Wraps server-side RemoteEvent handling with the validation ladder from the
	roblox-security skill: rate limit → type check → range check → handler.

	Usage (server):

		local SafeRemote = require(ReplicatedStorage.Shared.SafeRemote)

		SafeRemote.on("BuyItem", {
			rate = { perSecond = 3, burst = 5 },
			args = {
				SafeRemote.isString,
				SafeRemote.isIntegerIn(1, 100),
			},
		}, function(player, itemId, quantity)
			-- itemId and quantity are validated by the time you get here.
		end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Validators = require(script.Parent.Validators)

export type Validator = Validators.Validator

export type RemoteOptions = {
	rate: { perSecond: number, burst: number }?,
	args: { Validator },
}

local SafeRemote = {}

local REMOTE_FOLDER_NAME = "SafeRemotes"

-- Re-export the pure validators (tested standalone; see tests/run.luau)
SafeRemote.isString = Validators.isString
SafeRemote.isBoolean = Validators.isBoolean
SafeRemote.isFiniteNumber = Validators.isFiniteNumber
SafeRemote.isIntegerIn = Validators.isIntegerIn
SafeRemote.isKeyOf = Validators.isKeyOf
SafeRemote.isStringUpTo = Validators.isStringUpTo

-- ========================================================================
-- Token-bucket rate limiting, per player per remote
-- ========================================================================

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

local function allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * perSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- ========================================================================
-- Remote registration (server creates; client fires)
-- ========================================================================

local function remoteFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	assert(RunService:IsServer(), "SafeRemote folder must be created by the server")
	local folder = Instance.new("Folder")
	folder.Name = REMOTE_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

--- Server: register a validated handler for a named RemoteEvent.
function SafeRemote.on(name: string, options: RemoteOptions, handler: (Player, ...any) -> ())
	assert(RunService:IsServer(), "SafeRemote.on is server-only")

	local folder = remoteFolder()
	local remote: RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), `SafeRemote "{name}" collides with a non-RemoteEvent`)
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		remote = created
	end

	remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		local rate = options.rate
		if rate and not allow(player, name, rate.perSecond, rate.burst) then
			return -- silently drop; never error back to a potential exploiter
		end

		local argCount = select("#", ...)
		if argCount ~= #options.args then
			return
		end
		local args = table.pack(...)
		for index, validate in options.args do
			if not validate(args[index]) then
				return
			end
		end

		handler(player, table.unpack(args, 1, argCount))
	end)
end

--- Client: fire a named remote (waits for the server to have created it).
function SafeRemote.fire(name: string, ...: unknown)
	assert(RunService:IsClient(), "SafeRemote.fire is client-only")
	local folder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME)
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `SafeRemote "{name}" is not a RemoteEvent`)
	remote:FireServer(...)
end

return SafeRemote
