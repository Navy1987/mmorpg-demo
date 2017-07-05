local env = require "silly.env"
local zproto = require "zproto"
local redis = require "redis"
local format = string.format

local M = {}
local dbinst

local dbkey = "role:%s:coord"

function M.coord(uid)
	local x, z
	local k = format(dbkey, uid)
	local ok, res = dbinst:hget(k, "x")
	if ok then
		x = tonumber(res)
	else
		x = 1
	end

	ok, res = dbinst:hget(k, "z")
	if ok then
		z = tonumber(res)
	else
		z = 1
	end
	return x, z
end

function M.updatecoord(uid, x, z)
	local k = format(dbkey, uid)
	dbinst:hset(k, "x", x)
	dbinst:hset(k, "z", z)
end

function M.start()
	local err
	dbinst, err = redis:connect {
		addr = env.get("dbport")
	}
	return dbinst and true or false
end

return M

