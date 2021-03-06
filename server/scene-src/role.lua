local channel = require "channel"
local xml = require "XML"
local property = require "protocol.property"
local db = require "db"
local errno = require "protocol.errno"

local a_roleinfo = {
	name = false,
	level = false,
	exp = false,
	gold = false,
	bag = false,
	prop = false,
	hp = false,
}
local function a_roleinfo_fill(role)
	a_roleinfo.name = role.name
	a_roleinfo.level = role.level
	a_roleinfo.exp = role.exp
	a_roleinfo.gold = role.gold
	a_roleinfo.bag = role.bag
	a_roleinfo.prop = role
	a_roleinfo.hp = role.hp
	a_roleinfo.mp = role.mp
	print("roleinfo_fill", role.hp, role.mp, role.exp)
end

local function r_roleinfo(uid, req, fd)
	print("r_roleinfo", uid)
	local info = db.roleload(uid)
	if not info then
		return channel.errorclient(fd, uid, "a_roleinfo", errno.ROLE_NONEXIST)
	end
	a_roleinfo_fill(info)
	return channel.sendclient(fd, uid, "a_roleinfo", a_roleinfo)
end

local function r_rolecreate(uid, req, fd)
	print("r_rolecreate", uid, req.name)
	local info = db.roleload(uid)
	if info then
		return channel.sendclient(fd, uid, "a_rolecreate", info)
	end
	info = db.rolecreate(uid, req.name)
	a_roleinfo_fill(info)
	return channel.sendclient(fd, uid, "a_rolecreate", a_roleinfo)
end

local a_itemuse = {
	hp = false,
}
local function r_itemuse(uid, req, fd)
	--[[
	local id = req.id
	local count = req.count
	local bag = db.roleget(uid)
	local basic = db.roleget(uid)
	for k, v in pairs(bag) do
		print('itemuse bag', k, v)
	end
	local item = bag[id]
	print("itemuse", id, item)
	if not item or item.count < count then
		return channel.errorclient(fd, uid, "a_itemuse", errno.ROLE_NOITEM)
	end
	local x = xml.getkey("ItemUse.xml", id)
	print("r_itemuse", uid, id, count)
	item.count = item.count - count;
	if item.count == 0 then
		bag[id] = nil
	end
	local hp = basic.hp + item.hp
	basic.hp = hp
	db.roledirtybag(uid)
	db.roledirtybasic(uid)
	a_itemuse.hp = hp
	return channel.sendclient(fd, uid, "a_itemuse", a_itemuse)
	]]--
end

channel.regclient("r_roleinfo", r_roleinfo)
channel.regclient("r_rolecreate", r_rolecreate)
channel.regclient("r_itemuse", r_itemuse)

