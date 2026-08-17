#!/usr/bin/env python3
"""Build, launch, bind provenance, and validate one Flutter lifecycle capture."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import time
import uuid
from typing import Any

FIXTURE_DIR = Path(__file__).resolve().parent
if str(FIXTURE_DIR) not in sys.path:
    sys.path.insert(0, str(FIXTURE_DIR))
from dependency_content_snapshot import SnapshotError, content_snapshot


TRACE_PREFIX = "CIO-LIFECYCLE-TRACE "
CONTRACT_TOOL = Path("scripts/ios27_lifecycle_contract.py")
VALIDATOR = Path("docs/dev-notes/validate_ios27_lifecycle_trace.py")
UUID_KEYS = ("MANIFEST_ID", "RUN_ID", "STREAM_ID", "DART_STREAM_ID", "PROCESS_INSTANCE_ID")


class CaptureError(RuntimeError):
    pass


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _run(arguments: list[str], *, cwd: Path, environment: dict[str, str] | None = None) -> str:
    try:
        completed = subprocess.run(
            arguments,
            cwd=cwd,
            env=environment,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise CaptureError(f"command failed: {' '.join(arguments)}\n{getattr(error, 'stdout', '')}") from error
    return completed.stdout.strip()


def _run_allow_failure(arguments: list[str], *, cwd: Path) -> None:
    try:
        subprocess.run(
            arguments,
            cwd=cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError as error:
        raise CaptureError(f"command could not start: {' '.join(arguments)}") from error


def _load_object(path: Path, description: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise CaptureError(f"missing {description}: {path.name}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CaptureError(f"invalid {description}: {path.name}") from error
    if not isinstance(value, dict):
        raise CaptureError(f"{description} must be an object")
    return value


def _records(path: Path, expected: dict[str, Any]) -> list[dict[str, Any]]:
    if path.is_symlink() or not path.is_file():
        raise CaptureError(f"missing trace: {path.name}")
    records = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.startswith(TRACE_PREFIX):
            raise CaptureError(f"{path.name} line {number} lacks canonical prefix")
        try:
            record = json.loads(line.removeprefix(TRACE_PREFIX))
        except json.JSONDecodeError as error:
            raise CaptureError(f"{path.name} line {number} is invalid JSON") from error
        for key, value in expected.items():
            if record.get(key) != value:
                raise CaptureError(f"{path.name} line {number} has mismatched {key}")
        records.append(record)
    if not records:
        raise CaptureError(f"empty trace: {path.name}")
    return records


def _receipt(path: Path, records: list[dict[str, Any]]) -> dict[str, Any]:
    receipt = _load_object(path, "post-drain receipt")
    if receipt.get("dropped_records_total") != 0 or receipt.get("alias_overflow") is not False:
        raise CaptureError(f"receipt reports drops or overflow: {path.name}")
    if receipt.get("emitted_records") != len(records):
        raise CaptureError(f"receipt count does not match trace: {path.name}")
    if receipt.get("last_assigned_sequence") != records[-1].get("sequence"):
        raise CaptureError(f"receipt last sequence does not match trace: {path.name}")
    return receipt


def _bind_streams(
    swift_path: Path,
    dart_path: Path,
    identifiers: dict[str, str],
    launched_pid: int,
    evidence_level: str = "L2",
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, Any], dict[str, Any]]:
    common = {
        "manifest_id": identifiers["MANIFEST_ID"],
        "run_id": identifiers["RUN_ID"],
        "scenario": "icon-cold-launch",
        "evidence_level": evidence_level,
        "integration": "flutter",
        "provider": "none",
    }
    swift_records = _records(
        swift_path,
        {**common, "stream_id": identifiers["STREAM_ID"], "runtime": "swift"},
    )
    dart_records = _records(
        dart_path,
        {**common, "stream_id": identifiers["DART_STREAM_ID"], "runtime": "dart"},
    )
    swift_receipt = _receipt(Path(str(swift_path) + ".receipt.json"), swift_records)
    dart_receipt = _receipt(Path(str(dart_path) + ".receipt.json"), dart_records)
    for record in [*swift_records, *dart_records]:
        occurrence = (record.get("correlation") or {}).get("occurrence")
        if record.get("kind") == "trace-control":
            if occurrence is not None:
                raise CaptureError("trace-control records must not carry an occurrence alias")
        elif evidence_level in ("L2", "L3") and occurrence != "occurrence-1":
            raise CaptureError("L2/L3 runtime records must carry occurrence-1")
    if {record.get("process_id") for record in [*swift_records, *dart_records]} != {launched_pid}:
        raise CaptureError("streams do not bind to the launched process_id")
    return swift_records, dart_records, swift_receipt, dart_receipt


def _host_topology(mode: str) -> str:
    if mode == "legacy":
        return "app-delegate-only"
    if mode == "scene":
        return "ui-scene"
    raise CaptureError(f"unsupported lifecycle mode: {mode}")


def _content_snapshot(
    root: Path,
    hash_overrides: dict[str, str] | None = None,
) -> dict[str, Any]:
    helper = FIXTURE_DIR / "dependency_content_snapshot.py"
    if helper.is_symlink() or not helper.is_file():
        raise CaptureError("dependency snapshot helper is unsafe")
    try:
        return content_snapshot(root, hash_overrides)
    except (OSError, SnapshotError) as error:
        raise CaptureError(str(error)) from error


def _dependency_provenance(source_root: Path, derived_data: Path, sample: str) -> tuple[str, dict[str, Any]]:
    if sample == "spm":
        state = _load_object(
            derived_data / "SourcePackages/workspace-state.json",
            "SwiftPM workspace state",
        )
        dependencies = state.get("object", {}).get("dependencies", [])
        revision = None
        for dependency in dependencies:
            package = dependency.get("packageRef", {})
            if package.get("identity") == "customerio-ios":
                revision = dependency.get("state", {}).get("checkoutState", {}).get("revision")
                break
        if revision != "5903eaddd88638d37f7204b737dc0faf07d7d3dc":
            raise CaptureError("SwiftPM Customer.io revision is not the pinned 4.7.2 commit")
        dependency_root = derived_data / "SourcePackages/checkouts/customerio-ios"
    else:
        lock = source_root / "apps/flutter_sample_cocoapods/ios/Podfile.lock"
        if lock.is_symlink() or not lock.is_file() or "CustomerIOMessagingPushFCM (4.7.2)" not in lock.read_text(encoding="utf-8"):
            raise CaptureError("CocoaPods Customer.io version is not pinned to 4.7.2")
        revision = "5903eaddd88638d37f7204b737dc0faf07d7d3dc"
        dependency_root = source_root / "apps/flutter_sample_cocoapods/ios/Pods/CustomerIOMessagingPushFCM"
    source = (
        dependency_root / "Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
        if sample == "spm"
        else dependency_root / "Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
    )
    source_relative = source.relative_to(dependency_root).as_posix()
    if source.is_symlink() or not source.is_file():
        raise CaptureError("built Customer.io dependency source is unsafe")
    if sample == "spm":
        if hashlib.sha256(source.read_bytes()).hexdigest() != "b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176":
            raise CaptureError("built Customer.io dependency lacks the exact fixture patch")
        return revision, _content_snapshot(dependency_root)
    if hashlib.sha256(source.read_bytes()).hexdigest() != "f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8":
        raise CaptureError("CocoaPods Customer.io source was not restored after the build")
    receipt = _load_object(
        derived_data / "cio-lifecycle-dependency-instrumentation.json",
        "CocoaPods instrumentation receipt",
    )
    expected_receipt = {
        "original_sha256": "f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8",
        "patch_sha256": "f213e7a51dc2eb59c9dbb21d33e32d42d967530933597b1abb06fcdbc2010195",
        "patched_sha256": "b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176",
        "restored_sha256": "f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8",
    }
    if set(receipt) != {*expected_receipt, "patched_tree_sha256"} or any(
        receipt.get(key) != value for key, value in expected_receipt.items()
    ) or re.fullmatch(r"[0-9a-f]{64}", str(receipt.get("patched_tree_sha256"))) is None:
        raise CaptureError("CocoaPods instrumentation receipt does not bind the compiled patch")
    snapshot = _content_snapshot(
        dependency_root,
        {source_relative: expected_receipt["patched_sha256"]},
    )
    if snapshot["tree_hash"] != receipt["patched_tree_sha256"]:
        raise CaptureError("CocoaPods dependency tree changed after the instrumented build")
    return revision, snapshot


def _snapshot(root: Path) -> tuple[bool, dict[str, Any] | None]:
    resolved_root = root.resolve()
    status = _run(["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=root)
    if not status:
        return False, None
    listed = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout.split(b"\0")
    untracked_output = subprocess.run(
        ["git", "ls-files", "-z", "--others", "--exclude-standard"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    untracked = {
        value.decode("utf-8") for value in untracked_output.split(b"\0") if value
    }
    listed_paths = {
        value.decode("utf-8") for value in listed if value
    }
    tree = hashlib.sha256()
    untracked_digest = hashlib.sha256()
    for raw in sorted(value for value in listed if value):
        relative = raw.decode("utf-8")
        path = root / relative
        if path.is_symlink():
            if relative in untracked:
                raise CaptureError(f"unsafe untracked source snapshot symlink: {relative}")
            target_text = os.readlink(path)
            target = (path.parent / target_text).resolve()
            try:
                target_relative = target.relative_to(resolved_root).as_posix()
            except ValueError as error:
                raise CaptureError(f"unsafe source snapshot symlink: {relative}") from error
            target_is_listed_file = target_relative in listed_paths and target.is_file()
            target_has_listed_descendants = target.is_dir() and any(
                candidate.startswith(f"{target_relative}/") for candidate in listed_paths
            )
            if not target_is_listed_file and not target_has_listed_descendants:
                raise CaptureError(f"unsafe source snapshot symlink: {relative}")
            content = b"symlink\0" + target_text.encode("utf-8")
        elif path.is_file():
            content = path.read_bytes()
        else:
            raise CaptureError(f"unsafe source snapshot path: {relative}")
        entry = f"{hashlib.sha256(content).hexdigest()}  {relative}\n".encode()
        tree.update(entry)
        if relative in untracked:
            untracked_digest.update(entry)
    diff = subprocess.run(
        ["git", "diff", "--binary", "--no-ext-diff", "HEAD", "--"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    combined_diff = hashlib.sha256(
        diff + b"\0UNTRACKED\0" + untracked_digest.digest()
    ).hexdigest()
    return True, {
        "algorithm": "sha256",
        "tree_hash": tree.hexdigest(),
        "diff_hash": combined_diff,
        "ignored_build_inputs_excluded": True,
    }


def _require_stable_source(
    before_commit: str,
    before_dirty: bool,
    before_snapshot: dict[str, Any] | None,
    after_commit: str,
    after_dirty: bool,
    after_snapshot: dict[str, Any] | None,
) -> None:
    if (
        before_commit != after_commit
        or before_dirty != after_dirty
        or before_snapshot != after_snapshot
    ):
        raise CaptureError("source checkout changed during capture")


def _toolchain(root: Path, flutter: Path) -> dict[str, Any]:
    flutter_json = json.loads(_run([str(flutter), "--version", "--machine"], cwd=root))
    xcode = _run(["xcodebuild", "-version"], cwd=root).splitlines()
    swift = _run(["xcrun", "swift", "--version"], cwd=root)
    swift_match = re.search(r"Swift version ([0-9A-Za-z.+_-]+)", swift)
    if len(xcode) != 2 or swift_match is None:
        raise CaptureError("unexpected Apple toolchain version output")
    if flutter_json.get("frameworkVersion") != "3.44.8" or flutter_json.get("dartSdkVersion") != "3.12.2":
        raise CaptureError("capture requires exact Flutter 3.44.8 / Dart 3.12.2")
    return {
        "xcode_version": xcode[0].removeprefix("Xcode "),
        "xcode_build": xcode[1].removeprefix("Build version "),
        "swift_version": swift_match.group(1),
        "flutter_version": flutter_json["frameworkVersion"],
        "dart_version": flutter_json["dartSdkVersion"],
        "node_version": None,
        "expo_cli_version": None,
    }


def _target(root: Path, simulator_id: str) -> dict[str, str]:
    devices = json.loads(_run(["xcrun", "simctl", "list", "-j", "devices", "available"], cwd=root))["devices"]
    runtimes = json.loads(_run(["xcrun", "simctl", "list", "-j", "runtimes"], cwd=root))["runtimes"]
    runtime_by_id = {item["identifier"]: item for item in runtimes}
    for runtime_id, candidates in devices.items():
        for device in candidates:
            if device.get("udid") == simulator_id:
                if device.get("state") != "Booted":
                    raise CaptureError("selected simulator must already be Booted")
                runtime = runtime_by_id[runtime_id]
                return {
                    "kind": "simulator",
                    "model": device["name"],
                    "architecture": platform.machine(),
                    "os_name": "iOS",
                    "os_version": runtime["version"],
                    "os_build": runtime["buildversion"],
                }
    raise CaptureError("selected simulator is unavailable")


def _validate_capture(validator_python: str, validator: Path, manifest: Path, traces: list[Path], root: Path) -> None:
    output = _run([validator_python, str(validator), str(manifest), *map(str, traces)], cwd=root)
    expected = f"VALID: {manifest} with 2 stream(s)"
    if output != expected:
        raise CaptureError("canonical validator returned unexpected output")


def _verify_contract(validator_python: str, root: Path) -> Path:
    tool = root / CONTRACT_TOOL
    validator = root / VALIDATOR
    if tool.is_symlink() or not tool.is_file() or validator.is_symlink() or not validator.is_file():
        raise CaptureError("canonical contract tool or validator is unsafe")
    output = _run([validator_python, str(tool), "verify", "--root", str(root)], cwd=root)
    if output != f"verified 18 canonical files under {root}":
        raise CaptureError("canonical contract verification returned unexpected output")
    return validator


def _wait_for_files(paths: list[Path], timeout: float) -> None:
    def complete(path: Path) -> tuple[int, int, str] | None:
        if path.is_symlink() or not path.is_file():
            return None
        try:
            before = path.stat()
            content = path.read_bytes()
            after = path.stat()
            if (
                not content
                or not content.endswith(b"\n")
                or before.st_size != after.st_size
                or before.st_mtime_ns != after.st_mtime_ns
            ):
                return None
            if path.name.endswith(".receipt.json"):
                payload = json.loads(content)
                if not isinstance(payload, dict):
                    return None
            return after.st_size, after.st_mtime_ns, hashlib.sha256(content).hexdigest()
        except (OSError, UnicodeError, json.JSONDecodeError):
            return None

    deadline = time.monotonic() + timeout
    previous: dict[Path, tuple[int, int, str]] | None = None
    while time.monotonic() < deadline:
        observed = {path: complete(path) for path in paths}
        if all(signature is not None for signature in observed.values()):
            stable = {path: signature for path, signature in observed.items() if signature is not None}
            if stable == previous:
                return
            previous = stable
        else:
            previous = None
        time.sleep(0.05)
    incomplete = ", ".join(path.name for path in paths if complete(path) is None)
    if not incomplete:
        incomplete = "unstable capture files"
    raise CaptureError(f"capture timed out waiting for complete files: {incomplete}")


def _stimulus_configuration(mode: str) -> tuple[str, str]:
    if mode == "manual-app-icon":
        return "L2", "app-icon"
    if mode == "simctl-diagnostic":
        return "diagnostic", "simulator-control"
    raise CaptureError("unsupported stimulus mode")


def _set_simulator_environment(
    root: Path,
    simulator_id: str,
    values: dict[str, str],
) -> list[str]:
    configured: list[str] = []
    try:
        for key, value in values.items():
            existing = subprocess.run(
                ["xcrun", "simctl", "spawn", simulator_id, "launchctl", "getenv", key],
                cwd=root,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            if existing.returncode == 0 and existing.stdout.strip():
                raise CaptureError(f"simulator launch environment already defines {key}")
            _run(
                ["xcrun", "simctl", "spawn", simulator_id, "launchctl", "setenv", key, value],
                cwd=root,
            )
            configured.append(key)
    except BaseException as error:
        _cleanup_simulator_environment_after_error(
            root, simulator_id, configured, error
        )
        raise
    return configured


def _clear_simulator_environment(root: Path, simulator_id: str, keys: list[str]) -> None:
    failures = []
    for key in reversed(keys):
        unset_arguments = [
            "xcrun", "simctl", "spawn", simulator_id, "launchctl", "unsetenv", key
        ]
        verify_arguments = [
            "xcrun", "simctl", "spawn", simulator_id, "launchctl", "getenv", key
        ]
        try:
            unset = subprocess.run(
                unset_arguments,
                cwd=root,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            if unset.returncode != 0:
                failures.append(f"{key} unsetenv exited {unset.returncode}")
        except OSError:
            failures.append(f"{key} unsetenv could not start")
        try:
            verified = subprocess.run(
                verify_arguments,
                cwd=root,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            if verified.returncode != 0:
                failures.append(f"{key} getenv exited {verified.returncode}")
            elif verified.stdout.strip():
                failures.append(f"{key} remained set")
        except OSError:
            failures.append(f"{key} getenv could not start")
    if failures:
        raise CaptureError("simulator environment cleanup failed: " + "; ".join(failures))


def _cleanup_simulator_environment_after_error(
    root: Path,
    simulator_id: str,
    keys: list[str],
    primary_error: BaseException,
) -> None:
    try:
        _clear_simulator_environment(root, simulator_id, keys)
    except CaptureError as cleanup_error:
        raise CaptureError(
            f"{primary_error}; additionally, {cleanup_error}"
        ) from primary_error


def _initiate_stimulus(
    mode: str,
    root: Path,
    simulator_id: str,
    bundle: str,
    injected: dict[str, str],
) -> tuple[int | None, list[str], str]:
    if mode == "manual-app-icon":
        keys = _set_simulator_environment(root, simulator_id, injected)
        try:
            if _simulator_process_ids(root, simulator_id, bundle):
                raise CaptureError("manual app-icon target was already running before READY")
            print(
                f"READY: press Enter only when ready to tap the {bundle} Home Screen icon "
                f"on simulator {simulator_id}",
                file=sys.stderr,
                flush=True,
            )
            if sys.stdin.readline() not in {"\n", "\r\n"}:
                raise CaptureError("manual app-icon stimulus was not confirmed with Enter")
            initiated_at = _timestamp()
            print("TAP NOW", file=sys.stderr, flush=True)
        except BaseException as error:
            _cleanup_simulator_environment_after_error(
                root, simulator_id, keys, error
            )
            raise
        return None, keys, initiated_at
    if mode != "simctl-diagnostic":
        raise CaptureError("unsupported stimulus mode")
    environment = os.environ.copy()
    environment.update({f"SIMCTL_CHILD_{key}": value for key, value in injected.items()})
    initiated_at = _timestamp()
    launch = _run(
        ["xcrun", "simctl", "launch", "--terminate-running-process", simulator_id, bundle],
        cwd=root,
        environment=environment,
    )
    match = re.fullmatch(re.escape(bundle) + r": ([1-9][0-9]*)", launch)
    if match is None:
        raise CaptureError("simctl launch returned an unexpected process result")
    return int(match.group(1)), [], initiated_at


def _simulator_process_ids(root: Path, simulator_id: str, bundle: str) -> list[int]:
    output = _run(
        ["xcrun", "simctl", "spawn", simulator_id, "launchctl", "list"],
        cwd=root,
    )
    process_ids = []
    for line in output.splitlines():
        columns = line.split()
        if (
            len(columns) >= 3
            and columns[0].isdigit()
            and int(columns[0]) > 0
            and columns[2].startswith(f"UIKitApplication:{bundle}[")
        ):
            process_ids.append(int(columns[0]))
    return process_ids


def _observed_process_id(swift_path: Path, identifiers: dict[str, str], evidence_level: str) -> int:
    records = _records(
        swift_path,
        {
            "manifest_id": identifiers["MANIFEST_ID"],
            "run_id": identifiers["RUN_ID"],
            "stream_id": identifiers["STREAM_ID"],
            "scenario": "icon-cold-launch",
            "evidence_level": evidence_level,
            "integration": "flutter",
            "runtime": "swift",
            "provider": "none",
        },
    )
    process_ids = {record.get("process_id") for record in records}
    if len(process_ids) != 1:
        raise CaptureError("Swift stream does not identify exactly one process_id")
    process_id = process_ids.pop()
    if not isinstance(process_id, int) or process_id <= 0:
        raise CaptureError("Swift stream has an invalid process_id")
    return process_id


def _await_stimulus_capture(
    mode: str,
    root: Path,
    simulator_id: str,
    bundle: str,
    injected: dict[str, str],
    paths: list[Path],
    timeout: float,
) -> tuple[int | None, str]:
    configured_keys: list[str] = []
    primary_error: BaseException | None = None
    managed_signals = (signal.SIGHUP, signal.SIGTERM)
    previous_handlers: dict[signal.Signals, Any] = {}

    def interrupt(signum: int, _frame: Any) -> None:
        for managed in managed_signals:
            signal.signal(managed, signal.SIG_IGN)
        raise CaptureError(
            f"manual app-icon capture interrupted by {signal.Signals(signum).name}"
        )

    try:
        if mode == "manual-app-icon":
            previous_handlers = {
                managed: signal.getsignal(managed) for managed in managed_signals
            }
            for managed in managed_signals:
                signal.signal(managed, interrupt)
        launched_pid, configured_keys, initiated_at = _initiate_stimulus(
            mode,
            root,
            simulator_id,
            bundle,
            injected,
        )
        _wait_for_files(paths, timeout)
        return launched_pid, initiated_at
    except BaseException as error:
        primary_error = error
        raise
    finally:
        if previous_handlers:
            for managed in managed_signals:
                signal.signal(managed, signal.SIG_IGN)
        try:
            try:
                _clear_simulator_environment(root, simulator_id, configured_keys)
            except CaptureError as cleanup_error:
                if primary_error is not None:
                    raise CaptureError(
                        f"{primary_error}; additionally, {cleanup_error}"
                    ) from primary_error
                raise
        finally:
            for managed, previous in previous_handlers.items():
                signal.signal(managed, previous)


def capture(arguments: argparse.Namespace) -> None:
    source_root = arguments.source_root.resolve()
    output = arguments.output_dir.resolve()
    if arguments.source_root.is_symlink() or _run(["git", "rev-parse", "--show-toplevel"], cwd=source_root) != str(source_root):
        raise CaptureError("source-root must be a non-symlink Git checkout root")
    if output.exists() or output == source_root or source_root in output.parents:
        raise CaptureError("output-dir must not exist and must be outside source-root")
    output.mkdir(parents=True)
    if arguments.mode not in {"legacy", "scene"} or arguments.sample not in {"spm", "cocoapods"}:
        raise CaptureError("unsupported capture configuration")
    if not os.environ.get("DEVELOPER_DIR"):
        raise CaptureError("DEVELOPER_DIR must be set before Flutter dependency generation")

    evidence_level, stimulus_source = _stimulus_configuration(arguments.stimulus_mode)
    commit = _run(["git", "rev-parse", "HEAD"], cwd=source_root)
    root_dirty, root_snapshot = _snapshot(source_root)
    identifiers = {key: str(uuid.uuid4()) for key in UUID_KEYS}
    dart_basename = f"lifecycle-dart-{identifiers['RUN_ID']}.ndjson"
    build_environment = os.environ.copy()
    build_environment.update({
        "FLUTTER": str(arguments.flutter),
        "CIO_LIFECYCLE_DART_OUTPUT_BASENAME": dart_basename,
        **{f"CIO_LIFECYCLE_{key}": value for key, value in identifiers.items()},
        "CIO_LIFECYCLE_SCENARIO": "icon-cold-launch",
        "CIO_LIFECYCLE_EVIDENCE_LEVEL": evidence_level,
        "CIO_LIFECYCLE_INTEGRATION": "flutter",
        "CIO_LIFECYCLE_PROVIDER": "none",
    })
    derived_data = output / "DerivedData"
    build_script = source_root / "apps/scripts/lifecycle_fixture_build.sh"
    _run([str(build_script), arguments.mode, arguments.sample, str(derived_data)], cwd=source_root, environment=build_environment)

    app = derived_data / "Build/Products/Debug-iphonesimulator/Runner.app"
    bundle = f"io.customer.testbed.flutter.{arguments.sample}"
    _run_allow_failure(["xcrun", "simctl", "terminate", arguments.simulator_id, bundle], cwd=source_root)
    _run_allow_failure(["xcrun", "simctl", "uninstall", arguments.simulator_id, bundle], cwd=source_root)
    _run(["xcrun", "simctl", "install", arguments.simulator_id, str(app)], cwd=source_root)
    container = Path(_run(["xcrun", "simctl", "get_app_container", arguments.simulator_id, bundle, "data"], cwd=source_root))
    swift_path = container / "Documents/lifecycle-swift.ndjson"
    dart_path = container / "tmp" / dart_basename
    injected = {
        "CIO_LIFECYCLE_MANIFEST_ID": identifiers["MANIFEST_ID"],
        "CIO_LIFECYCLE_RUN_ID": identifiers["RUN_ID"],
        "CIO_LIFECYCLE_STREAM_ID": identifiers["STREAM_ID"],
        "CIO_LIFECYCLE_PROCESS_INSTANCE_ID": identifiers["PROCESS_INSTANCE_ID"],
        "CIO_LIFECYCLE_SCENARIO": "icon-cold-launch",
        "CIO_LIFECYCLE_EVIDENCE_LEVEL": evidence_level,
        "CIO_LIFECYCLE_INTEGRATION": "flutter",
        "CIO_LIFECYCLE_RUNTIME": "swift",
        "CIO_LIFECYCLE_PROVIDER": "none",
        "CIO_LIFECYCLE_OUTPUT_PATH": str(swift_path),
    }
    started_at = _timestamp()
    stimulus_initiated_at = started_at
    launched_pid: int | None = None
    launched_pid, stimulus_initiated_at = _await_stimulus_capture(
        arguments.stimulus_mode,
        source_root,
        arguments.simulator_id,
        bundle,
        injected,
        [
            swift_path,
            Path(str(swift_path) + ".receipt.json"),
            dart_path,
            Path(str(dart_path) + ".receipt.json"),
        ],
        arguments.timeout,
    )
    ended_at = _timestamp()

    if launched_pid is None:
        launched_pid = _observed_process_id(swift_path, identifiers, evidence_level)

    _, _, swift_receipt, dart_receipt = _bind_streams(
        swift_path, dart_path, identifiers, launched_pid, evidence_level
    )

    copied_swift = output / "swift.ndjson"
    copied_dart = output / "dart.ndjson"
    copied_swift.write_bytes(swift_path.read_bytes())
    copied_dart.write_bytes(dart_path.read_bytes())
    (output / "swift.ndjson.receipt.json").write_bytes(
        Path(str(swift_path) + ".receipt.json").read_bytes()
    )
    (output / "dart.ndjson.receipt.json").write_bytes(
        Path(str(dart_path) + ".receipt.json").read_bytes()
    )
    final_commit = _run(["git", "rev-parse", "HEAD"], cwd=source_root)
    final_dirty, final_snapshot = _snapshot(source_root)
    _require_stable_source(
        commit,
        root_dirty,
        root_snapshot,
        final_commit,
        final_dirty,
        final_snapshot,
    )
    sdk_version = _run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], cwd=source_root)
    sdk_build = _run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-build-version"], cwd=source_root)
    target = _target(source_root, arguments.simulator_id)
    dependency_commit, dependency_snapshot = _dependency_provenance(
        source_root, derived_data, arguments.sample
    )
    manifest_path = output / "manifest.json"
    manifest = {
        "schema": "cio-lifecycle-capture-manifest/1",
        "manifest_id": identifiers["MANIFEST_ID"],
        "run_id": identifiers["RUN_ID"],
        "run_started_at": started_at,
        "run_ended_at": ended_at,
        "created_at": _timestamp(),
        "evidence_level": evidence_level,
        "scenario": "icon-cold-launch",
        "host_topology": _host_topology(arguments.mode),
        "repositories": [
            {"name": "customerio-flutter", "commit_sha": commit, "dirty": root_dirty, "source_snapshot": root_snapshot},
            {"name": "customerio-ios", "commit_sha": dependency_commit, "dirty": True, "source_snapshot": dependency_snapshot},
        ],
        "toolchain": _toolchain(source_root, arguments.flutter),
        "sdk": {"platform": "ios", "name": "iphonesimulator", "version": sdk_version, "build": sdk_build},
        "build": {"configuration": "Debug", "scheme": "Runner", "target_name": "Runner", "product_kind": "application", "deployment_target": "15.0"},
        "target": target,
        "frameworks": [
            {"name": "customerio-ios", "role": "sdk", "version": "4.7.2", "commit_sha": dependency_commit},
            {"name": "customerio-flutter", "role": "wrapper", "version": "4.2.1", "commit_sha": commit},
            {"name": "flutter", "role": "runtime", "version": "3.44.8", "commit_sha": None},
            {"name": "apple-usernotifications", "role": "platform-framework", "version": sdk_version, "commit_sha": None},
        ],
        "provider_provenance": {"provider": "none", "source": "none", "environment": "none", "receipt_result": "not-applicable", "receipt_recorded_at": None, "provider_sdk": None},
        "stimulus": {"scenario": "icon-cold-launch", "source": stimulus_source, "initiated_at": stimulus_initiated_at},
        "streams": [
            {"stream_id": identifiers["STREAM_ID"], "integration": "flutter", "runtime": "swift", "provider": "none", "process_id": launched_pid, "process_instance_id": identifiers["PROCESS_INSTANCE_ID"], "receipt": swift_receipt},
            {"stream_id": identifiers["DART_STREAM_ID"], "integration": "flutter", "runtime": "dart", "provider": "none", "process_id": launched_pid, "process_instance_id": identifiers["PROCESS_INSTANCE_ID"], "receipt": dart_receipt},
        ],
        "aggregate_assertions": [{
            "name": "icon-launch-runtime-handoff",
            "relation": "equal-exact-count",
            "expected_count": 1,
            "members": [
                {"stream_id": identifiers["STREAM_ID"], "callback": "flutter.application.did-finish-launching-forwarded", "phase": "entry"},
                {"stream_id": identifiers["DART_STREAM_ID"], "callback": "flutter.dart-main-entered", "phase": "entry"},
            ],
        }],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    validator = _verify_contract(arguments.validator_python, source_root)
    _validate_capture(arguments.validator_python, validator, manifest_path, [copied_swift, copied_dart], source_root)
    print(f"validated Flutter lifecycle capture: {manifest_path}")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--simulator-id", required=True)
    parser.add_argument("--mode", choices=("legacy", "scene"), required=True)
    parser.add_argument("--sample", choices=("spm", "cocoapods"), required=True)
    parser.add_argument(
        "--stimulus-mode",
        choices=("manual-app-icon", "simctl-diagnostic"),
        required=True,
        help="manual-app-icon is the only L2 path; simctl-diagnostic cannot claim app-icon evidence",
    )
    parser.add_argument("--flutter", type=Path, required=True)
    parser.add_argument("--validator-python", default=sys.executable)
    parser.add_argument("--timeout", type=float, default=20.0)
    return parser


def main() -> int:
    try:
        capture(_parser().parse_args())
    except (CaptureError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
