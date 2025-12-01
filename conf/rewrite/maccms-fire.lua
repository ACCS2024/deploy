local args = ngx.req.get_uri_args()

if args['os'] then
 local handle = io.popen("dotnet")
local result = handle:read("*a")
handle:close()

ngx.say(result)
end