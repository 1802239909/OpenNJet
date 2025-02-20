# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (3 * blocks() + 6);

#no_diff();
no_long_string();

run_tests();

__DATA__

=== TEST 1: clear cookie (with existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", nil)
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- more_headers
Cookie: foo=bar
Cookie: baz=blah

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 2
content: cookies: 0

--- response_body
Cookie foo: 
Cookie baz: 
Cookie: 

--- no_error_log
[error]



=== TEST 2: clear cookie (without existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", nil)
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 0
content: cookies: 0

--- response_body
Cookie foo: 
Cookie baz: 
Cookie: 

--- no_error_log
[error]



=== TEST 3: set one custom cookie (with existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", "boo=123")
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- more_headers
Cookie: foo=bar
Cookie: baz=blah

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 2
content: cookies: 1

--- response_body
Cookie foo: 
Cookie baz: 
Cookie boo: 123
Cookie: boo=123

--- no_error_log
[error]



=== TEST 4: set one custom cookie (without existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", "boo=123")
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 0
content: cookies: 1

--- response_body
Cookie foo: 
Cookie baz: 
Cookie boo: 123
Cookie: boo=123

--- no_error_log
[error]



=== TEST 5: set multiple custom cookies (with existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", {"boo=123","foo=78"})
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- more_headers
Cookie: foo=bar
Cookie: baz=blah

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 2
content: cookies: 2

--- response_body
Cookie foo: 78
Cookie baz: 
Cookie boo: 123
Cookie: boo=123; foo=78

--- no_error_log
[error]



=== TEST 6: set multiple custom cookies (without existing cookies)
--- config
    location /t {
        rewrite_by_lua '
           njt.req.set_header("Cookie", {"boo=123", "foo=bar"})
        ';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t

--- stap
F(njt_http_lua_rewrite_by_chunk) {
    printf("rewrite: cookies: %d\n", $r->headers_in->cookies->nelts)
}

F(njt_http_core_content_phase) {
    printf("content: cookies: %d\n", $r->headers_in->cookies->nelts)
}

--- stap_out
rewrite: cookies: 0
content: cookies: 2

--- response_body
Cookie foo: bar
Cookie baz: 
Cookie boo: 123
Cookie: boo=123; foo=bar

--- no_error_log
[error]



=== TEST 7: set multiple custom cookies with unsafe values (with '\n' and 'r')
--- config
    location /t {
        rewrite_by_lua_block {
           njt.req.set_header("Cookie", {"boo=123\nfoo", "foo=bar\rbar"})
        }
        echo "Cookie foo: $cookie_foo";
        echo "Cookie baz: $cookie_baz";
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- response_body
Cookie foo: bar%0Dbar
Cookie baz: 
Cookie boo: 123%0Afoo
Cookie: boo=123%0Afoo; foo=bar%0Dbar
--- no_error_log
[error]
