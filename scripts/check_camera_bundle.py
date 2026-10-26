#!/usr/bin/env python3
"""Check the signed camera extension's macOS registration contract before packaging."""
import plistlib
import subprocess
import sys
from pathlib import Path


def check(app: Path) -> list[str]:
    failures = []
    extensions = list((app / "Contents/Library/SystemExtensions").glob("*.systemextension"))
    if len(extensions) != 1:
        return ["Expected exactly one bundled camera extension"]
    extension = extensions[0]
    info = plistlib.loads((extension / "Contents/Info.plist").read_bytes())
    result = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(extension)], capture_output=True)
    if result.returncode:
        return ["Camera extension is not signed"]
    entitlements = plistlib.loads(result.stdout)
    service = info.get("CMIOExtension", {}).get("CMIOExtensionMachServiceName", "")
    groups = entitlements.get("com.apple.security.application-groups", [])
    if not service or not any(service == group or service.startswith(group + ".") for group in groups):
        failures.append("Camera Mach service must be prefixed by an App Group in the SIGNED extension entitlements")
    if entitlements.get("com.apple.security.app-sandbox") is not True:
        failures.append("Camera extension must be sandboxed")
    if "$" in service or any("$" in group for group in groups):
        failures.append("Unexpanded build variable in camera registration identifiers")
    return failures


if __name__ == "__main__":
    problems = check(Path(sys.argv[1]))
    if problems:
        for problem in problems:
            print("FAIL:", problem)
        sys.exit(1)
    print("PASS: signed camera extension has a valid App Group / Mach service registration")
