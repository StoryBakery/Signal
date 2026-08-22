--[[
	Portions of this file are derived from NamedSignal:
	https://github.com/averlyst/NamedSignal/blob/main/src/Types.luau

	MIT License

	Copyright (c) 2026 Averlyst

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

export type DefaultSignature = (...any) -> ()

type function SignalFireSignature(signature: type): type
	if not signature:is("function") then
		error(`SignalBase<Signature> expects Signature to be a function, got "{signature.tag}"`)
	end

	const parameters = signature:parameters()
	const head = parameters.head
	if head ~= nil then
		table.insert(head, 1, types.any)
	else
		parameters.head = { types.any }
	end

	return types.newfunction(parameters)
end

type function SignalWaitSignature(signature: type): type
	if not signature:is("function") then
		error(`SignalBase<Signature> expects Signature to be a function, got "{signature.tag}"`)
	end

	return types.newfunction({ head = { types.any } }, signature:parameters())
end

--[=[
	@class Connection
	
	[Signal:Connect()] 로 반환되는 연결 객체 타입입니다.  
]=]
export type Connection = {
	--- 연결이 유지 중인지 여부.
	read Connected: boolean,
	--- 연결을 해제합니다.
	read Disconnect: (self: Connection) -> (),
	--- 연결을 해제합니다.
	read Destroy: (self: Connection) -> (),
}

--[=[
	@interface ObservedSignal.ObservedSignalOptions
]=]
export type ObservedSignalOptions = {
	--- 연결 수가 `0 -> 1` 이 될 때 실행됩니다.
	--- 반환값으로 함수를 주면 연결 수가 `1 -> 0` 이 되는 시점에 실행됩니다.
	read OnActive: ((self: any) -> (() -> ())?)?,

	--- 연결 수가 최초 `0 -> 1` 시점에 딱 한 번 실행됩니다.
	--- 반환값으로 함수를 주면 `Destroy` 시점에 실행됩니다.
	read OnFirstActive: ((self: any) -> (() -> ())?)?,

	--- 연결 수가 `1 -> 0` 이 될 때 실행됩니다.
	read OnInactive: ((self: any) -> ())?,
}

--[=[
	@type SignalModule.DispatchMode

	콜백 예약 방식을 선택합니다.
]=]
export type DispatchMode = "Deferred" | "Immediate"

--[=[
	@type SignalModule.SignalOptions

	`Signal.new(options)` 에서 조합할 dispatch, priority, observation 옵션입니다.
]=]
export type SignalOptions = {
	read Dispatch: DispatchMode?,
	read Prioritized: boolean?,
	read Observed: (boolean | ObservedSignalOptions)?,
}

--[=[
	@type SignalModule.SignalBase
	기본 시그널 베이스 타입.
	
	다른 Signal 타입 또한 전부 `SignalBase` 를 통해 만들어진 내장 타입입니다.
	따로 구분된 이유는 자주 사용되는 타입들이기 때문.
	
	@param Signature - 연결되는 콜백 표현 함수
]=]
export type SignalBase<Signature = DefaultSignature> = {

	read IsDestroyed: boolean,

	--[=[
		@method Signal:Connect

		시그널에 콜백 함수를 연결합니다.
		"Fire()" 호출 시 실행되며, 반환된 [Connection]으로 연결을 해제할 수 있습니다.
		
		@param callback Callback
		@return Connection
	]=]
	read Connect: (self: any, callback: Signature) -> Connection,

	--[=[
		@method Signal:ConnectUnyielding

		없이 즉시 실행되는 콜백을 연결합니다.
		Signal에서도 "Fire()" 직후 즉시 실행되며, 콜백이 yield 하면 안 됩니다.
		필요한 로우 레벨 코드에 한해 사용을 권장합니다.
		
		@param unyieldingCallback Callback
		@return Connection
	]=]
	read ConnectUnyielding: (self: any, callback: Signature) -> Connection,

	--[=[
		@method Signal:Once

		한 번만 실행하도록 연결합니다.
		실행된 뒤 연결이 자동으로 해제됩니다.
		
		@param callback Callback
		@return Connection
	]=]
	read Once: (self: any, callback: Signature) -> Connection,

	--[=[
		@method Signal:OnceUnyielding

		한 번만 즉시 실행하도록 연결합니다.
		Signal에서도 "Fire()" 직후 즉시 실행되며, 콜백이 yield 하면 안 됩니다.
		동일한 제약을 따릅니다.
		
		@param unyieldingCallback Callback
		@return Connection
	]=]
	read OnceUnyielding: (self: any, callback: Signature) -> Connection,

	--[=[
		@method Signal:Wait

		"Fire()"될 때까지 대기하고 전달된 매개변수를 반환합니다.
		Destroy된 Signal에서 호출되거나 대기 중 Signal이 Destroy되면 에러가 발생합니다.
		
		@yields
		@return Parameter...
	]=]
	read Wait: SignalWaitSignature<Signature>,

	--[=[
		@method Signal:Fire

		발생시켜 연결된 모든 콜백을 실행합니다.
		매개변수가 그대로 콜백에 전달됩니다.
		
		@param ...Parameter
	]=]
	read Fire: SignalFireSignature<Signature>,

	--[=[
		@method Signal:DisconnectAll

		모든 [Signal.Connection]을 해제합니다.
	]=]
	read DisconnectAll: (self: any) -> (),

	--[=[
		@method Signal:Destroy

		연결을 해제하고 시그널을 파괴합니다.
		[Signal:Connect]로 생성한 [Signal.Connection]은 더 이상 유효하지 않습니다.
	]=]
	read Destroy: (self: any) -> (),
}

type ObservedSignalMethods = {
	--[=[
		@method ObservedSignal.AttachLifecycle

		생성 이후에도 `OnActive`, `OnFirstActive`, `OnInactive` 콜백을 추가합니다.
		기존 콜백 뒤에 순차적으로 실행됩니다.
		최초 관찰 이후 `OnFirstActive` 를 추가하면 즉시 한 번 실행됩니다.

		@param options Signal.ObservedSignalOptions
	]=]
	read AttachLifecycle: (self: any, options: ObservedSignalOptions?) -> (),
	read HasConnections: (self: any) -> boolean,
	read GetConnectionCount: (self: any) -> number,
	read _onActive: (self: any) -> (),
	read _onInactive: (self: any) -> (),
}

--[=[
	@type SignalModule.ObservedSignalBase

	관찰자 수 추적 기능이 포함된 시그널 베이스 타입.
]=]
export type ObservedSignalBase<Signature = DefaultSignature> =
	ObservedSignalMethods
	& SignalBase<Signature>

--[=[
	@type SignalModule.PrioritizedSignalBase

	우선순위에 따라 연결을 실행하는 시그널 베이스 타입.
	높은 숫자가 먼저 실행되며, 같은 우선순위는 먼저 연결된 순서대로 실행됩니다.
]=]
export type PrioritizedSignalBase<Signature = DefaultSignature> = {
	read IsDestroyed: boolean,
	read Connect: (self: any, callback: Signature, priority: number?) -> Connection,
	read ConnectUnyielding: (self: any, callback: Signature, priority: number?) -> Connection,
	read Once: (self: any, callback: Signature, priority: number?) -> Connection,
	read OnceUnyielding: (self: any, callback: Signature, priority: number?) -> Connection,
	read Wait: SignalWaitSignature<Signature>,
	read Fire: SignalFireSignature<Signature>,
	read DisconnectAll: (self: any) -> (),
	read Destroy: (self: any) -> (),
}

--[=[
	@type SignalModule.ObservedPrioritizedSignalBase

	연결 수 추적과 우선순위 실행 기능이 포함된 시그널 베이스 타입.
]=]
export type ObservedPrioritizedSignalBase<Signature = DefaultSignature> =
	ObservedSignalMethods
	& PrioritizedSignalBase<Signature>

export type ConfiguredSignalBase<Signature = DefaultSignature> = PrioritizedSignalBase<Signature>

--[=[
	@type SignalModule.Signal
	
	일반 시그널 타입.
	
	@param Signature - 연결되는 콜백 시그니처.
]=]
export type Signal<Params... = ...any> = SignalBase<(Params...) -> ()>

--[=[
	@type SignalModule.ObservedSignal

	연결 수를 추적하는 시그널 타입.
]=]
export type ObservedSignal<Params... = ...any> = ObservedSignalBase<(Params...) -> ()>

--[=[
	@type SignalModule.PrioritizedSignal

	우선순위에 따라 연결을 실행하는 시그널 타입.
]=]
export type PrioritizedSignal<Params... = ...any> = PrioritizedSignalBase<(Params...) -> ()>

--[=[
	@type SignalModule.ObservedPrioritizedSignal

	연결 수를 추적하며 우선순위에 따라 실행하는 시그널 타입.
]=]
export type ObservedPrioritizedSignal<Params... = ...any> = ObservedPrioritizedSignalBase<
	(Params...) -> ()
>

--[=[
	@type SignalModule.ConfiguredSignal

	`Signal.new(options)` 로 생성한 시그널의 공통 인터페이스 타입.
]=]
export type ConfiguredSignal<Params... = ...any> = ConfiguredSignalBase<(Params...) -> ()>

--[=[
	@type SignalModule.ChangedSignal
	
	변경 시그널 타입.
	
	@param Value - 변경된 값의 타입.
]=]
export type ChangedSignal<Value = any> = Signal<(newValue: Value) -> ()>

--[=[
	@type SignalModule.AddedSignal
	
	추가 시그널 타입.
	
	@param Value - 추가된 값의 타입.
]=]
export type AddedSignal<Value = any> = Signal<(added: Value) -> ()>

--[=[
	@type Signal.RemovedSignal
	
	무언가 제거되었을 때, 제거된 것을 주는 시그널의 타입에 유용합니다.
	
	@param Value - 제거된 값의 타입.
]=]
export type RemovedSignal<Value = any> = Signal<(removed: Value) -> ()>

--[=[
	@type Signal.ObjectChangedSignal
	
	객체의 특정 프로퍼티가 바뀌었을 때 발생하는 시그널입니다.  
	프로퍼티명과 새로운 값을 인자로 전달하는 시그널의 타입에 유용합니다.
	
	```luau
	const objectChangedSignal: Signal.ObjectChangedSignal
	objectChangedSignal:Connect(function(property: string, newValue: any)
		print(property, newValue)
	end)
	
	const explicitObjectChangedSignal: Signal.ObjectChangedSignal<'Name' | 'Pivot', string | CFrame>
	explicitObjectChangedSignal:Connect(function(
		property: 'Name' | 'Pivot', 
		newValue: string | CFrame
	)
		print(property, newValue)
	end)
	```
	
	@param Property - 변경된 프로퍼티 이름의 타입.
	@param Value - 새로운 값의 타입.
]=]
export type ObjectChangedSignal<Property = string, Value = any> = Signal<
	(property: Property, newValue: Value) -> ()
>

const Types = {}

return Types
