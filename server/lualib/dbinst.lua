local core = require "silly.core"
local env = require "silly.env"
local redis = require "redis"

local db = {}

db.inst = nil
function db.start()
	local err
	db.inst, err = redis:connect {
		addr = env.get("dbport")
	}
	print("Redis Connect:", db.inst, err)
	return db.inst and true or false
end

return db

