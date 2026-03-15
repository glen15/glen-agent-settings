#!/bin/bash
# backoff.sh 단위 테스트

source "${PROJECT_DIR}/src/ralph-loop/lib/backoff.sh"

echo "-- detect_rate_limit --"

assert_exit 0 detect_rate_limit "Error: rate limit exceeded"
assert_exit 0 detect_rate_limit "429 Too Many Requests"
assert_exit 0 detect_rate_limit "usage limit reached"
assert_exit 0 detect_rate_limit "Request was throttled"
assert_exit 1 detect_rate_limit "성공적으로 완료"
assert_exit 1 detect_rate_limit ""

echo "-- detect_provider_error --"

assert_exit 0 detect_provider_error "500 Internal Server Error"
assert_exit 0 detect_provider_error "503 Service Unavailable"
assert_exit 0 detect_provider_error "502 Bad Gateway"
assert_exit 0 detect_provider_error "API is overloaded"
assert_exit 1 detect_provider_error "200 OK"
assert_exit 1 detect_provider_error "정상 응답"
