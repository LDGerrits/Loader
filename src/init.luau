--!strict

-- Loader

export type ServiceLifecycleFn = (self: Service) -> ()
--[=[
	@within Loader
	@interface Service
	.loaderName string?
	.Init (Service) -> ()
	.Start (Service) -> ()

	Services are simple structures that provide top-level structure,
	as well as lifecycle methods to help safeguard communication
	between each other.
]=]
export type Service = {
	Init: ServiceLifecycleFn?,
	Start: ServiceLifecycleFn?,
	[any]: any,
}

--[=[
	@class Loader

	Loader is a service framework. Services are simple structures that give high-level
	encapsulation of game logic, as well as providing lifecycle methods to help control
	the communication between each other.

	```lua
	local Loader = require(somewhere.Loader)

	-- Add Services:
	for _, module in ipairs(somewhere.Services:GetChildren()) do
		Loader:AddService(module)
	end

	-- Start Loader:
	Loader:Start()
	
	print("Loader started")
	```
]=]
local Loader = {}

Loader._services = {} :: { [string]: Service }
Loader._starting = false :: boolean
Loader._started = false :: boolean
Loader._awaiting = {} :: { thread }

--[=[
	Add a service to Loader.

	```lua
	local MyService = {}

	-- Init is called and completed on all Services before moving
	-- on to Start:
	function MyService:Init()
		print("Prepare MyService here")
	end

	-- Start is called once all Init methods have completed:
	function MyService:Start()
		print("Loader started")
	end

	-- Add the service to Loader:
	Loader:AddService(MyService)
	```

	:::caution Before Start
	Must be called _before_ `Loader:Start()`.
	:::
]=]
function Loader.AddService(self: Loader, serviceModule: ModuleScript): Service
	if self._started or self._starting then
		error("Cannot add Services after Loader has started", 2)
	elseif self._services[serviceModule.Name] ~= nil then
		error("Service already exists", 2)
	end
	local service = require(serviceModule) :: Service
	self._services[serviceModule.Name] = service
	return service
end

--[=[
	@yields
	Starts Loader and yields the current thread until Loader has fully started.

	```lua
	-- [Add Services here before starting]
	Loader:Start()
	print("Loader has started")
	```

	:::caution Call Once
	Can only be called once. Calling more than once will throw an error.
	:::

	:::note Yields Only If Necessary
	If any of the Init functions yield, Loader will yield
	to wait for them to complete. If none yield, then Loader will Start immediately
	without any yield.
	:::
]=]
function Loader.Start(self: Loader)
	if self._started or self._starting then
		error("Loader already started", 2)
	end
	self._starting = true

	local numServices = 0
	for _ in self._services do
		numServices += 1
	end
	local initDone = 0
	local initTries = 0

	-- Call all Init methods:
	local thread = coroutine.running()
	for name: string, service: Service in self._services do
		local init = service.Init
		if typeof(init) == "function" then
			initTries += 1
			task.spawn(function()
				debug.setmemorycategory(name)
				init(service)
				initDone += 1
				if initDone == numServices then
					if coroutine.status(thread) == "suspended" then
						task.spawn(thread)
					end
				end
			end)
		end
	end

	-- Await all Init methods to be completed:
	if initTries ~= initDone then
		coroutine.yield(thread)
	end

	-- Call all Start methods:
	for name: string, service: Service in self._services do
		local start = service.Start
		if typeof(start) == "function" then
			task.spawn(function()
				debug.setmemorycategory(name)
				start(service)
			end)
		end
	end

	-- Resume awaiting threads:
	for _, awaitingThread in ipairs(self._awaiting) do
		task.defer(awaitingThread)
	end

	self._starting = false
	self._started = true
end

--[=[
	@yields
	Yields the current thread until Loader has fully started. If Loader
	has already been started, this function simply does nothing.

	```lua
	Loader:AwaitStart()
	print("Loader has started!")
	```
]=]
function Loader.AwaitStart(self: Loader)
	if self._started then
		return
	end
	table.insert(self._awaiting, coroutine.running())
	coroutine.yield()
end

--[=[
	Calls the callback once Loader has fully started. If Loader has
	already been started, then the callback is immediately called.

	```lua
	Loader:OnStart(function()
		print("Loader has started!")
	end)
	```
]=]
function Loader.OnStart(self: Loader, callback: () -> ())
	if self._started then
		task.spawn(callback)
		return
	end
	local thread = coroutine.create(callback)
	table.insert(self._awaiting, thread)
end

export type Loader = typeof(Loader)

return Loader
