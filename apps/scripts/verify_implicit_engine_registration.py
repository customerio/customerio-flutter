#!/usr/bin/env python3
"""Prove the implicit-engine plugin bootstrap runs exactly once (MBL-2232).

Registering plugins twice on one engine is not a silent bug: `registrarForPlugin:`
asserts on a duplicate key. This script gathers the evidence that the sample apps
register exactly once per implicit engine, at three levels:

  source   the sample's Swift has exactly one `GeneratedPluginRegistrant.register`
           and one permission-channel registration, both inside
           `didInitializeImplicitFlutterEngine`, none at launch;
  wiring   the generated registrant uses one unique registry key per plugin, the
           permission channel adds one more distinct key, and the storyboard
           declares exactly one FlutterViewController, so one launch creates one
           implicit engine;
  product  (with --app) the built binary exposes `didInitializeImplicitFlutterEngine:`
           on the Runner AppDelegate class, so the seat survived compilation and
           `-conformsToProtocol:` can find it through the Customer.io wrapper.

With --flutter-root it also re-reads the pinned engine sources, so a Flutter bump
that changes the once-per-engine semantics fails here instead of being assumed.

This is source/product-shaped evidence. It is not a runtime capture and makes no
`cio-lifecycle-trace/1` evidence-level claim.
"""

from __future__ import annotations

import argparse
import plistlib
import re
import subprocess
import sys
from pathlib import Path

SAMPLES = ("spm", "cocoapods")
BOOTSTRAP = "didInitializeImplicitFlutterEngine"
LAUNCH = "didFinishLaunchingWithOptions"
PERMISSION_KEY = "io.customer.testbed.PermissionChannelHandler"


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def check(self, ok: bool, label: str, detail: str = "") -> None:
        if ok:
            print(f"  ok    {label}{f' -- {detail}' if detail else ''}")
        else:
            print(f"  FAIL  {label}{f' -- {detail}' if detail else ''}")
            self.failures.append(label)


def function_body(source: str, name: str) -> str:
    """Return the matching Swift method, ignoring mentions in comments."""
    declarations = list(re.finditer(r"(?m)^    (?:override )?func ", source))
    for index, declaration in enumerate(declarations):
        start = declaration.start()
        end = declarations[index + 1].start() if index + 1 < len(declarations) else len(source)
        candidate = source[start:end]
        signature_end = candidate.find("{")
        if signature_end >= 0 and name in candidate[:signature_end]:
            return candidate
    return ""


def check_source(repo: Path, sample: str, report: Report) -> None:
    app_delegate = repo / f"apps/flutter_sample_{sample}/ios/Runner/AppDelegate.swift"
    source = app_delegate.read_text(encoding="utf-8")
    bootstrap = function_body(source, BOOTSTRAP)
    launch = function_body(source, LAUNCH)

    registrant_calls = source.count("GeneratedPluginRegistrant.register(")
    permission_calls = source.count("permissionHandler.register(")

    report.check(
        "FlutterImplicitEngineDelegate" in source,
        f"{sample}: AppDelegate adopts FlutterImplicitEngineDelegate",
    )
    report.check(registrant_calls == 1, f"{sample}: one GeneratedPluginRegistrant.register call", f"found {registrant_calls}")
    report.check(permission_calls == 1, f"{sample}: one permission-channel registration", f"found {permission_calls}")
    report.check(
        "GeneratedPluginRegistrant.register(with: registry)" in bootstrap,
        f"{sample}: registration targets engineBridge.pluginRegistry inside {BOOTSTRAP}",
    )
    report.check(
        "permissionHandler.register(with: registrar" in bootstrap,
        f"{sample}: permission channel uses a registrar from the same registry",
    )
    report.check(
        "registry.hasPlugin(" in bootstrap,
        f"{sample}: repeat callback on the same engine is guarded",
    )
    registrar_index = bootstrap.find("registry.registrar(forPlugin:")
    registrant_index = bootstrap.find("GeneratedPluginRegistrant.register(with: registry)")
    permission_index = bootstrap.find("permissionHandler.register(with: registrar")
    report.check(
        0 <= registrar_index < registrant_index < permission_index,
        f"{sample}: permission key is claimed before generated registration",
    )
    report.check(bool(launch), f"{sample}: launch method body was located")
    report.check(
        "GeneratedPluginRegistrant.register(" not in launch
        and re.search(r"\bregister\s*\(", launch) is None,
        f"{sample}: nothing registers at launch",
    )
    report.check(
        "rootViewController" not in launch,
        f"{sample}: no launch-time rootViewController access",
    )


def check_wiring(repo: Path, sample: str, report: Report) -> None:
    ios = repo / f"apps/flutter_sample_{sample}/ios"

    storyboard = (ios / "Runner/Base.lproj/Main.storyboard").read_text(encoding="utf-8")
    controllers = storyboard.count('customClass="FlutterViewController"')
    report.check(
        controllers == 1,
        f"{sample}: storyboard declares one FlutterViewController",
        f"found {controllers}",
    )

    registrant = ios / "Runner/GeneratedPluginRegistrant.m"
    if not registrant.exists():
        report.check(
            False,
            f"{sample}: GeneratedPluginRegistrant.m present",
            "run `flutter pub get` / `flutter build ios --config-only` first",
        )
        return

    keys = re.findall(r'registrarForPlugin:@"([^"]+)"', registrant.read_text(encoding="utf-8"))
    report.check(bool(keys), f"{sample}: generated registrant registers plugins", f"{len(keys)} plugins")
    report.check(
        len(keys) == len(set(keys)),
        f"{sample}: every generated registry key is unique",
        f"{len(keys)} keys, {len(set(keys))} distinct",
    )
    report.check(
        PERMISSION_KEY not in keys,
        f"{sample}: permission-channel key does not collide with a plugin key",
    )


