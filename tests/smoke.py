"""Exercise the built image, including the legacy seccomp pwritev2 regression."""

import http.client
import os
import json
import pathlib
import tempfile
import subprocess
import time
import uuid

env = os.environ.copy()
prefix = ['docker']
image = os.environ.get('TEST_IMAGE', 'dynamic-nginx-proxy:test')
profile_dir = tempfile.TemporaryDirectory(prefix='dnp-seccomp-')
security_args = []
if os.environ.get('TEST_DENY_PWRITEV2') == '1':
    # Test-only: isolate the syscall denial reported on older runtimes.
    profile = pathlib.Path(profile_dir.name) / 'deny-pwritev2.json'
    profile.write_text(json.dumps({
        'defaultAction': 'SCMP_ACT_ALLOW',
        'syscalls': [{'names': ['pwritev2'], 'action': 'SCMP_ACT_ERRNO', 'errnoRet': 1}],
    }))
    security_args = ['--security-opt', 'seccomp=' + str(profile)]
    print('Testing with pwritev2 denied (EPERM)', flush=True)
else:
    print('Testing with the default Docker security profile', flush=True)

def docker(*args):
    return subprocess.check_output(prefix + list(args), env=env, text=True, stderr=subprocess.STDOUT).strip()

suffix = uuid.uuid4().hex[:8]
network = 'dnp-test-' + suffix
containers = []

def start(name, *args):
    containers.append(name)
    docker('run', '-d', '--name', name, '--network', network, *security_args, *args)
    return name

def request(name, path):
    port = int(docker('port', name, '8080/tcp').rsplit(':', 1)[1])
    for attempt in range(50):
        try:
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=2)
            conn.request('GET', path)
            response = conn.getresponse()
            result = response.status, response.read().decode(), dict(response.getheaders())
            conn.close()
            return result
        except (OSError, http.client.HTTPException):
            time.sleep(0.1)
    raise AssertionError('Container did not become ready: ' + docker('logs', name))

try:
    docker('network', 'create', network)
    backend = start('dnp-backend-' + suffix, '--network-alias', 'backend', '--entrypoint', 'sh',
        image, '-c',
        '''printf '%s' 'events {} http { server { listen 8080; location / { default_type text/plain; return 200 "uri=$request_uri host=$http_host"; } } }' > /tmp/backend.conf; exec nginx -c /tmp/backend.conf -g 'daemon off;' ''')
    defaults = start('dnp-defaults-' + suffix, '-p', '127.0.0.1::8080', image)
    assert request(defaults, '/')[0] == 404
    docker('exec', defaults, 'nginx', '-t')
    print('PASS default startup and nginx -t')

    settings = {
        'GLOBAL_PORT': '8080', 'GLOBAL_MAX_BODY_SIZE': '50m',
        'GLOBAL_READ_TIMEOUT': '75s', 'GLOBAL_CONNECT_TIMEOUT': '15s', 'DEBUG': 'true',
        'ROUTE_1_PATH': '/api/', 'ROUTE_1_DEST': 'http://backend:8080/',
        'ROUTE_1_HOST': 'service.internal', 'ROUTE_1_TIMEOUT': '12s',
        'ROUTE_2_PATH': '/strip', 'ROUTE_2_DEST': 'http://backend:8080', 'ROUTE_2_STRIP_PREFIX': 'true',
        'ROUTE_3_PATH': '/old', 'ROUTE_3_DEST': 'http://backend:8080', 'ROUTE_3_REWRITE': '^/old/(.*) /v2/$1',
        'ROUTE_4_PATH': '/redirect', 'ROUTE_4_REDIRECT': 'https://example.com/dashboard',
        'ROUTE_5_PATH': '/permanent', 'ROUTE_5_REDIRECT': 'https://example.com/new', 'ROUTE_5_REDIRECT_CODE': '308',
        'ROUTE_6_PATH': '/incomplete',
        'ROUTE_7_PATH': '/v2', 'ROUTE_7_DEST': 'http://backend:8080',
    }
    args = ['-p', '127.0.0.1::8080']
    for key, value in settings.items():
        args += ['-e', key + '=' + value]
    proxy = start('dnp-routes-' + suffix, *args, image)
    status, body, headers = request(proxy, '/api/ping?x=1')
    assert (status, body) == (200, 'uri=/ping?x=1 host=service.internal'), (status, body)
    print('PASS proxy route, query string and Host override')
    status, body, _ = request(proxy, '/strip/ping')
    assert status == 200 and 'uri=/ping ' in body, (status, body)
    status, body, _ = request(proxy, '/old/ping')
    assert status == 200 and 'uri=/v2/ping ' in body, (status, body)
    print('PASS strip-prefix and rewrite')
    for path, code, target in [('/redirect', 302, 'https://example.com/dashboard'), ('/permanent', 308, 'https://example.com/new')]:
        status, _, headers = request(proxy, path)
        assert status == code and headers['Location'] == target, (status, headers)
    assert request(proxy, '/incomplete')[0] == 404
    print('PASS default/custom redirects and incomplete route handling')
    config = docker('exec', proxy, 'nginx', '-T')
    for line in ('client_max_body_size 50m;', 'proxy_read_timeout 75s;', 'proxy_connect_timeout 15s;', 'proxy_read_timeout 12s;'):
        assert line in config, line
    assert '===== Generated configuration =====' in docker('logs', proxy)
    print('PASS nginx -T, global/per-route settings and debug output')

    custom = start('dnp-port-' + suffix, '-e', 'GLOBAL_PORT=9090',
        '-e', 'ROUTE_1_PATH=/', '-e', 'ROUTE_1_REDIRECT=https://example.com/', image)
    for attempt in range(50):
        try:
            config = docker('exec', custom, 'nginx', '-T')
            assert 'listen 9090;' in config
            break
        except (subprocess.CalledProcessError, AssertionError):
            time.sleep(0.1)
    else:
        raise AssertionError('custom port config failed')
    print('PASS custom listen port')
    print(docker('exec', proxy, 'nginx', '-v'))
    print(docker('exec', proxy, 'cat', '/etc/os-release'))
except Exception:
    for name in containers:
        try:
            print(name + ': ' + docker('logs', name))
        except subprocess.CalledProcessError:
            pass
    raise
finally:
    for name in reversed(containers):
        subprocess.run(prefix + ['rm', '-f', name], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(prefix + ['network', 'rm', network], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    profile_dir.cleanup()
