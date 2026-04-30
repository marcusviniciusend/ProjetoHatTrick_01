local Logger = {}

function Logger.new(tag: string)
	local prefix = "[" .. tag .. "] "
	return {
		log  = function(msg: string, ...) print((prefix  .. msg):format(...)) end,
		warn = function(msg: string, ...) warn((prefix   .. msg):format(...)) end,
	}
end

return Logger
