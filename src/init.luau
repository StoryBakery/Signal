const Types = require("@self/Types")
const Variants = require("@self/Variants")

const SignalModule = {}
SignalModule.Deferred = Variants.Deferred
SignalModule.Immediate = Variants.Immediate
SignalModule.Observed = Variants.Observed
SignalModule.Prioritized = Variants.Prioritized

export type DefaultSignature = Types.DefaultSignature
export type DispatchMode = Types.DispatchMode
export type SignalOptions = Types.SignalOptions
export type Connection = Types.Connection
export type SignalBase<Signature = DefaultSignature> = Types.SignalBase<Signature>
export type ObservedSignalOptions = Types.ObservedSignalOptions
export type ObservedSignalBase<Signature = DefaultSignature> = Types.ObservedSignalBase<Signature>
export type Signal<Params... = ...any> = Types.Signal<Params...>
export type ObservedSignal<Params... = ...any> = Types.ObservedSignal<Params...>
export type PrioritizedSignalBase<Signature = DefaultSignature> = Types.PrioritizedSignalBase<
	Signature
>
export type PrioritizedSignal<Params... = ...any> = Types.PrioritizedSignal<Params...>
export type ObservedPrioritizedSignalBase<Signature = DefaultSignature> =
	Types.ObservedPrioritizedSignalBase<Signature>
export type ObservedPrioritizedSignal<Params... = ...any> = Types.ObservedPrioritizedSignal<
	Params...
>
export type ConfiguredSignal<Params... = ...any> = Types.ConfiguredSignal<Params...>
export type ChangedSignal<Value = any> = Types.ChangedSignal<Value>
export type AddedSignal<Value = any> = Types.AddedSignal<Value>
export type RemovedSignal<Value = any> = Types.RemovedSignal<Value>
export type ObjectChangedSignal<Property = string, Value = any> = Types.ObjectChangedSignal<
	Property,
	Value
>

--[=[
	@constructor SignalModule.new
	
	옵션 조합에 맞는 Signal 을 생성합니다. 기본은 Deferred 입니다.
]=]
function SignalModule.new(options: Types.SignalOptions?): unknown
	if options == nil then
		return Variants.Deferred.new()
	end

	const dispatch = options.Dispatch or "Deferred"
	if dispatch ~= "Deferred" and dispatch ~= "Immediate" then
		error(`Invalid Signal dispatch "{dispatch}"`, 2)
	end

	const observed = options.Observed
	const isObserved = observed ~= nil and observed ~= false
	const isPrioritized = options.Prioritized == true

	local observedOptions: Types.ObservedSignalOptions? = nil
	if type(observed) == "table" then
		observedOptions = observed
	end

	if isObserved then
		if isPrioritized then
			if dispatch == "Immediate" then
				return Variants.Observed.Prioritized.Immediate.new(observedOptions)
			end

			return Variants.Observed.Prioritized.Deferred.new(observedOptions)
		end

		if dispatch == "Immediate" then
			return Variants.Observed.Immediate.new(observedOptions)
		end

		return Variants.Observed.Deferred.new(observedOptions)
	end

	if isPrioritized then
		if dispatch == "Immediate" then
			return Variants.Prioritized.Immediate.new()
		end

		return Variants.Prioritized.Deferred.new()
	end

	if dispatch == "Immediate" then
		return Variants.Immediate.new()
	end

	return Variants.Deferred.new()
end

--[=[
    @class SignalModule
    
    시그널을 전체적으로 관리하는 모듈입니다.
]=]
type SignalModule = {
	new: (options: Types.SignalOptions?) -> ConfiguredSignal,

	--[=[
        @constructor SignalModule.Deferred.new
        
        `Deferred.new` 를 통해 Deferred Signal 을 생성할 수 있습니다.
    ]=]
	Deferred: { new: () -> Signal },

	--[=[
        @constructor SignalModule.Immediate.new
        
        `Immediate.new` 를 통해 Immediate Signal 을 생성할 수 있습니다.
    ]=]
	Immediate: { new: () -> Signal },

	Observed: {
		--[=[
			@constructor SignalModule.Observed.new
			
			연결 수를 추적하는 Signal 을 생성합니다.
			
			기본은 Deferred 입니다.
			`options` 로 `OnActive`, `OnFirstActive`, `OnInactive` 콜백을 전달할 수 있습니다.
		]=]
		new: (options: Types.ObservedSignalOptions?) -> ObservedSignal,

		--- @constructor SignalModule.Observed.Deferred
		--- 연결 수를 추적하는 Deferred Signal 을 생성합니다.
		Deferred: { new: (options: Types.ObservedSignalOptions?) -> ObservedSignal },

		--- @constructor SignalModule.Observed.Immediate
		--- 연결 수를 추적하는 Immediate Signal 을 생성합니다.
		Immediate: { new: (options: Types.ObservedSignalOptions?) -> ObservedSignal },

		Prioritized: {
			--- @constructor SignalModule.Observed.Prioritized.new
			--- 연결 수를 추적하는 우선순위 기반 Signal 을 생성합니다.
			new: (options: Types.ObservedSignalOptions?) -> ObservedPrioritizedSignal,

			Deferred: {
				--- @constructor SignalModule.Observed.Prioritized.Deferred
				--- 연결 수를 추적하는 우선순위 기반 Deferred Signal 을 생성합니다.
				new: (options: Types.ObservedSignalOptions?) -> ObservedPrioritizedSignal,
			},

			Immediate: {
				--- @constructor SignalModule.Observed.Prioritized.Immediate
				--- 연결 수를 추적하는 우선순위 기반 Immediate Signal 을 생성합니다.
				new: (options: Types.ObservedSignalOptions?) -> ObservedPrioritizedSignal,
			},
		},
	},

	Prioritized: {
		--[=[
			@constructor SignalModule.Prioritized.new

			우선순위 기반 Signal 을 생성합니다.
			
			`Connect(callback, priority)` 계열 메서드는 높은 숫자부터 실행하며,
			같은 우선순위는 먼저 연결된 순서대로 실행합니다.
			기본은 Deferred 입니다.
		]=]
		new: () -> PrioritizedSignal,

		--- @constructor SignalModule.Prioritized.Deferred.new
		--- Deferred Prioritized Signal 을 생성할 수 있습니다.
		Deferred: { new: () -> PrioritizedSignal },

		--- @constructor SignalModule.Prioritized.Immediate.new
		--- Deferred Prioritized Signal 을 생성할 수 있습니다.
		Immediate: { new: () -> PrioritizedSignal },
	},
}

return (SignalModule :: any) :: SignalModule
