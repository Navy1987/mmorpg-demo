local core = require "silly.core"
local np = require "netpacket"
local sproto = require "protocol.server"
local cproto = require "protocol.client"
local slave = require "cluster.slave"
local pack = string.pack
local unpack = string.unpack

------------------router

local router_handler = {}
local router_client = {}

local function router_register(proto, cmd, func)
	assert(func, cmd)
	local cb = function(uid, dat, fd)
		local req
		if #dat > 0 then
			req = proto:decode(cmd, dat)
		else
			req = NIL
		end
		func(uid, req, fd)
	end
	router_handler[cmd] = cb
end

local function router_regserver(cmd, func)
	local cmd = sproto:querytag(cmd)
	router_register(sproto, cmd, func)
end

local function router_regclient(cmd, func)
	local cmd = cproto:querytag(cmd)
	router_register(cproto, cmd, func)
	router_client[cmd] = true
end

------------------user from gate

local user_gate = {}
local function user_attach(uid, fd)
	print("attach", uid, fd)
	user_gate[uid] = fd
end
local function user_detach(uid)
	user_gate[uid] = nil
end

local function user_patch(uidmap, onlinefd)
	for uid, fd in pairs(user_gate) do
		if fd == onlinefd then
			if not uidmap[uid] then
				uidmap[uid] = "offline"
			else
				uidmap[uid] = nil
			end
		end
	end
	for uid, _ in pairs(uidmap) do
		user_gate[uid] = onlinefd
	end
	return uidmap
end


------------------protocol socket function
local ERR = {
	cmd = false,
	err = false,
}

local function sendfunc(proto)
	return function(fd, uid, cmd, ack)
		cmd = proto:querytag(cmd)
		local hdr = pack("<I4I4", uid, cmd)
		local dat = proto:encode(cmd, ack)
		return slave.send(fd, hdr .. dat)
	end
end

local function senduidfunc(proto)
	return function(uid, cmd, ack)
		local fd = user_gate[uid]
		cmd = proto:querytag(cmd)
		local hdr = pack("<I4I4", uid, cmd)
		local dat = proto:encode(cmd, ack)
		return slave.send(fd, hdr .. dat)
	end
end

local sendserver = sendfunc(sproto)
local sendclient = sendfunc(cproto)
local senduid = senduidfunc(cproto)
local function senderror(fd, uid, cmd, err)
	cmd = cproto:querytag(cmd)
	ERR.cmd = cmd
	ERR.err = err
	sendclient(fd, uid, "a_error", ERR)
end

local s_multicast = {
	uid = {},
	data = false,
}

local function multicastgate(gatelist, cmd, ack)
	local cmd = cproto:querytag(cmd)
	local hdr = pack("<I4", cmd)
	local dat = cproto:encode(cmd, ack)
	dat = hdr .. dat
	s_multicast.data = dat
	for fd, uids in pairs(gatelist) do
		s_multicast.uid = uids
		sendserver(fd, 0, "s_multicast", s_multicast)
		gatelist[fd] = nil
	end
	s_multicast.data = false
end

