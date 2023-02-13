return function(name: string)
	name = name or ""
	local symbol = newproxy(true)
	getmetatable(symbol).__tostring = function()
		return "Symbol<" .. name .. ">"
	end
	return symbol
end
