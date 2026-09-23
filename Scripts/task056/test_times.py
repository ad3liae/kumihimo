#!/usr/bin/env python3
"""Task 056: read how long each test took out of an .xcresult.

    python3 Scripts/task056/test_times.py <bundle.xcresult> [--top 25] [--compare <other.xcresult>]

Prints three figures and a table:

- the sum of every test's own duration (Swift Testing and XCTest alike),
- the test phase (the summary's finish time minus its start time),
- the counts (passed, failed, skipped),

then the slowest tests with their running share of the sum. A parameterised
test is counted once, as the sum of its arguments, since that is what running
it costs; the table says how many arguments it has.

**Do not read a parameterised test's own `durationInSeconds`.** For a test
with arguments the result bundle puts about the *average* of its arguments
there, not their sum (Task 056: 44.7 s of argument runs showed as 12.7 s).
Summing the node figures therefore leaves some 30 s of test time looking as
if it were spent outside the tests.

With --compare, the same tests are looked up in the second bundle and both
durations are shown side by side.
"""

import argparse
import json
import subprocess


def xcresult(path, *what):
    out = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", *what, "--path", path],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def cases(path):
    """(suite, test, seconds, arguments, result) for every test case."""
    found = []

    def walk(node, suite):
        kind = node.get("nodeType")
        if kind == "Test Suite":
            suite = node["name"]
        if kind == "Test Case":
            arguments = [c for c in node.get("children", [])
                         if c.get("nodeType") == "Arguments"]
            seconds = (sum(c.get("durationInSeconds", 0.0) for c in arguments)
                       if arguments else node.get("durationInSeconds", 0.0))
            found.append((suite, node["name"], seconds,
                          len(arguments), node.get("result")))
            return
        for child in node.get("children", []):
            walk(child, suite)

    for root in xcresult(path, "tests")["testNodes"]:
        walk(root, None)
    return found


def suites_span(path):
    """(launch, in suites, after) in seconds, from the action log.

    launch: from the start of the test action to the first suite starting,
    which is installing and launching the test host. in suites: first suite
    start to last suite end. after: from there to the end of the action.
    """
    log = json.loads(subprocess.run(
        ["xcrun", "xcresulttool", "get", "log", "--type", "action", "--path", path],
        check=True, capture_output=True, text=True,
    ).stdout)
    spans = []

    def walk(node):
        title = node.get("title", "")
        if title.startswith("Run test suite ") and title not in (
                "Run test suite All tests", "Run test suite Selected tests"):
            spans.append((node["startTime"], node["startTime"] + node["duration"]))
            return
        for child in node.get("subsections", []):
            walk(child)

    walk(log)
    if not spans:
        return None
    start = log["startTime"]
    end = start + log["duration"]
    first = min(s for s, _ in spans)
    last = max(e for _, e in spans)
    return first - start, last - first, end - last


def summary(path):
    s = xcresult(path, "summary")
    return {
        "phase": s["finishTime"] - s["startTime"],
        "passed": s["passedTests"],
        "failed": s["failedTests"],
        "skipped": s["skippedTests"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle")
    parser.add_argument("--top", type=int, default=25)
    parser.add_argument("--compare")
    args = parser.parse_args()

    found = cases(args.bundle)
    total = sum(c[2] for c in found)
    s = summary(args.bundle)
    print(f"bundle: {args.bundle}")
    print(f"tests: {len(found)} cases; passed {s['passed']}, failed {s['failed']}, "
          f"skipped {s['skipped']}")
    print(f"sum of each test's own time: {total:.1f} s")
    print(f"test phase (finish - start): {s['phase']:.1f} s")
    print(f"outside the tests: {s['phase'] - total:.1f} s")
    span = suites_span(args.bundle)
    if span:
        launch, inside, after = span
        print(f"  of the action: launch to first suite {launch:.1f} s, "
              f"first suite to last {inside:.1f} s "
              f"(of which between tests {inside - total:.1f} s), after {after:.1f} s")
    print()

    other = {}
    if args.compare:
        other = {(c[0], c[1]): c[2] for c in cases(args.compare)}

    ranked = sorted(found, key=lambda c: -c[2])
    running = 0.0
    header = "| # | s | cum | suite | test |"
    if other:
        header = "| # | s | other s | cum | suite | test |"
    print(header)
    print("|" + " --- |" * (header.count("|") - 1))
    for rank, (suite, name, seconds, arguments, result) in enumerate(ranked[:args.top], 1):
        running += seconds
        label = name + (f" ×{arguments}" if arguments else "")
        if result != "Passed":
            label += f" [{result}]"
        if other:
            then = other.get((suite, name))
            then_text = f"{then:.2f}" if then is not None else "–"
            print(f"| {rank} | {seconds:.2f} | {then_text} | {100 * running / total:.1f}% "
                  f"| {suite} | {label} |")
        else:
            print(f"| {rank} | {seconds:.2f} | {100 * running / total:.1f}% "
                  f"| {suite} | {label} |")


if __name__ == "__main__":
    main()
