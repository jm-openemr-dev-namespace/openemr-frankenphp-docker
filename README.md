# OpenEMR FrankenPHP/Caddy Experiment

- `openemr-source-code` is a copy of https://github.com/openemr/openemr with [one file](./openemr-source-code/frankenphp-worker.php) added.
- `openemr-devops-source-code` is a copy of https://github.com/openemr/openemr-devops with no changes.
- Both can be found copied to `frankenphp_experiment/openemr` and `frankenphp_experiment/devops` respectively.

The only file added to the source code to make this work is the file [frankenphp-worker.php](./openemr-source-code/frankenphp-worker.php).

This repo demonstrates the running of OpenEMR via the [Caddy](https://github.com/caddyserver/caddy) webserver using the [FrankenPHP](https://github.com/php/frankenphp) `frankenphp:1-php8.3` container.

## How does this container's performance compare to the standard v7.0.4 container?

| Metric | FrankenPHP | Apache 7.0.4 | Delta (%) |
| --- | --- | --- | --- |
| Avg latency (ms) | 84.99 | 110.74 | -23.3% |
| p95 latency (ms) | 211.90 | 347.11 | -39.0% |
| Requests/sec | 172.74 | 165.26 | +4.5% |
| Web tier CPU % | 0.00 | 4.15 | -100.0% |
| Web tier RSS (MiB) | 467.30 | 807.20 | -42.1% |
| MySQL CPU % | 0.01 | 0.26 | -96.2% |
| MySQL RSS (MiB) | 309.80 | 380.70 | -18.6% |

The script used to generate this table can be found [here](./frankenphp_experiment/benchmarking/results/generate_table.py).

Full results can be found [here](./frankenphp_experiment/benchmarking/results). Benchmarking scripts written using [k6](http://github.com/grafana/k6) can be found [here](./frankenphp_experiment/benchmarking/k6-script.js) (NOTE: this script is currently way too simple to be what it should be to properly compare Apache and Caddy and should be improved in the future to really provide good benchmarking abilities) and [here](./frankenphp_experiment/benchmarking/run_benchmarks.sh).

## How can I replicate these results?

1. Clone this repository and change directory into it.
2. Run `COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker build -f frankenphp_experiment/docker/frankenphp/Dockerfile -t openemr/frankenphp-experiment frankenphp_experiment`
3. Run `COMPOSE_PROJECT_NAME=frankenphp-exp docker compose -f frankenphp_experiment/compose/docker-compose.yml up -d`
4. Run `./frankenphp_experiment/benchmarking/run_benchmarks.sh`
5. Navigate to `./frankenphp_experiment/benchmarking/results` and see your results.
6. (Optional) Generate a version of the table seen above based off your most recent results using the [generate_table.py script](./frankenphp_experiment/benchmarking/results/generate_table.py)

## What are the implications vis-a-vis OpenEMR development

I'd say it's too early to say. While the initial findings are promising we need to design better benchmarking than what I have currently to really compare the two.

There's also more that can be done to optimize the FrankenPHP/Caddy container (such as adding additional files to `$preloadCandidates` in [frankenphp-worker.php](./openemr-source-code/frankenphp-worker.php)). 

To fully leverage the capabilities of FrankenPHP we would need to leverage its [worker mode](https://frankenphp.dev/docs/worker/) which would allow us to run OpenEMR loaded into memory using [goroutines](https://go.dev/tour/concurrency/1). However, doing that would involve substantial rewrites to huge parts of the OpenEMR codebase.
