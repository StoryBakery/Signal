
local Config = require("./Config")
local shouldDebugTraceback = Config.TraceBack

local Signal = {}
Signal.__index = Signal


local Connection = {}
Connection.__index = Connection

export type Signal = typeof( setmetatable({} :: {
	IsDestroyed: boolean,
	_head: ConnectionNode?,
	_headUnyielding: ConnectionNode?,
}, Signal) )

export type Connection = typeof( setmetatable({
	Connected = true,
	_node = nil :: ConnectionNode?
}, Connection) )

type ConnectionNode = {
	_signal: Signal,
	_connection: Connection?,
	_handler: (...any) -> (),

	_next: ConnectionNode?,
	_prev: ConnectionNode?,
	_traceback: string?,

	_parallel:boolean?,
}

--#region Constructors
function Signal.new(): Signal
	return setmetatable({
		IsDestroyed = false,
		_head = nil,
		_headUnyielding = nil,
	}, Signal)
end
--#endregion Constructors

--#region Methods
local createBaseConnectionNode
if not shouldDebugTraceback then
	function createBaseConnectionNode(signal: Signal, handler, head): ConnectionNode
		return {
			_signal = signal :: Signal,
			_connection = nil,
			_handler = handler,

			_next = head,
			_prev = nil,
		}
	end
else
	function createBaseConnectionNode(signal: Signal, handler, head): ConnectionNode
		return {
			_signal = signal :: Signal,
			_connection = nil,
			_handler = handler,

			_next = head,
			_prev = nil,
			_traceback = debug.traceback("Connected From: ", 4)
		}
	end
end

function Signal:_addNewConnectionNodeFromHead(head, handler)
	local node = createBaseConnectionNode(self, handler, head)

	if head ~= nil then
		head._prev = node
	end

	local connection = setmetatable({
		Connected = true,
		_node = node
	}, Connection)

	node._connection = connection

	return node, connection
end

function Signal:Connect(
	handler: (...any) -> ()
): Connection

	if self.IsDestroyed then
		return setmetatable({
			Connected = false,
			_node = nil
		}, Connection)
	end

	local node, connection = self:_addNewConnectionNodeFromHead(self._head, handler)
	self._head = node

	return connection :: Connection
end

function Signal:ConnectUnyielding(
	handler: (...any) -> ()
): Connection

	if self.IsDestroyed then
		return setmetatable({
			Connected = false,
			_node = nil
		}, Connection)
	end

	local node, connection = self:_addNewConnectionNodeFromHead(self._headUnyielding, handler)
	self._headUnyielding = node

	return connection :: Connection
end


function Signal:Once(
	handler: (...any) -> ()
): Connection

	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)

	return connection
end

function Signal:OnceUnyielding(
	handler: (...any) -> ()
): Connection

	local connection
	connection = self:ConnectUnyielding(function(...)
		connection:Disconnect()
		handler(...)
	end)

	return connection
end

function Signal:Wait(): (...any)
	local thread do
		thread = coroutine.running()

		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(thread, ...)
		end)
	end

	return coroutine.yield()
end

local freeThreads: { thread } = {}

local fireThread, runCallback
if not shouldDebugTraceback then
	function fireThread(thread, fn, ...)
		task.spawn(thread, fn, thread, ...)
	end

	function runCallback(callback, thread, ...)
		callback(...)
		table.insert(freeThreads, thread)
	end
else
	function fireThread(thread, fn, connectionTraceback, ...)
		task.spawn(
			thread, fn, thread, connectionTraceback, 
			debug.traceback("From: ", 4), 
			...
		)
	end

	function runCallback(callback, thread, connectionTraceback, traceback, ...)
		local suc, err = pcall(callback, ...)
		if suc then
			table.insert(freeThreads, thread)
			return
		end

		error(err .. "\n\n" .. connectionTraceback .. "\n" .. traceback, 3)
	end
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local function getOrCreateThread(): thread
	local thread
	if #freeThreads > 0 then
		thread = freeThreads[#freeThreads]
		freeThreads[#freeThreads] = nil
	else
		thread = coroutine.create(yielder)
		coroutine.resume(thread)
	end

	return thread
end

local invokeNodeHandler
if not shouldDebugTraceback then
	function invokeNodeHandler(node: ConnectionNode, ...)
		fireThread(getOrCreateThread(), node._handler, ...)
	end
else
	function invokeNodeHandler(node: ConnectionNode, ...)
		fireThread(getOrCreateThread(), node._handler, node._traceback, ...)
	end
end

function Signal:Fire(...: any)
	local unyieldingNode = self._headUnyielding
	while unyieldingNode ~= nil do
		unyieldingNode._handler(...)
		unyieldingNode = unyieldingNode._next
	end

	local node: ConnectionNode? = self._head

	while node ~= nil do
		if node._connection ~= nil then
			invokeNodeHandler(node, ...)
		end

		node = node._next
	end
end

function Signal:DisconnectAll()
	local node: ConnectionNode? = self._head
	while node ~= nil do
		local _connection = node._connection

		if _connection ~= nil then
			_connection.Connected = false
			_connection._node = nil
			node._connection = nil
		end

		node = node._next
	end

	self._head = nil
end

function Signal:Destroy()
	if self.IsDestroyed then
		return
	end

	self:DisconnectAll()
	self.IsDestroyed = true
end

function Connection:Disconnect()
	if self.Connected ~= true then
		return
	end

	self.Connected = false

	local _node: ConnectionNode = self._node
	local _prev = _node._prev
	local _next = _node._next

	if _next ~= nil then
		_next._prev = _prev
	end

	if _prev ~= nil then
		_prev._next = _next
	else
		-- _node == _signal._head

		_node._signal._head = _next
	end

	_node._connection = nil
	self._node = nil
end
Connection.Destroy = Connection.Disconnect
--#endregion Methods

return Signal