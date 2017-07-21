local core = require "silly.core"
local env = require "silly.env"
local channel = require "channel"
local rpccmd = require "protocol.rpc"
local tool = require "tool"
local db = require "db"
local aoi = require "aoi"
local xml = require "XML"
local npc = require "npc"
local scene = require "scene"
local unpack = string.unpack

require "role"
require "logic"

local slaveid = tonumber(env.get("sceneid"))
local slavetype = "scene"
local xmlpath = env.get("xmlconfig")

local EVENT = {
	connected = function(fd, online)
		local tbl = {}
		for i = 1, #online do
			local player = online[i]
			local uid = player.uid
			tbl[uid] = "online"
			db.roleload(uid)
			print("[scene] online", uid)
		end
		channel.onlinepatch(tbl, fd)
		for k, v in pairs(tbl) do
			aoi.leave(k)
		end
	end,
	close = function(gateid)
	end,
}

core.start(function()
	local l = tool.hublist()
	for k, v in pairs(l) do
		print(string.format("[role] gateid:%s port:%s", k, v))
	end
	local cmd = string.format("find %s -name '*.xml'", xmlpath)
	xml.parselist {
		xmlpath .. "/RoleLevel.xml",
		xmlpath .. "/RoleCreate.xml",
		xmlpath .. "/ItemUse.xml",
		xmlpath .. "/Skill.xml",
		xmlpath .. "/NPC.xml",
	}
	aoi.start(1000.0, 1000.0)
	scene.start(npc)
	npc.start()
	local dbok = db.start()
	local channelok = channel.start {
		channelid = slaveid,
		channeltype = slavetype,
		hublist = l,
		event = EVENT,
		rpccmd = rpccmd,
	}
	print("[role] server start, dbstart", dbok, "channelstart", channelok)
end)

