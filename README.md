[![CI](https://github.com/Sleitnick/Loader/actions/workflows/ci.yaml/badge.svg)](https://github.com/Sleitnick/Loader/actions/workflows/ci.yaml)
[![CD](https://github.com/Sleitnick/Loader/actions/workflows/cd.yaml/badge.svg)](https://github.com/Sleitnick/Loader/actions/workflows/cd.yaml)
[![Docs](https://github.com/Sleitnick/Loader/actions/workflows/docs.yaml/badge.svg)](https://github.com/Sleitnick/Loader/actions/workflows/docs.yaml)

# Loader

Loader is a service framework for the Roblox ecosystem.

## Service Example

Services are simply tables with a name and a couple lifecycle methods.

```lua
local MyService = {}

function MyService.Init(self: MyService)
	print("Initialized the service")
end

function MyService.Start(self: MyService)
	print("Started")
end

return MyService
```

Services must be explicitly added into Loader via `Loader:AddService()`. Once all services are added, `Loader:Start()` will kick off the lifecycle methods of the services.

A script to bootstrap Loader might look like this:

```lua
local Loader = require(somewhere.Loader)

for _, module in ipairs(somewhere.MyServiceModules:GetChildren()) do
	Loader:AddService(service)
end

Loader:Start()
```

## Using multiple services

Because services are just tables, it is easy for one service to use another. Simply get a reference to the other service (e.g. requiring its ModuleScript) and then access it after Start has fired. For example:

```lua
local MyService = require(somewhere.MyService) -- Grab the other service

local AnotherService = {}

function AnotherService.Init(self: AnotherService)
	-- Other services are NOT safe to use here, because there's no guarantee
	-- that they have all been initialized yet. Wait until Start.
end

function AnotherService.Start(self: AnotherService)
	-- Other services are safe to use once the Start method fires.
	MyService:DoSomething()
end
```

## Memory categories

Because Loader services are started from one source, the default memory label within the Developer Console will appear the same for all services. To solve this, Loader will automatically assign a memory category based on the service's name.

When MyService is initialized/started, any memory usage will show up within the MyService label in the Developer Console memory section.
