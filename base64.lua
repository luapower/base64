
--https://github.com/kengonakajima/luvit-base64/issues/1
--http://lua-users.org/wiki/BaseSixtyFour

local base64 = {}

local ffi  = require'ffi'
local bit  = require'bit'
local shl  = bit.lshift
local shr  = bit.rshift
local bor  = bit.bor
local band = bit.band
local u8a  = ffi.typeof'uint8_t[?]'
local u8p  = ffi.typeof'uint8_t*'
local u16a = ffi.typeof'uint16_t[?]'
local u16p = ffi.typeof'uint16_t*'

local b64chars_s = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64chars = u8a(#b64chars_s + 1)
ffi.copy(b64chars, b64chars_s)

local b64digits = u16a(4096)
for j=0,63,1 do
	for k=0,63,1 do
		b64digits[j*64+k] = bor(shl(b64chars[k], 8), b64chars[j])
	end
end

local EQ = string.byte'='

function base64.encode(s, sn, dbuf, dn)

	local sn = sn or #s
	local min_dn = math.ceil(sn / 3) * 4
	local dn = dn or min_dn
	assert(dn >= min_dn, 'buffer too small')
	local dp  = dbuf and ffi.cast(u8p, dbuf) or u8a(dn)
	local sp  = ffi.cast(u8p, s)
	local dpw = ffi.cast(u16p, dp)
	local si = 0
	local di = 0

	while sn > 2 do
		local n = sp[si]
		n = shl(n, 8)
		n = bor(n, sp[si+1])
		n = shl(n, 8)
		n = bor(n, sp[si+2])
		local c1 = shr(n, 12)
		local c2 = band(n, 0x00000fff)
		dpw[di  ] = b64digits[c1]
		dpw[di+1] = b64digits[c2]
		sn = sn - 3
		di = di + 2
		si = si + 3
	end

	di = di * 2

	if sn > 0 then
		local c1 = shr(band(sp[si], 0xfc), 2)
		local c2 = shl(band(sp[si], 0x03), 4)
		if sn > 1 then
			si = si + 1
			c2 = bor(c2, shr(band(sp[si], 0xf0), 4))
		end
		dp[di  ] = b64chars[c1]
		dp[di+1] = b64chars[c2]
		di = di + 2
		if sn == 2 then
			local c3 = shl(band(sp[si], 0xf), 2)
			si = si + 1
			c3 = bor(c3, shr(band(sp[si], 0xc0), 6))
			dp[di] = b64chars[c3]
			di = di + 1
		end
		if sn == 1 then
			dp[di] = EQ
			di = di + 1
		end
		dp[di] = EQ
	end

	if dbuf then
		return dp, dn
	else
		return ffi.string(dp, dn)
	end
end

function base64.decode(s, sn, dbuf, dn)
	s = s:gsub('[^'..b64chars_s..'=]', '')
	return (s:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', b64chars_s:find(x, 1, true)-1
		for i=6,1,-1 do
			r = r .. (f%2^i - f%2^(i-1) > 0 and '1' or '0')
		end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1,8 do
			c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0)
		end
		return string.char(c)
	end))
end

-- https://tools.ietf.org/html/rfc8555 Page 10
-- Binary fields in the JSON objects used by acme are encoded using
-- base64url encoding described in Section 5 of [RFC4648] according to
-- the profile specified in JSON Web Signature in Section 2 of
-- [RFC7515].  This encoding uses a URL safe character set.  Trailing
-- '=' characters MUST be stripped.  Encoded values that include
-- trailing '=' characters MUST be rejected as improperly encoded.
function base64.urlencode(s)
	return b64.encode(s):gsub('/', '_'):gsub('+', '-'):gsub('=*$', '')
end

function base64.urldecode(s)
	return b64.decode(s):gsub('_', '/'):gsub('-', '+'):gsub('=*$', '')
end


if not ... then

	local decode = base64.decode
	local encode = base64.encode

	assert(decode'YW55IGNhcm5hbCBwbGVhc3VyZS4=' == 'any carnal pleasure.')
	assert(decode'YW55IGNhcm5hbCBwbGVhc3VyZQ==' == 'any carnal pleasure')
	assert(decode'YW55IGNhcm5hbCBwbGVhc3Vy' == 'any carnal pleasur')
	assert(decode'YW55IGNhcm5hbCBwbGVhc3U=' == 'any carnal pleasu')
	assert(decode'YW55IGNhcm5hbCBwbGVhcw==' == 'any carnal pleas')
	assert(decode'., ? !@#$%^& \n\r\n\r YW55IGNhcm5hbCBwbGVhcw== \n\r' == 'any carnal pleas')

	assert(encode'any carnal pleasure.' == 'YW55IGNhcm5hbCBwbGVhc3VyZS4=')
	assert(encode'any carnal pleasure' == 'YW55IGNhcm5hbCBwbGVhc3VyZQ==')
	assert(encode'any carnal pleasur' == 'YW55IGNhcm5hbCBwbGVhc3Vy')
	assert(encode'any carnal pleasu' == 'YW55IGNhcm5hbCBwbGVhc3U=')
	assert(encode'any carnal pleas' == 'YW55IGNhcm5hbCBwbGVhcw==')

	assert(decode(encode'') == '')
	assert(decode(encode'x') == 'x')
	assert(decode(encode'xx') == 'xx')
	assert(decode'.!@#$%^&*( \n\r\t' == '')

	local clock = require'time'.clock
	local libb64 = require'libb64'
	local s=''
	for i=1,1000 do s = s .. '0123456789' end
	local n = 50000

	local st = clock()
	local encoded1
	for i=1,n do
		encoded1 = encode(s)
	end
	local et = clock()
	local dt = et - st
	print('Lua len:',#s,'n:',n,dt,'sec', (#s*n)/dt/1024.0/1024.0, 'MB/s' )

	local st = clock()
	local encoded2
	for i=1,n do
		encoded2 = libb64.encode(s)
	end
	local et = clock()
	local dt = et - st
	print('C   len:',#s,'n:',n,dt,'sec', (#s*n)/dt/1024.0/1024.0, 'MB/s' )

	encoded2 = encoded2:gsub('\n', '')
	assert(encoded1 == encoded2)
	assert(decode(encoded1) == s)

	--TODO: rewrite decode with ffi.
	--TODO: benchmark decode.
end


return base64
