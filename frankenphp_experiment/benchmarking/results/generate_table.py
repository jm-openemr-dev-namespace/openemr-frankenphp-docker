#!/usr/bin/env python3
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent

K6_FIELDS = {
    "avg_latency": re.compile(r"http_req_duration.*avg=([0-9.]+)ms"),
    "p95_latency": re.compile(r"http_req_duration.*p\(95\)=([0-9.]+)ms"),
    "reqs_per_sec": re.compile(r"http_reqs.*\s([0-9.]+)/s"),
}

LINE_SPLIT = re.compile(r"\s{2,}")


def parse_k6(path: pathlib.Path):
    data = path.read_text()
    results = {}
    for key, pattern in K6_FIELDS.items():
        match = pattern.search(data)
        if not match:
            raise ValueError(f"Missing {key} in {path}")
        results[key] = float(match.group(1))
    return results


def parse_docker_stats(path: pathlib.Path):
    lines = path.read_text().strip().splitlines()
    if len(lines) < 2:
        raise ValueError(f"Unexpected docker stats format in {path}")

    stats = {}
    for line in lines[1:]:
        parts = LINE_SPLIT.split(line.strip())
        if len(parts) < 4:
            continue
        name = parts[1]
        cpu = float(parts[2].rstrip("%"))
        mem_raw = parts[3].split("/")[0].strip()
        mem = float(mem_raw.rstrip("MiB").rstrip())

        role = "mysql" if "mysql" in name else "web"
        stats[role] = {"cpu": cpu, "mem": mem}

    stats.setdefault("web", {"cpu": 0.0, "mem": 0.0})
    stats.setdefault("mysql", {"cpu": 0.0, "mem": 0.0})
    return stats


def percent_delta(frank, apache):
    if apache == 0:
        return "n/a"
    delta = (frank - apache) / apache * 100
    return f"{delta:+.1f}%"


def main():
    franken_k6 = parse_k6(ROOT / "frankenphp-k6.txt")
    apache_k6 = parse_k6(ROOT / "apache-k6.txt")

    franken_stats = parse_docker_stats(ROOT / "frankenphp-docker-stats.txt")
    apache_stats = parse_docker_stats(ROOT / "apache-docker-stats.txt")

    rows = [
        ("Avg latency (ms)", franken_k6["avg_latency"], apache_k6["avg_latency"]),
        ("p95 latency (ms)", franken_k6["p95_latency"], apache_k6["p95_latency"]),
        ("Requests/sec", franken_k6["reqs_per_sec"], apache_k6["reqs_per_sec"]),
        (
            "Web tier CPU %",
            franken_stats["web"]["cpu"],
            apache_stats["web"]["cpu"],
        ),
        (
            "Web tier RSS (MiB)",
            franken_stats["web"]["mem"],
            apache_stats["web"]["mem"],
        ),
        (
            "MySQL CPU %",
            franken_stats["mysql"]["cpu"],
            apache_stats["mysql"]["cpu"],
        ),
        (
            "MySQL RSS (MiB)",
            franken_stats["mysql"]["mem"],
            apache_stats["mysql"]["mem"],
        ),
    ]

    header = "| Metric | FrankenPHP | Apache 7.0.4 | Delta (%) |"
    sep = "| --- | --- | --- | --- |"
    print(header)
    print(sep)
    for label, frank, apache in rows:
        delta = percent_delta(frank, apache)
        print(f"| {label} | {frank:.2f} | {apache:.2f} | {delta} |")


if __name__ == "__main__":
    main()
