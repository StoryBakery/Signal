if task then
	return task
end

local suc, taskModule = pcall(require, "@lute/task")
if suc then
	return taskModule
end

suc, taskModule = pcall(require, "@lune/task")
return if suc then taskModule else error("Unsupported runtime: requires Roblox, Lute, or Lune.")
