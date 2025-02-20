# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2 + 9);

#no_diff();
#no_long_string();
#master_on();
#workers(2);
run_tests();

__DATA__

=== TEST 1: set indexed variables to nil
--- config
    location = /test {
        set $var 32;
        content_by_lua '
            njt.say("old: ", njt.var.var)
            njt.var.var = nil
            njt.say("new: ", njt.var.var)
        ';
    }
--- request
GET /test
--- response_body
old: 32
new: nil



=== TEST 2: set variables with set_handler to nil
--- config
    location = /test {
        content_by_lua '
            njt.say("old: ", njt.var.args)
            njt.var.args = nil
            njt.say("new: ", njt.var.args)
        ';
    }
--- request
GET /test?hello=world
--- response_body
old: hello=world
new: nil



=== TEST 3: reference nonexistent variable
--- config
    location = /test {
        set $var 32;
        content_by_lua '
            njt.say("value: ", njt.var.notfound)
        ';
    }
--- request
GET /test
--- response_body
value: nil



=== TEST 4: no-hash variables
--- config
    location = /test {
        proxy_pass http://127.0.0.1:$server_port/foo;
        header_filter_by_lua '
            njt.header["X-My-Host"] = njt.var.proxy_host
        ';
    }

    location = /foo {
        echo foo;
    }
--- request
GET /test
--- response_headers
X-My-Host: foo
--- response_body
foo
--- SKIP



=== TEST 5: variable name is caseless
--- config
    location = /test {
        set $Var 32;
        content_by_lua '
            njt.say("value: ", njt.var.VAR)
        ';
    }
--- request
GET /test
--- response_body
value: 32



=== TEST 6: true $invalid_referer variable value in Lua
github issue #239
--- config
    location = /t {
        valid_referers www.foo.com;
        content_by_lua '
            njt.say("invalid referer: ", njt.var.invalid_referer)
            njt.exit(200)
        ';
        #echo $invalid_referer;
    }

--- request
GET /t
--- more_headers
Referer: http://www.foo.com/

--- response_body
invalid referer: 

--- no_error_log
[error]



=== TEST 7: false $invalid_referer variable value in Lua
github issue #239
--- config
    location = /t {
        valid_referers www.foo.com;
        content_by_lua '
            njt.say("invalid referer: ", njt.var.invalid_referer)
            njt.exit(200)
        ';
        #echo $invalid_referer;
    }

--- request
GET /t
--- more_headers
Referer: http://www.bar.com

--- response_body
invalid referer: 1

--- no_error_log
[error]



=== TEST 8: $proxy_host & $proxy_port & $proxy_add_x_forwarded_for
--- config
    location = /t {
        proxy_pass http://127.0.0.1:$server_port/back;
        header_filter_by_lua_block {
            njt.header["Proxy-Host"] = njt.var.proxy_host
            njt.header["Proxy-Port"] = njt.var.proxy_port
            njt.header["Proxy-Add-X-Forwarded-For"] = njt.var.proxy_add_x_forwarded_for
        }
    }

    location = /back {
        echo hello;
    }
--- request
GET /t
--- raw_response_headers_like
Proxy-Host: 127.0.0.1\:\d+\r
Proxy-Port: \d+\r
Proxy-Add-X-Forwarded-For: 127.0.0.1\r
--- response_body
hello
--- no_error_log
[error]



=== TEST 9: get a bad variable name
--- config
    location = /test {
        set $true 32;
        content_by_lua '
            njt.say("value: ", njt.var[true])
        ';
    }
--- request
GET /test
--- response_body_like: 500 Internal Server Error
--- error_log
bad variable name
--- error_code: 500



=== TEST 10: set a bad variable name
--- config
    location = /test {
        set $true 32;
        content_by_lua '
            njt.var[true] = 56
        ';
    }
--- request
GET /test
--- response_body_like: 500 Internal Server Error
--- error_log
bad variable name
--- error_code: 500



=== TEST 11: set a variable that is not changeable
--- config
    location = /test {
        content_by_lua '
            njt.var.query_string = 56
        ';
    }
--- request
GET /test?hello
--- response_body_like: 500 Internal Server Error
--- error_log
variable "query_string" not changeable
--- error_code: 500



=== TEST 12: get a variable in balancer_by_lua_block
--- http_config
    upstream balancer {
        server 127.0.0.1;
        balancer_by_lua_block {
            local balancer = require "njt.balancer"
            local host = "127.0.0.1"
            local port = njt.var.port;
            local ok, err = balancer.set_current_peer(host, port)
            if not ok then
                njt.log(njt.ERR, "failed to set the current peer: ", err)
                return njt.exit(500)
            end
        }
    }
    server {
        # this is the real entry point
        listen 8091;
        location / {
            content_by_lua_block{
                njt.print("this is backend peer 8091")
            }
        }
    }
    server {
        # this is the real entry point
        listen 8092;
        location / {
            content_by_lua_block{
                njt.print("this is backend peer 8092")
            }
        }
    }
--- config
    location =/balancer {
        set $port '';
        set_by_lua_block $port {
            local args, _ = njt.req.get_uri_args()
            local port = args['port']
            return port
        }
        proxy_pass http://balancer;
    }
--- pipelined_requests eval
["GET /balancer?port=8091", "GET /balancer?port=8092"]
--- response_body eval
["this is backend peer 8091", "this is backend peer 8092"]
