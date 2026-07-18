---@class MnrTimestampAPI
local timestamp = {}

function timestamp.unix(value)
	if type(value) ~= 'string' then error(('value must be a string, received "%s"'):format(type(value)), 2) end

	local year, month, day, hour, min, sec = value:match('^(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d)$')

	if not year then
		year, month, day = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
		hour, min, sec = '0', '0', '0'
	end

	if not year then error(('value must be in "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS" format, received "%s"'):format(value), 2) end

	local unix = os.time({ year = tonumber(year) --[[@as integer]], month = tonumber(month) --[[@as integer]], day = tonumber(day) --[[@as integer]], hour = tonumber(hour) --[[@as integer]], min = tonumber(min) --[[@as integer]], sec = tonumber(sec) --[[@as integer]] })

	if not unix then error(('value is not a valid calendar date, received "%s"'):format(value), 2) end

	return unix
end

function timestamp.string(unix, withTime)
	if type(unix) ~= 'number' then error(('timestamp must be a number, received "%s"'):format(type(unix)), 2) end

	local format = withTime == false and '%Y-%m-%d' or '%Y-%m-%d %H:%M:%S'

	return os.date(format, unix) --[[@as string]]
end

return timestamp