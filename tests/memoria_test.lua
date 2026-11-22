-- luajit tests/memoria_test.lua, from the repository's root.
package.path = './?.lua;' .. package.path
package.preload['backend.backend'] = function()
    return {}
end
local memoria = require('core.memoria')

-- 2026-11-03 07:21:00 UTC, which is 00:21 in America/Denver.
local t = 1793690460
assert(memoria.sessionName(nil, t) == '2026-11-3_7_21Z', memoria.sessionName(nil, t))
assert(memoria.sessionName({}, t) == '2026-11-3_7_21Z')
assert(memoria.sessionName({ 'pilot', 'Firemarshal' }, t) == 'pilot_Firemarshal_2026-11-3_7_21Z')
print('ok')
