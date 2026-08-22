--[=[ 
	@class Signal
	
	시그널을 생성하고 사용할 수 있는 인터페이스를 제공합니다.
	로블록스 RBXScriptSignal 과 비슷한 사용감을 목표로 합니다. 
]=]

const DispatchPolicies = require("./DispatchPolicies")

const RunService: RunService? = if game then game:GetService("RunService") :: RunService else nil

const shouldDebugTraceback = RunService == nil or RunService:IsStudio()

type Handler = (...any) -> ()

type SignalProps = {
	IsDestroyed: boolean,
	_head: ConnectionNode?,
	_headUnyielding: ConnectionNode?,
	_traceback: string?,
	_waiters: { thread },
}

type Signal = SignalProps & {
	Connect: (self: Signal, handler: Handler, priority: number?) -> Connection,
	ConnectUnyielding: (self: Signal, handler: Handler, priority: number?) -> Connection,
	Once: (self: Signal, handler: Handler, priority: number?) -> Connection,
	OnceUnyielding: (self: Signal, handler: Handler, priority: number?) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),
}

type ConnectionData = {
	Connected: boolean,
	_node: ConnectionNode?,
}

type Connection = ConnectionData & {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
}

type ConnectionNode = {
	_signal: Signal,
	_connection: Connection?,
	_handler: Handler,
	_priority: number,

	_next: ConnectionNode?,
	_prev: ConnectionNode?,
	_traceback: string?,
}

type SignalClass = {
	new: () -> Signal,
}

type CreateSignalParams = {
	Dispatch: typeof(DispatchPolicies.Deferred),
	Prioritized: boolean?,
}

type CreateBaseConnectionNode = (
	signal: Signal,
	handler: Handler,
	priority: number,
	head: ConnectionNode?
) -> ConnectionNode

const DEFAULT_PRIORITY = 0

const function captureErrorTraceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

