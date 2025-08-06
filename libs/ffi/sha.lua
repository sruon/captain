local ffi = require('ffi')

ffi.cdef [[
    typedef void* HCRYPTPROV;
    typedef void* HCRYPTHASH;
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef const char* LPCSTR;
    typedef char* LPSTR;
    typedef DWORD* LPDWORD;

    static const int PROV_RSA_AES = 24;
    static const int CRYPT_VERIFYCONTEXT = 0xF0000000;
    static const int CALG_SHA_256 = 0x0000800c;
    static const int HP_HASHVAL = 0x0002;
    static const int HP_HASHSIZE = 0x0004;
    static const int CRYPT_STRING_BASE64 = 0x00000001;

    BOOL CryptAcquireContextA(HCRYPTPROV* phProv, LPCSTR szContainer, LPCSTR szProvider, DWORD dwProvType, DWORD dwFlags);
    BOOL CryptReleaseContext(HCRYPTPROV hProv, DWORD dwFlags);
    BOOL CryptCreateHash(HCRYPTPROV hProv, DWORD Algid, HCRYPTHASH hKey, DWORD dwFlags, HCRYPTHASH* phHash);
    BOOL CryptHashData(HCRYPTHASH hHash, const char* pbData, DWORD dwDataLen, DWORD dwFlags);
    BOOL CryptGetHashParam(HCRYPTHASH hHash, DWORD dwParam, char* pbData, LPDWORD pdwDataLen, DWORD dwFlags);
    BOOL CryptDestroyHash(HCRYPTHASH hHash);
    BOOL CryptBinaryToStringA(const char* pbBinary, DWORD cbBinary, DWORD dwFlags, LPSTR pszString, LPDWORD pcchString);
]]

local advapi32 = ffi.load('advapi32')
local crypt32  = ffi.load('crypt32')

local sha_ffi  = {}

---Converts a hexadecimal string to binary string
---@param hex_string string Hexadecimal string (without 0x prefix)
---@return string binary_string Binary representation
function sha_ffi.hex_to_bin(hex_string)
    if not hex_string or hex_string == '' then
        return ''
    end

    hex_string = hex_string:gsub('%s+', ''):upper()
    if #hex_string % 2 ~= 0 then
        hex_string = '0' .. hex_string
    end

    local result = {}
    for i = 1, #hex_string, 2 do
        local hex_byte = hex_string:sub(i, i + 1)
        local byte_val = tonumber(hex_byte, 16)
        if not byte_val then
            error('Invalid hex character in string: ' .. hex_string)
        end
        table.insert(result, string.char(byte_val))
    end

    return table.concat(result)
end

---Converts binary string to base64
---@param binary_string string Binary data
---@return string base64_string Base64 encoded string
function sha_ffi.bin_to_base64(binary_string)
    if not binary_string or binary_string == '' then
        return ''
    end

    local input_len  = #binary_string
    local output_len = ffi.new('DWORD[1]')

    local success    = crypt32.CryptBinaryToStringA(
        binary_string,
        input_len,
        ffi.C.CRYPT_STRING_BASE64,
        nil,
        output_len
    )

    if success == 0 then
        error('Failed to get base64 buffer size')
    end

    local output_buffer = ffi.new('char[?]', output_len[0])
    success             = crypt32.CryptBinaryToStringA(
        binary_string,
        input_len,
        ffi.C.CRYPT_STRING_BASE64,
        output_buffer,
        output_len
    )

    if success == 0 then
        error('Failed to convert to base64')
    end

    local result = ffi.string(output_buffer):gsub('\r?\n', '')
    return result
end

---Computes SHA-256 hash of input message
---@param message string Input message to hash
---@return string hex_hash SHA-256 hash as hexadecimal string
function sha_ffi.sha256(message)
    if not message then
        message = ''
    end

    local hProv   = ffi.new('HCRYPTPROV[1]')
    local hHash   = ffi.new('HCRYPTHASH[1]')

    local success = advapi32.CryptAcquireContextA(
        hProv,
        nil,
        nil,
        ffi.C.PROV_RSA_AES,
        ffi.C.CRYPT_VERIFYCONTEXT
    )

    if success == 0 then
        error('Failed to acquire crypto context')
    end

    success = advapi32.CryptCreateHash(
        hProv[0],
        ffi.C.CALG_SHA_256,
        nil,
        0,
        hHash
    )

    if success == 0 then
        advapi32.CryptReleaseContext(hProv[0], 0)
        error('Failed to create hash object')
    end

    success = advapi32.CryptHashData(
        hHash[0],
        message,
        #message,
        0
    )

    if success == 0 then
        advapi32.CryptDestroyHash(hHash[0])
        advapi32.CryptReleaseContext(hProv[0], 0)
        error('Failed to hash data')
    end

    local hash_size = ffi.new('DWORD[1]')
    local size_len  = ffi.new('DWORD[1]', ffi.sizeof('DWORD'))

    success         = advapi32.CryptGetHashParam(
        hHash[0],
        ffi.C.HP_HASHSIZE,
        ffi.cast('char*', hash_size),
        size_len,
        0
    )

    if success == 0 then
        advapi32.CryptDestroyHash(hHash[0])
        advapi32.CryptReleaseContext(hProv[0], 0)
        error('Failed to get hash size')
    end

    local hash_buffer = ffi.new('char[?]', hash_size[0])
    local hash_len    = ffi.new('DWORD[1]', hash_size[0])

    success           = advapi32.CryptGetHashParam(
        hHash[0],
        ffi.C.HP_HASHVAL,
        hash_buffer,
        hash_len,
        0
    )

    if success == 0 then
        advapi32.CryptDestroyHash(hHash[0])
        advapi32.CryptReleaseContext(hProv[0], 0)
        error('Failed to get hash value')
    end

    advapi32.CryptDestroyHash(hHash[0])
    advapi32.CryptReleaseContext(hProv[0], 0)

    local hex_result  = {}
    local hash_string = ffi.string(hash_buffer, hash_len[0])
    for i = 1, #hash_string do
        table.insert(hex_result, string.format('%02x', string.byte(hash_string, i)))
    end

    return table.concat(hex_result)
end

return sha_ffi
