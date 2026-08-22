const task = require("./task")

type Handler = (...any) -> ()

export type DispatchPolicy = {
	ScheduleThread: (thread, Handler, thread, ...any) -> thread,
	ScheduleWaiter: (thread, any, ...any) -> thread,
	DebugFireTracebackLevel: number,
	GuardDisconnectedOnFire: boolean,
	TrackConnectionTracebackInDebug: boolean,
}

const Deferred: DispatchPolicy = {
	ScheduleThread = task.defer,
	ScheduleWaiter = task.defer,
	DebugFireTracebackLevel = 3,
	GuardDisconnectedOnFire = false,
	TrackConnectionTracebackInDebug = false,
}

const Immediate: DispatchPolicy = {
	ScheduleThread = task.spawn,
	ScheduleWaiter = task.spawn,
	DebugFireTracebackLevel = 4,
	GuardDisconnectedOnFire = true,
	TrackConnectionTracebackInDebug = true,
}

return table.freeze({
	Deferred = table.freeze(Deferred),
	Immediate = table.freeze(Immediate),
})
