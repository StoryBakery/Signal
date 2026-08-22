const task = require("./task")

const Types = require("./Types")

type Handler = (...any) -> ()
type Cleanup = () -> ()

type BaseConnection = {
	Connected: boolean,
	Disconnect: (self: BaseConnection) -> (),
	Destroy: (self: BaseConnection) -> (),
}

type BaseSignal = {
	IsDestroyed: boolean,
	Connect: (self: BaseSignal, handler: Handler, priority: number?) -> BaseConnection,
	ConnectUnyielding: (
		self: BaseSignal,
		handler: Handler,
		priority: number?
	) -> BaseConnection,
	Once: (self: BaseSignal, handler: Handler, priority: number?) -> BaseConnection,
	OnceUnyielding: (
		self: BaseSignal,
		handler: Handler,
		priority: number?
	) -> BaseConnection,
	Wait: (self: BaseSignal) -> ...any,
	Fire: (self: BaseSignal, ...any) -> (),
	DisconnectAll: (self: BaseSignal) -> (),
	Destroy: (self: BaseSignal) -> (),
}

type BaseSignalClass = {
	new: () -> BaseSignal,
}

type LifecycleCallback = (self: any) -> ()
type ActiveCallback = (self: any) -> Cleanup?

type ObservedSignalData = {
	IsDestroyed: boolean,
	_signal: BaseSignal,
	_connectionCount: number,
	_hasBeenObserved: boolean,
	_onActiveCallback: ActiveCallback?,
	_onActiveCleanup: Cleanup?,
	_onFirstActiveCallback: ActiveCallback?,
	_onFirstActiveCleanup: Cleanup?,
	_onInactiveCallback: LifecycleCallback?,
}

type ObservedSignal = ObservedSignalData & {
	AttachLifecycle: (self: ObservedSignal, options: Types.ObservedSignalOptions?) -> (),
	_onFirstActive: (self: ObservedSignal) -> (),
	_onActive: (self: ObservedSignal) -> (),
	_onInactive: (self: ObservedSignal) -> (),
	_didBecomeObserved: (self: ObservedSignal) -> (),
	_didBecomeUnobserved: (self: ObservedSignal) -> (),
	_addConnection: (self: ObservedSignal) -> (),
	_removeConnection: (self: ObservedSignal) -> (),
	_makeConnectionTracked: (
		self: ObservedSignal,
		connection: BaseConnection
	) -> BaseConnection,
	Connect: (self: ObservedSignal, handler: Handler, priority: number?) -> BaseConnection,
	ConnectUnyielding: (
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	) -> BaseConnection,
	Once: (self: ObservedSignal, handler: Handler, priority: number?) -> BaseConnection,
	OnceUnyielding: (
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	) -> BaseConnection,
	Wait: (self: ObservedSignal) -> ...any,
	Fire: (self: ObservedSignal, ...any) -> (),
	HasConnections: (self: ObservedSignal) -> boolean,
	GetConnectionCount: (self: ObservedSignal) -> number,
	DisconnectAll: (self: ObservedSignal) -> (),
	Destroy: (self: ObservedSignal) -> (),
}

type ObservedSignalClass = {
	new: (options: Types.ObservedSignalOptions?) -> ObservedSignal,
}

const function appendLifecycleCallback(
	previousCallback: LifecycleCallback?,
	nextCallback: LifecycleCallback
): LifecycleCallback
	if previousCallback == nil then
		return nextCallback
	end

	return function(self: any)
		previousCallback(self)
		nextCallback(self)
	end
end

const function appendCleanup(previousCleanup: Cleanup?, nextCleanup: Cleanup?): Cleanup?
	if nextCleanup == nil then
		return previousCleanup
	end

	if previousCleanup == nil then
		return nextCleanup
	end

	return function()
		nextCleanup()
		previousCleanup()
	end
end

const function appendOnActiveCallback(
	previousCallback: ActiveCallback?,
	nextCallback: ActiveCallback
): ActiveCallback
	if previousCallback == nil then
		return nextCallback
	end

	return function(self: any)
		const previousCleanup = previousCallback(self)
		const nextCleanup = nextCallback(self)
		return appendCleanup(previousCleanup, nextCleanup)
	end
end