local gate = {}
local function multicastmap(cmd, ack, map)
	for uid, _ in pairs(map) do
		local fd = user_gate[uid]
		local g = gate[fd]
		if not g then
			g = {}
			gate[fd] = g
		end
		g[#g + 1] = uid
	end
	return multicastgate(gate, cmd, ack)
end

local function multicastarr(cmd, ack, arr)
	local i = 1
	for i = 1, #arr do
		local uid = arr[i]
		local fd = user_gate[uid]
		local g = gate[fd]
		if not g then
			g = {}
			gate[fd] = g
		end
		g[#g + 1] = uid
	end
	return multicastgate(gate, cmd, ack)
end

local function multicastarrclr(cmd, ack, arr)
	local i = 1
	for i = 1, #arr do
		local uid = arr[i]
		arr[i] = nil
		local fd = user_gate[uid]
		local g = gate[fd]
		if not g then
			g = {}
			gate[fd] = g
		end
		g[#g + 1] = uid
	end
	return multicastgate(gate, cmd, ack)

end

------------------rpc
local TIMEOUT = 10000
local TIMER = 1000
local rpc_socket = {
	--['fd'] = {
	--	suspend = {}
	--	wheel = {}
	--}
}

local function rpc_wheel(time)
	local wheel = time % TIMEOUT
	return wheel // TIMER
end

local function rpc_wakeupall(socket)
	local rpc_suspend = socket.suspend
	for k, co in pairs(rpc_suspend) do
		core.wakeup(co)
		rpc_suspend[k] = nil
	end
end

local function rpc_initwheel(socket)
	local wheel = {}
	for i = 0, TIMEOUT // TIMER do
		wheel[i] = {}
	end
	socket.wheel = wheel
end

local function rpc_waitfor(socket, id)
	local co = core.running()
	local w = rpc_wheel(core.current() + TIMEOUT)
	socket.suspend[id] = co
	local expire = socket.wheel[w]
	expire[#expire + 1] = id
	return core.wait()
end

local function rpc_timer(now, socket)
	local w = wheel(now)
	local expire = socket.wheel[w]
	local suspend = socket.suspend
	for k, session in pairs(expire) do
		local co = suspend[session]
		if co then
			print("[rpc] timeout session:", session)
			suspend[session] = nil
			core.wakeup(co)
		end
		expire[k] = nil
	end
end

local function rpc_timerwrapper()
	local now = core.current()
	for _, s in pairs(rpc_socket) do
		local ok ,err = core.pcall(timer, now, s)
		if not ok then
			print(err)
		end
	end
	core.timeout(TIMER, rpc_timerwrapper)
end

local function rpc_ack(uid, ack, fd)
	local s = rpc_socket[fd]
	if not s then
		print("[rpc] socket close:", fd)
	end
	local rpc = assert(ack.rpc, "rpc_ack need field 'rpc'")
	local co = s.suspend[rpc]
	if not co then
		print("[rpc] session timout:", rpc)
		return
	end
	core.wakeup(co, ack)
	s.suspend[rpc] = nil
end

local function rpc_call(fd, uid, cmd, req)
	local s = rpc_socket[fd]
	if not s then
		return
	end
	local rpc = core.genid()
	req.rpc = rpc
	local ok = sendserver(fd, uid, cmd, req)
	if not ok then
		return
	end
	return rpc_waitfor(s, rpc)
end

local function rpc_cmdlist(cmd_array)
	for _, cmd in pairs(cmd_array) do
		router_regserver(cmd, rpc_ack)
	end
end

local function rpc_connected(fd)
	local s = {
		wheel = false,
		suspend = {},
	}
	rpc_initwheel(s)
	rpc_socket[fd] = s
end

local function rpc_close(fd)
	local s = rpc_socket[fd]
	if not s then
		return
	end
	rpc_wakeupall(s)
	rpc_socket[fd] = nil
end

-----------------protocol
local function register_router(fd, channelid, channeltype)
	local h = {}
	local sr_register = {
		rpc = false,
		id = channelid,
		typ = channeltype,
		handler = h,
	}
	for cmd, _ in pairs(router_client) do
		print("[channel] cmd:", cmd)
		h[#h + 1] = cmd
	end
	while true do
		local ack = rpc_call(fd, 0, "sr_register", sr_register)
		print("register", ack, ack and ack.rpc or "")
		if ack then
			return ack.online
		end
	end
end

-----------------interface

local M = {
call = rpc_call,
sendserver = sendserver,
sendclient = sendclient,
senduid = senduid,
multicastmap = multicastmap,
multicastarr = multicastarr,
multicastarrclr = multicastarrclr,
errorclient = senderror,
regclient = router_regclient,
regserver = router_regserver,
onlineattach = user_attach,
onlinedetach = user_detach,
onlinepatch = user_patch,
start = function(config)
	local hook = config.event
	local channelid = config.channelid
	local channeltype = config.channeltype
	rpc_cmdlist(config.rpccmd)
	slave.start {
		masters = config.hublist,
		event = {
			connected = function(fd)
				print("[channel] connected", fd)
				rpc_connected(fd)
				local online = register_router(fd, channelid, channeltype)
				hook.connected(fd, online)
			end,
			close = function(fd)
				print("[channel] close", fd)
				rpc_close(fd)
				hook.close(fd)
			end,
			data = function(fd, d, sz)
				local dat = core.tostring(d, sz)
				np.drop(d)
				local uid, cmd = unpack("<I4I4", dat)
				local func = router_handler[cmd]
				if not func then
					print("[role] unkonw cmd:", cmd)
					return
				end
				func(uid, dat:sub(8 + 1), fd)
			end
		}
	}
end
}

return M


