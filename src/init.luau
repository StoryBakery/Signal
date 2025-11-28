--[=[ 
	@class Signal
	
	시그널을 생성하고 사용할 수 있는 인터페이스를 제공합니다.
	로블록스 RBXScriptSignal 과 비슷한 사용감을 목표로 합니다. 
]=]

local DeferredSignal = require("./Deferred")
local ImmediateSignal = require("./Immediate")


local Signal = {}
Signal.Deferred = DeferredSignal
Signal.Immediate = ImmediateSignal

--#region Types

--[=[
	@interface Connection
	@within Signal
	
	`Connect()`로 반환되는 연결 객체 타입입니다.  
	`Disconnect()` 혹은 `Destroy()` 로 연결을 해제할 수 있습니다.
	
	.Connected boolean -- 연결이 유지 중인지 여부
	.Disconnect (self: Connection) -> () -- 연결을 해제합니다.
	.Destroy (self: Connection) -> () -- `Disconnect` 와 동일하게 연결을 해제합니다.
]=]
export type Connection = {
	Disconnect: (self: any) -> (),
	Destroy: (self: any) -> (),
}

--[=[
	@type SignalBase Signal
	@within Signal
	기본 시그널 베이스 타입.
	
	다른 Signal 타입 또한 전부 `SignalBase` 를 통해 만들어진 내장 타입입니다.
	따로 구분된 이유는 자주 사용되는 타입들이기 때문.
	
	Callback: 연결되는 콜백 타입. 기본값은 `(...any) -> ()` 입니다.
	Parameter...: 시그널이 전달하는 매개변수 타입. 기본값은 `...any` 입니다.
]=]
export type SignalBase<Callback = (...any)->(), Parameter... = ...any> = {
	IsDestroyed: boolean,
	Connect: (self: any, callback: Callback)->Connection,
	ConnectUnyielding: (self: any, unyieldingCallback: Callback)->Connection,
	Once: (self: any, callback: Callback)->Connection,
	OnceUnyielding: (self: any, unyieldingCallback: Callback)->Connection,
	Wait: (self: any)->(Parameter...),
	Fire: (self: any, Parameter...)->(),
	DisconnectAll: (self: any)->(),
	Destroy: (self: any)->(),
}



--[=[
	@type Signal Signal
	@within Signal
	
	일반 시그널 타입.
	
	Parameter...: 시그널이 전달하는 매개변수 타입. 기본값은 `...any` 입니다.
]=]
export type Signal<Parameter... = ...any> = SignalBase<(Parameter...)->(), Parameter...>

--[=[
	@type ChangedSignal Signal
	@within Signal
	
	변경 시그널 타입.
	
	Parameter: 변경된 값의 타입. 기본값은 `any` 입니다.
]=]
export type ChangedSignal<Parameter = any> = SignalBase<(new: Parameter)->(), Parameter>

--[=[
	@type AddedSignal Signal
	@within Signal
	
	추가 시그널 타입.
	
	Parameter: 추가된 값의 타입. 기본값은 `any` 입니다.
]=]
export type AddedSignal<Parameter = any> = SignalBase<(added: Parameter)->(), Parameter>

--[=[
	@type RemovedSignal Signal
	@within Signal
	
	무언가 제거되었을 때, 제거된 것을 주는 시그널의 타입에 유용합니다.
	
	Parameter: 제거된 값의 타입. 기본값은 `any` 입니다.
]=]
export type RemovedSignal<Parameter = any> = SignalBase<(removed: Parameter)->(), Parameter>

--[=[
	@type ObjectChangedSignal Signal
	@within Signal
	
	객체의 특정 프로퍼티가 바뀌었을 때 발생하는 시그널입니다.  
	프로퍼티명과 새로운 값을 인자로 전달하는 시그널의 타입에 유용합니다.
	
	Property: 변경된 프로퍼티 이름의 타입. 기본값은 `string` 입니다.
	Parameter: 새로운 값의 타입. 기본값은 `any` 입니다.
]=]
export type ObjectChangedSignal<Property = string, Parameter = any> =
	SignalBase<(property: Property, new: Parameter)->(), Parameter>


--[[
	.new fun(): Signal -- 환경에 따라 Deferred/Immediate 중 하나를 생성 (기본은 Deferred)
	.Deferred { new: ()-> Signal }
	.Immediate { new: ()-> Signal } 
]]
type SignalModule = {
	new: ()->(Signal),
	Deferred: { new: ()->(Signal) },
	Immediate: { new: ()->(Signal) },
}
--#endregion Types

--#region Method Doc Comments


--[=[
	@method Connect
	@within Signal

	시그널에 콜백 함수를 연결합니다.
	"Fire()" 호출 시 실행되며, 반환된 [Connection]으로 연결을 해제할 수 있습니다.
	
	@param callback Callback
	@return Connection
]=]

--[=[
	@method ConnectUnyielding
	@within Signal

	없이 즉시 실행되는 콜백을 연결합니다.
	Signal에서도 "Fire()" 직후 즉시 실행되며, 콜백이 yield 하면 안 됩니다.
	필요한 로우 레벨 코드에 한해 사용을 권장합니다.
	
	@param unyieldingCallback Callback
	@return Connection
]=]

--[=[
	@method Once
	@within Signal

	한 번만 실행하도록 연결합니다.
	실행된 뒤 연결이 자동으로 해제됩니다.
	
	@param callback Callback
	@return Connection
]=]


--[=[
	@method OnceUnyielding
	@within Signal

	한 번만 즉시 실행하도록 연결합니다.
	Signal에서도 "Fire()" 직후 즉시 실행되며, 콜백이 yield 하면 안 됩니다.
	동일한 제약을 따릅니다.
	
	@param unyieldingCallback Callback
	@return Connection
]=]


--[=[
	@method Wait
	@within Signal

	"Fire()"될 때까지 대기하고 전달된 매개변수를 반환합니다.
	
	@yields
	@return Parameter...
]=]


--[=[
	@method Fire
	@within Signal

	발생시켜 연결된 모든 콜백을 실행합니다.
	매개변수가 그대로 콜백에 전달됩니다.
	
	@param ... Parameter
]=]


--[=[
	@method DisconnectAll
	@within Signal

	모든 [Signal.Connection]을 해제합니다.
]=]


--[=[
	@method Destroy
	@within Signal

	연결을 해제하고 시그널을 파괴합니다.
	[Signal:Connect]로 생성한 [Signal.Connection]은 더 이상 유효하지 않습니다.
]=]



--#endregion Method Doc Comments


function Signal.new()
	return DeferredSignal.new()
end

return (Signal :: any) :: SignalModule