const function createObservedSignalClass(baseSignalClass: BaseSignalClass): ObservedSignalClass
	const ObservedSignal = {}
	ObservedSignal.__index = ObservedSignal

	function ObservedSignal.new(options: Types.ObservedSignalOptions?): ObservedSignal
		const data: ObservedSignalData = {
			IsDestroyed = false,
			_signal = baseSignalClass.new(),
			_connectionCount = 0,
			_hasBeenObserved = false,
			_onActiveCallback = nil,
			_onActiveCleanup = nil,
			_onFirstActiveCallback = nil,
			_onFirstActiveCleanup = nil,
			_onInactiveCallback = nil,
		}
		const signal = setmetatable(data, ObservedSignal) :: ObservedSignal

		signal:AttachLifecycle(options)

		return signal
	end

	function ObservedSignal.AttachLifecycle(
		self: ObservedSignal,
		options: Types.ObservedSignalOptions?
	)
		if options == nil or self.IsDestroyed then
			return
		end

		const onActive = options.OnActive
		if onActive ~= nil then
			self._onActiveCallback = appendOnActiveCallback(self._onActiveCallback, onActive)
		end

		const onFirstActive = options.OnFirstActive
		if onFirstActive ~= nil then
			if self._hasBeenObserved then
				const cleanup = onFirstActive(self)
				self._onFirstActiveCleanup = appendCleanup(self._onFirstActiveCleanup, cleanup)
			else
				self._onFirstActiveCallback =
					appendOnActiveCallback(self._onFirstActiveCallback, onFirstActive)
			end
		end

		const onInactive = options.OnInactive
		if onInactive ~= nil then
			self._onInactiveCallback = appendLifecycleCallback(self._onInactiveCallback, onInactive)
		end
	end

	function ObservedSignal._onFirstActive(self: ObservedSignal)
		const callback = self._onFirstActiveCallback
		local cleanup: Cleanup? = nil
		if callback ~= nil then
			cleanup = callback(self)
		end

		self._onFirstActiveCleanup = cleanup
	end

	function ObservedSignal._onActive(self: ObservedSignal)
		const callback = self._onActiveCallback
		local cleanup: Cleanup? = nil
		if callback ~= nil then
			cleanup = callback(self)
		end

		self._onActiveCleanup = cleanup
	end

	function ObservedSignal._onInactive(self: ObservedSignal)
		const cleanup = self._onActiveCleanup
		if cleanup ~= nil then
			self._onActiveCleanup = nil
			task.spawn(cleanup)
		end

		const callback = self._onInactiveCallback
		if callback ~= nil then
			callback(self)
		end
	end

	function ObservedSignal._didBecomeObserved(self: ObservedSignal)
		if not self._hasBeenObserved then
			self._hasBeenObserved = true
			self:_onFirstActive()
		end

		self:_onActive()
	end

	function ObservedSignal._didBecomeUnobserved(self: ObservedSignal)
		self:_onInactive()
	end

	function ObservedSignal._addConnection(self: ObservedSignal)
		const nextCount = self._connectionCount + 1
		self._connectionCount = nextCount

		if nextCount == 1 then
			self:_didBecomeObserved()
		end
	end

	function ObservedSignal._removeConnection(self: ObservedSignal)
		const previousCount = self._connectionCount
		if previousCount <= 0 then
			return
		end

		const nextCount = previousCount - 1
		self._connectionCount = nextCount

		if nextCount == 0 then
			self:_didBecomeUnobserved()
		end
	end

	function ObservedSignal._makeConnectionTracked(
		self: ObservedSignal,
		connection: BaseConnection
	): BaseConnection
		if not connection.Connected then
			return connection
		end

		self:_addConnection()

		const ownerSignal = self
		const baseDisconnect = connection.Disconnect
		local hasDisconnected = false

		const function trackedDisconnect(this: BaseConnection)
			if hasDisconnected then
				return
			end

			hasDisconnected = true

			const wasConnected = this.Connected
			baseDisconnect(this)

			if wasConnected then
				ownerSignal:_removeConnection()
			end
		end

		connection.Disconnect = trackedDisconnect
		connection.Destroy = trackedDisconnect

		return connection
	end

	function ObservedSignal.Connect(
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	): BaseConnection
		const connection = self._signal:Connect(handler, priority)
		return self:_makeConnectionTracked(connection)
	end

	function ObservedSignal.ConnectUnyielding(
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	): BaseConnection
		const connection = self._signal:ConnectUnyielding(handler, priority)
		return self:_makeConnectionTracked(connection)
	end

	function ObservedSignal.Once(
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	): BaseConnection
		const connection = self._signal:Once(handler, priority)
		return self:_makeConnectionTracked(connection)
	end

	function ObservedSignal.OnceUnyielding(
		self: ObservedSignal,
		handler: Handler,
		priority: number?
	): BaseConnection
		const connection = self._signal:OnceUnyielding(handler, priority)
		return self:_makeConnectionTracked(connection)
	end

	function ObservedSignal.Wait(self: ObservedSignal): ...any
		return self._signal:Wait()
	end

	function ObservedSignal.Fire(self: ObservedSignal, ...)
		self._signal:Fire(...)
	end

	function ObservedSignal.HasConnections(self: ObservedSignal): boolean
		return self._connectionCount > 0
	end

	function ObservedSignal.GetConnectionCount(self: ObservedSignal): number
		return self._connectionCount
	end

	function ObservedSignal.DisconnectAll(self: ObservedSignal)
		if self._connectionCount > 0 then
			self._connectionCount = 0
			self:_didBecomeUnobserved()
		end

		self._signal:DisconnectAll()
	end

	function ObservedSignal.Destroy(self: ObservedSignal)
		if self.IsDestroyed then
			return
		end

		self:DisconnectAll()

		const cleanup = self._onFirstActiveCleanup
		if cleanup ~= nil then
			self._onFirstActiveCleanup = nil
			task.spawn(cleanup)
		end

		self.IsDestroyed = true
		self._signal:Destroy()
	end

	return ObservedSignal
end

return createObservedSignalClass
