Config = {}
local configString = LoadResourceFile(GetCurrentResourceName(), "config.json")
if(configString ~= nil or configString ~= '') then
   Config.data = json.decode(configString)
end
Config.print = function(text) -- custom print function
end