const function createSignalClass(params: CreateSignalParams): SignalClass
	const dispatch = params.Dispatch
	const scheduleThread = dispatch.ScheduleThread
	const scheduleWaiter = dispatch.ScheduleWaiter
	const debugFireTracebackLevel = dispatch.DebugFireTracebackLevel
	const guardDisconnectedOnFire = dispatch.GuardDisconnectedOnFire
	const prioritizesConnections = params.Prioritized == true
	const trackConnectionTracebackInDebug = dispatch.TrackConnectionTracebackInDebug

	const Signal = {}
	Signal.__index = Signal

	const Connection = {}
	Connection.__index = Connection

	const WAIT_SIGNAL_FIRED = {}
	const WAIT_SIGNAL_DESTROYED = {}
	const WAIT_DESTROYED_ERROR = "Signal is destroyed"

	function Signal.new(): Signal
		local traceback: string? = nil
		if shouldDebugTraceback then
			traceback = debug.traceback("Signal Created From: ", 2)
		end

		const data: SignalProps = {
			IsDestroyed = false,
			_head = nil,
			_headUnyielding = nil,
			_traceback = traceback,
			_waiters = {},
		}

		return setmetatable(data, Signal) :: Signal
	end

	local createBaseConnectionNode: CreateBaseConnectionNode
	if not shouldDebugTraceback or not trackConnectionTracebackInDebug then
		function createBaseConnectionNode(
			signal: Signal,
			handler: Handler,
			priority: number,
			head: ConnectionNode?
		): ConnectionNode
			return {
				_signal = signal,
				_connection = nil,
				_handler = handler,
				_priority = priority,

				_next = head,
				_prev = nil,
			}
		end
	else
		function createBaseConnectionNode(
			signal: Signal,
			handler: Handler,
			priority: number,
			head: ConnectionNode?
		): ConnectionNode
			return {
				_signal = signal,
				_connection = nil,
				_handler = handler,
				_priority = priority,

				_next = head,
				_prev = nil,
				_traceback = debug.traceback("Connected From: ", 3),
			}
		end
	end

	const addNewConnectionFromHead = (function()
		if not prioritizesConnections then
			return function(
				self: Signal,
				head: ConnectionNode?,
				handler: Handler,
				priority: number
			): (ConnectionNode, Connection)
				const node = createBaseConnectionNode(self, handler, priority, head)
				local nextHead = node

				if head ~= nil then
					head._prev = node
				end

				const data: ConnectionData = {
					Connected = true,
					_node = node,
				}
				const connection = setmetatable(data, Connection) :: Connection

				node._connection = connection

				return nextHead, connection
			end
		else
			return function(
				self: Signal,
				head: ConnectionNode?,
				handler: Handler,
				priority: number
			): (ConnectionNode, Connection)
				const node = createBaseConnectionNode(self, handler, priority, head)
				local nextHead = node

				local previous: ConnectionNode? = nil
				local nextNode: ConnectionNode? = head

				while nextNode ~= nil and nextNode._priority >= priority do
					previous = nextNode
					nextNode = nextNode._next
				end

				node._prev = previous
				node._next = nextNode

				if previous ~= nil then
					previous._next = node
					nextHead = head
				end

				if nextNode ~= nil then
					nextNode._prev = node
				end

				const data: ConnectionData = {
					Connected = true,
					_node = node,
				}
				const connection = setmetatable(data, Connection) :: Connection

				node._connection = connection

				return nextHead :: ConnectionNode, connection
			end
		end
	end)()

	function Signal.Connect(self: Signal, handler: Handler, priority: number?): Connection
		if self.IsDestroyed then
			const data: ConnectionData = {
				Connected = false,
				_node = nil,
			}
			return setmetatable(data, Connection) :: Connection
		end

		const head, connection =
			addNewConnectionFromHead(self, self._head, handler, priority or DEFAULT_PRIORITY)
		self._head = head

		return connection
	end

	function Signal.ConnectUnyielding(self: Signal, handler: Handler, priority: number?): Connection
		if self.IsDestroyed then
			const data: ConnectionData = {
				Connected = false,
				_node = nil,
			}
			return setmetatable(data, Connection) :: Connection
		end

		const head, connection = addNewConnectionFromHead(
			self,
			self._headUnyielding,
			handler,
			priority or DEFAULT_PRIORITY
		)
		self._headUnyielding = head

		return connection
	end

	function Signal.Once(self: Signal, handler: Handler, priority: number?): Connection
		local connection: Connection?
		const newConnection = self:Connect(function(...)
			if connection == nil then
				return
			end

			connection:Disconnect()
			connection = nil

			handler(...)
		end, priority)
		connection = newConnection

		return newConnection
	end

	function Signal.OnceUnyielding(self: Signal, handler: Handler, priority: number?): Connection
		local connection: Connection?
		const newConnection = self:ConnectUnyielding(function(...)
			if connection == nil then
				return
			end

			connection:Disconnect()
			connection = nil

			handler(...)
		end, priority)
		connection = newConnection

		return newConnection
	end

	function Signal.Wait(self: Signal): ...any
		if self.IsDestroyed then
			error(WAIT_DESTROYED_ERROR, 2)
		end

		const waiters = self._waiters
		waiters[#waiters + 1] = coroutine.running()

		const yielded = table.pack(coroutine.yield())
		if yielded[1] == WAIT_SIGNAL_DESTROYED then
			error(WAIT_DESTROYED_ERROR, 2)
		end

		return table.unpack(yielded, 2, yielded.n)
	end

	const freeThreads: { thread } = {}

	local fireThread: (...any) -> ()
	local runCallback: (...any) -> ()
	if not shouldDebugTraceback then
		function fireThread(thread: thread, fn: Handler, ...)
			scheduleThread(thread, fn, thread, ...)
		end

		function runCallback(callback: Handler, thread: thread, ...)
			callback(...)
			freeThreads[#freeThreads + 1] = thread
		end
	elseif trackConnectionTracebackInDebug then
		function fireThread(
			thread: thread,
			fn: Handler,
			connectionTraceback: string?,
			signalTraceback: string?,
			...
		)
			scheduleThread(
				thread,
				fn,
				thread,
				connectionTraceback,
				signalTraceback,
				debug.traceback("Fired From: ", debugFireTracebackLevel),
				...
			)
		end

		function runCallback(
			callback: Handler,
			thread: thread,
			connectionTraceback: string?,
			signalTraceback: string?,
			fireTraceback: string,
			...
		)
			local err: string?
			const suc = xpcall(callback, function(callbackError)
				err = captureErrorTraceback(callbackError)
			end, ...)
			if suc then
				freeThreads[#freeThreads + 1] = thread
				return
			end

			error(
				`{err}\n\n\z
				{connectionTraceback}\n\z
				{signalTraceback}\n\z
				{fireTraceback}`,
				3
			)
		end
	else
		function fireThread(thread: thread, fn: Handler, signalTraceback: string?, ...)
			scheduleThread(
				thread,
				fn,
				thread,
				signalTraceback,
				debug.traceback("Fired From: ", debugFireTracebackLevel),
				...
			)
		end

		function runCallback(
			callback: Handler,
			thread: thread,
			signalTraceback: string?,
			fireTraceback: string,
			...
		)
			local err: string?
			const suc = xpcall(callback, function(callbackError)
				err = captureErrorTraceback(callbackError)
			end, ...)
			if suc then
				freeThreads[#freeThreads + 1] = thread
				return
			end

			error(
				`{err}\n\n\z
				{signalTraceback}\n\z
				{fireTraceback}`,
				3
			)
		end
	end

	const function yielder()
		while true do
			runCallback(coroutine.yield())
		end
	end

	const function getOrCreateThread(): thread
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
		function invokeNodeHandler(node: ConnectionNode, _signalTraceback: string?, ...)
			fireThread(getOrCreateThread(), node._handler, ...)
		end
	elseif trackConnectionTracebackInDebug then
		function invokeNodeHandler(node: ConnectionNode, signalTraceback: string?, ...)
			fireThread(getOrCreateThread(), node._handler, node._traceback, signalTraceback, ...)
		end
	else
		function invokeNodeHandler(node: ConnectionNode, signalTraceback: string?, ...)
			fireThread(getOrCreateThread(), node._handler, signalTraceback, ...)
		end
	end

	local fire: (Signal, ...any) -> ()
	if guardDisconnectedOnFire then
		function fire(self: Signal, ...: any)
			local unyieldingNode = self._headUnyielding
			while unyieldingNode ~= nil do
				unyieldingNode._handler(...)
				unyieldingNode = unyieldingNode._next
			end

			local node: ConnectionNode? = self._head
			while node ~= nil do
				if node._connection ~= nil then
					invokeNodeHandler(node, self._traceback, ...)
				end

				node = node._next
			end

			const waiters = self._waiters
			if #waiters > 0 then
				self._waiters = {}
				for index = 1, #waiters do
					scheduleWaiter(waiters[index], WAIT_SIGNAL_FIRED, ...)
				end
			end
		end
	else
		function fire(self: Signal, ...: any)
			local unyieldingNode = self._headUnyielding
			while unyieldingNode ~= nil do
				unyieldingNode._handler(...)
				unyieldingNode = unyieldingNode._next
			end

			local node: ConnectionNode? = self._head
			while node ~= nil do
				invokeNodeHandler(node, self._traceback, ...)
				node = node._next
			end

			const waiters = self._waiters
			if #waiters > 0 then
				self._waiters = {}
				for index = 1, #waiters do
					scheduleWaiter(waiters[index], WAIT_SIGNAL_FIRED, ...)
				end
			end
		end
	end
	Signal.Fire = fire

	const function disconnectAllFromHead(head: ConnectionNode?)
		local node: ConnectionNode? = head
		while node ~= nil do
			const connection = node._connection
			if connection ~= nil then
				connection.Connected = false
				connection._node = nil
				node._connection = nil
			end

			node = node._next
		end
	end

	function Signal.DisconnectAll(self: Signal)
		disconnectAllFromHead(self._head)
		disconnectAllFromHead(self._headUnyielding)

		self._head = nil
		self._headUnyielding = nil
	end

	function Signal.Destroy(self: Signal)
		if self.IsDestroyed then
			return
		end

		self:DisconnectAll()
		self.IsDestroyed = true

		const waiters = self._waiters
		if #waiters > 0 then
			self._waiters = {}
			for index = 1, #waiters do
				scheduleWaiter(waiters[index], WAIT_SIGNAL_DESTROYED)
			end
		end
	end

	function Connection.Disconnect(self: Connection)
		if self.Connected ~= true then
			return
		end

		self.Connected = false

		const node = self._node
		if node == nil then
			return
		end

		const prev = node._prev
		const next = node._next

		if next ~= nil then
			next._prev = prev
		end

		if prev ~= nil then
			prev._next = next
		else
			if node._signal._head == node then
				node._signal._head = next
			else
				node._signal._headUnyielding = next
			end
		end

		node._connection = nil
		self._node = nil
	end

	Connection.Destroy = Connection.Disconnect

	return Signal
end

return createSignalClass
