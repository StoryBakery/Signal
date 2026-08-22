const Signal = require("../src")

const testCases = {
	{
		Name = "runs higher-priority unyielding connections first",
		Run = function()
			const signal = Signal.Prioritized.Immediate.new()
			const calls = {}

			signal:ConnectUnyielding(function()
				table.insert(calls, "default")
			end)
			signal:ConnectUnyielding(function()
				table.insert(calls, "high")
			end, 10)
			signal:ConnectUnyielding(function()
				table.insert(calls, "low")
			end, -10)

			signal:Fire()

			assert(table.concat(calls, ",") == "high,default,low")
		end,
	},
	{
		Name = "keeps connection order for equal priorities",
		Run = function()
			const signal = Signal.Prioritized.Immediate.new()
			const calls = {}

			for index = 1, 3 do
				signal:ConnectUnyielding(function()
					table.insert(calls, index)
				end, 5)
			end

			signal:Fire()

			assert(table.concat(calls, ",") == "1,2,3")
		end,
	},
	{
		Name = "applies priority to regular connections",
		Run = function()
			const signal = Signal.Prioritized.Immediate.new()
			const calls = {}

			signal:Connect(function()
				table.insert(calls, "low")
			end, 0)
			signal:Connect(function()
				table.insert(calls, "high")
			end, 10)

			signal:Fire()

			assert(table.concat(calls, ",") == "high,low")
		end,
	},
	{
		Name = "disconnects prioritized connections without breaking order",
		Run = function()
			const signal = Signal.Prioritized.Immediate.new()
			const calls = {}

			signal:ConnectUnyielding(function()
				table.insert(calls, "low")
			end, 0)
			const middleConn = signal:ConnectUnyielding(function()
				table.insert(calls, "middle")
			end, 5)
			signal:ConnectUnyielding(function()
				table.insert(calls, "high")
			end, 10)

			middleConn:Disconnect()
			signal:Fire()

			assert(table.concat(calls, ",") == "high,low")
		end,
	},
	{
		Name = "applies priority to once connections",
		Run = function()
			const signal = Signal.Prioritized.Immediate.new()
			const calls = {}

			signal:OnceUnyielding(function()
				table.insert(calls, "low")
			end, 0)
			signal:OnceUnyielding(function()
				table.insert(calls, "high")
			end, 10)

			signal:Fire()
			signal:Fire()

			assert(table.concat(calls, ",") == "high,low")
		end,
	},
	{
		Name = "preserves regular signal newest-first order",
		Run = function()
			const signal = Signal.Immediate.new()
			const calls = {}

			signal:ConnectUnyielding(function()
				table.insert(calls, "first")
			end)
			signal:ConnectUnyielding(function()
				table.insert(calls, "second")
			end)

			signal:Fire()

			assert(table.concat(calls, ",") == "second,first")
		end,
	},
	{
		Name = "combines observed prioritized immediate behavior",
		Run = function()
			local activeCount = 0
			local inactiveCount = 0
			const calls = {}
			const signal = Signal.Observed.Prioritized.Immediate.new({
				OnActive = function()
					activeCount += 1
					return nil
				end,
				OnInactive = function()
					inactiveCount += 1
				end,
			})

			const lowConn = signal:ConnectUnyielding(function()
				table.insert(calls, "low")
			end, 0)
			const highConn = signal:ConnectUnyielding(function()
				table.insert(calls, "high")
			end, 10)

			assert(activeCount == 1)
			assert(signal:GetConnectionCount() == 2)

			signal:Fire()
			assert(table.concat(calls, ",") == "high,low")

			highConn:Disconnect()
			assert(signal:GetConnectionCount() == 1)
			assert(inactiveCount == 0)

			lowConn:Disconnect()
			assert(signal:GetConnectionCount() == 0)
			assert(inactiveCount == 1)
		end,
	},
	{
		Name = "selects a configured variant once at construction",
		Run = function()
			local activeCount = 0
			local inactiveCount = 0
			const calls = {}
			const signal = Signal.new({
				Dispatch = "Immediate",
				Prioritized = true,
				Observed = {
					OnActive = function()
						activeCount += 1
						return nil
					end,
					OnInactive = function()
						inactiveCount += 1
					end,
				},
			})

			signal:ConnectUnyielding(function()
				table.insert(calls, "low")
			end, 0)
			signal:ConnectUnyielding(function()
				table.insert(calls, "high")
			end, 10)

			signal:Fire()
			assert(table.concat(calls, ",") == "high,low")
			assert(activeCount == 1)

			signal:DisconnectAll()
			assert(inactiveCount == 1)
		end,
	},
}

for _, testCase in testCases do
	testCase.Run()
	print(`PASS: {testCase.Name}`)
end
