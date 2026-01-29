-- load.lua - Helper to setup package.path for local development

local llay_path = debug.getinfo(1, "S").source:match("@?(.*/)")
if llay_path then
	llay_path = llay_path:gsub("llay/src/load.lua$", "llay/src/")
	package.path = llay_path .. "?.lua;" .. package.path
end

return {
	path = llay_path,
}
