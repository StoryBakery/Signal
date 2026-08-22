const DispatchPolicies = require("./DispatchPolicies")
const createObservedSignalClass = require("./ObservedFactory")
const createSignalClass = require("./SignalFactory")

const Deferred = createSignalClass({
	Dispatch = DispatchPolicies.Deferred,
})

const Immediate = createSignalClass({
	Dispatch = DispatchPolicies.Immediate,
})

const PrioritizedDeferred = createSignalClass({
	Dispatch = DispatchPolicies.Deferred,
	Prioritized = true,
})

const PrioritizedImmediate = createSignalClass({
	Dispatch = DispatchPolicies.Immediate,
	Prioritized = true,
})

const ObservedDeferred = createObservedSignalClass(Deferred)
const ObservedImmediate = createObservedSignalClass(Immediate)
const ObservedPrioritizedDeferred = createObservedSignalClass(PrioritizedDeferred)
const ObservedPrioritizedImmediate = createObservedSignalClass(PrioritizedImmediate)

const Prioritized = {
	Deferred = PrioritizedDeferred,
	Immediate = PrioritizedImmediate,
}

function Prioritized.new()
	return PrioritizedDeferred.new()
end

const ObservedPrioritized = {
	Deferred = ObservedPrioritizedDeferred,
	Immediate = ObservedPrioritizedImmediate,
}

function ObservedPrioritized.new(options)
	return ObservedPrioritizedDeferred.new(options)
end

const Observed = {
	Deferred = ObservedDeferred,
	Immediate = ObservedImmediate,
	Prioritized = table.freeze(ObservedPrioritized),
}

function Observed.new(options)
	return ObservedDeferred.new(options)
end

return table.freeze({
	Deferred = Deferred,
	Immediate = Immediate,
	Observed = table.freeze(Observed),
	Prioritized = table.freeze(Prioritized),
})