def check_product(app: Path, report: Report) -> None:
    binaries = [p for p in (app / f"{app.stem}.debug.dylib", app / app.stem) if p.exists()]
    if not binaries:
        report.check(False, f"{app.name}: Runner binary present")
        return

    binary = binaries[0]
    symbols = subprocess.run(
        ["nm", "-m", str(binary)], capture_output=True, text=True, check=False
    ).stdout
    # The `To` suffix is the Swift-to-ObjC thunk: without it the runtime cannot
    # deliver the selector the engine sends.
    thunks = [
        line
        for line in symbols.splitlines()
        if "AppDelegateC34didInitializeImplicitFlutterEngine" in line and line.rstrip().endswith("To")
    ]
    report.check(
        len(thunks) == 1,
        f"{app.name}: built AppDelegate exposes {BOOTSTRAP}: to the ObjC runtime",
        f"{len(thunks)} thunk(s)",
    )

    # SwiftPM links CioMessagingPush into Runner.debug.dylib; CocoaPods embeds it
    # as a framework. In both products, verify that the Customer.io wrapper
    # still exposes the two Objective-C forwarding hooks needed for the engine's
    # protocol gate and subsequent delegate message.
    wrapper_framework = app / "Frameworks/CioMessagingPush.framework/CioMessagingPush"
    wrapper_binaries = binaries + ([wrapper_framework] if wrapper_framework.exists() else [])
    wrapper_symbols = "\n".join(
        subprocess.run(
            ["nm", "-m", str(candidate)],
            capture_output=True,
            text=True,
            check=False,
        ).stdout
        for candidate in wrapper_binaries
    )
    conformance_thunks = [
        line
        for line in wrapper_symbols.splitlines()
        if "ProviderAgnosticAppDelegateC8conforms2to" in line
        and line.rstrip().endswith("To")
    ]
    forwarding_thunks = [
        line
        for line in wrapper_symbols.splitlines()
        if "ProviderAgnosticAppDelegateC16forwardingTarget3for" in line
        and line.rstrip().endswith("To")
    ]
    report.check(
        len(conformance_thunks) == 1,
        f"{app.name}: built Customer.io wrapper exposes conforms(to:) to ObjC",
        f"{len(conformance_thunks)} thunk(s)",
    )
    report.check(
        len(forwarding_thunks) == 1,
        f"{app.name}: built Customer.io wrapper exposes forwardingTarget(for:) to ObjC",
        f"{len(forwarding_thunks)} thunk(s)",
    )

    info = plistlib.loads((app / "Info.plist").read_bytes())
    manifest = info.get("UIApplicationSceneManifest")
    if manifest is None:
        report.check(True, f"{app.name}: legacy configuration (no scene manifest)")
    else:
        configs = manifest["UISceneConfigurations"]["UIWindowSceneSessionRoleApplication"]
        delegates = {c.get("UISceneDelegateClassName") for c in configs}
        report.check(
            delegates == {"Runner.LifecycleTraceSceneDelegate"},
            f"{app.name}: scene configuration uses the fixture FlutterSceneDelegate subclass",
            f"{sorted(d for d in delegates if d)}",
        )


def check_engine(flutter_root: Path, report: Report) -> None:
    source = flutter_root / "engine/src/flutter/shell/platform/darwin/ios/framework/Source"
    engine = source / "FlutterEngine.mm"
    controller = source / "FlutterViewController.mm"
    if not engine.exists() or not controller.exists():
        report.check(False, "flutter engine sources available", f"looked in {source}")
        return

    engine_text = engine.read_text(encoding="utf-8")
    controller_text = controller.read_text(encoding="utf-8")

    report.check(
        "NSAssert(self.pluginPublications[pluginKey] == nil, @\"Duplicate plugin key" in engine_text,
        "engine still asserts on a duplicate plugin registry key",
    )
    report.check(
        engine_text.count("didInitializeImplicitFlutterEngine:") == 1,
        "engine invokes the implicit-engine delegate from one place",
    )
    report.check(
        controller_text.count("[_engine performImplicitEngineCallback]") == 1,
        "FlutterViewController performs the implicit-engine callback once per engine",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--app", type=Path, action="append", default=[], help="built Runner.app to inspect (repeatable)")
    parser.add_argument("--flutter-root", type=Path, default=None, help="Flutter SDK checkout with engine sources")
    args = parser.parse_args()

    repo = args.repo_root.resolve()
    report = Report()

    for sample in SAMPLES:
        print(f"[source] flutter_sample_{sample}")
        check_source(repo, sample, report)
        print(f"[wiring] flutter_sample_{sample}")
        check_wiring(repo, sample, report)

    for app in args.app:
        print(f"[product] {app}")
        check_product(app.resolve(), report)

    if args.flutter_root:
        print(f"[engine] {args.flutter_root}")
        check_engine(args.flutter_root.resolve(), report)

    print()
    if report.failures:
        print(f"{len(report.failures)} check(s) failed", file=sys.stderr)
        return 1
    print("all implicit-engine registration checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
