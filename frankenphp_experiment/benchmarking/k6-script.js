import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '1m', target: 100 },
    { duration: '1m30s', target: 150 },
    { duration: '1m', target: 150 },
    { duration: '45s', target: 0 },
  ],
};

const baseUrl = __ENV.BASE_URL || 'http://openemr-frankenphp:8080';

export default function () {
  const loginRes = http.get(`${baseUrl}/interface/login/login.php`);
  check(loginRes, {
    'login 200': (r) => r.status === 200,
    'login contains form': (r) => r.body && r.body.includes('OpenEMR Login'),
  });

  sleep(0.5);
}
