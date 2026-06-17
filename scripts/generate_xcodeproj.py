#!/usr/bin/env python3
"""Generate a valid Prisma.xcodeproj from source files."""

from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRISMA_DIR = ROOT / "Prisma"
TESTS_DIR = ROOT / "PrismaTests"
PROJECT_DIR = ROOT / "Prisma.xcodeproj"


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


class XcodeProject:
    def __init__(self) -> None:
        self.objects: dict[str, dict] = {}
        self.root_id = self.add_project()
        self.main_group_id = new_id()
        self.products_group_id = new_id()
        self.app_product_id = new_id()
        self.test_product_id = new_id()
        self.app_target_id = new_id()
        self.test_target_id = new_id()
        self.app_sources_phase = new_id()
        self.app_resources_phase = new_id()
        self.app_frameworks_phase = new_id()
        self.test_sources_phase = new_id()
        self.test_frameworks_phase = new_id()
        self.app_config_list = new_id()
        self.test_config_list = new_id()
        self.project_config_list = new_id()

        self.app_source_files: list[str] = []
        self.test_source_files: list[str] = []
        self.resource_files: list[str] = []

    def add(self, obj_id: str, body: dict) -> str:
        self.objects[obj_id] = body
        return obj_id

    def add_project(self) -> str:
        pid = new_id()
        self.project_id = pid
        return pid

    def add_file_ref(self, path: Path, file_type: str) -> str:
        fid = new_id()
        self.add(fid, {
            "isa": "PBXFileReference",
            "lastKnownFileType": file_type,
            "path": path.name,
            "sourceTree": '"<group>"',
        })
        return fid

    def add_group(self, name: str, children: list[str], path: str | None = None) -> str:
        gid = new_id()
        body: dict = {
            "isa": "PBXGroup",
            "children": children,
            "sourceTree": '"<group>"',
        }
        if path is not None:
            body["path"] = path
        else:
            body["name"] = name
        self.add(gid, body)
        return gid

    def add_build_file(self, file_ref: str, name: str, phase: str) -> str:
        bid = new_id()
        self.add(bid, {
            "isa": "PBXBuildFile",
            "fileRef": file_ref,
        })
        if phase == "sources":
            self.app_source_files.append(bid) if name.endswith(".swift") and "Tests" not in name else None
        return bid

    def build_group_tree(self, base: Path) -> str:
        """Recursively mirror directory structure as PBXGroups."""
        children: list[str] = []

        for item in sorted(base.iterdir()):
            if item.name.startswith("."):
                continue
            if item.is_dir() and item.suffix == ".xcassets":
                ref = self.add_file_ref(item, "folder.assetcatalog")
                children.append(ref)
                self.resource_files.append(ref)
                continue
            if item.is_dir():
                children.append(self.build_group_tree(item))
                continue
            if item.suffix == ".swift":
                ref = self.add_file_ref(item, "sourcecode.swift")
                bid = new_id()
                self.add(bid, {"isa": "PBXBuildFile", "fileRef": ref})
                if base.parts[-1] == "PrismaTests" or "PrismaTests" in item.parts:
                    self.test_source_files.append(bid)
                else:
                    self.app_source_files.append(bid)
                children.append(ref)
                continue
            if item.suffix in {".json", ".xcstrings"}:
                ftype = "text.json.xcstrings" if item.suffix == ".xcstrings" else "text.json"
                ref = self.add_file_ref(item, ftype)
                bid = new_id()
                self.add(bid, {"isa": "PBXBuildFile", "fileRef": ref})
                self.resource_files.append(bid)
                children.append(ref)
                continue
            if item.suffix == ".storekit":
                ref = self.add_file_ref(item, "text")
                children.append(ref)
                continue

        return self.add_group(base.name, children, path=base.name)

    def write(self) -> None:
        prisma_group = self.build_group_tree(PRISMA_DIR)

        # PrismaTests (only top-level swift + subdirs)
        test_children: list[str] = []
        for item in sorted(TESTS_DIR.rglob("*.swift")):
            rel_parent = item.parent
        test_group = self.build_group_tree(TESTS_DIR)

        products_group = self.add_group("Products", [self.app_product_id, self.test_product_id])
        main_group = self.add_group("", [prisma_group, test_group, products_group])

        self.add(self.app_product_id, {
            "isa": "PBXFileReference",
            "explicitFileType": "wrapper.application",
            "includeInIndex": 0,
            "path": "Prisma.app",
            "sourceTree": "BUILT_PRODUCTS_DIR",
        })
        self.add(self.test_product_id, {
            "isa": "PBXFileReference",
            "explicitFileType": "wrapper.cfbundle",
            "includeInIndex": 0,
            "path": "PrismaTests.xctest",
            "sourceTree": "BUILT_PRODUCTS_DIR",
        })

        self.add(self.app_sources_phase, {
            "isa": "PBXSourcesBuildPhase",
            "buildActionMask": 2147483647,
            "files": self.app_source_files,
            "runOnlyForDeploymentPostprocessing": 0,
        })
        self.add(self.test_sources_phase, {
            "isa": "PBXSourcesBuildPhase",
            "buildActionMask": 2147483647,
            "files": self.test_source_files,
            "runOnlyForDeploymentPostprocessing": 0,
        })
        self.add(self.app_resources_phase, {
            "isa": "PBXResourcesBuildPhase",
            "buildActionMask": 2147483647,
            "files": self.resource_files,
            "runOnlyForDeploymentPostprocessing": 0,
        })
        self.add(self.app_frameworks_phase, {
            "isa": "PBXFrameworksBuildPhase",
            "buildActionMask": 2147483647,
            "files": [],
            "runOnlyForDeploymentPostprocessing": 0,
        })
        self.add(self.test_frameworks_phase, {
            "isa": "PBXFrameworksBuildPhase",
            "buildActionMask": 2147483647,
            "files": [],
            "runOnlyForDeploymentPostprocessing": 0,
        })

        app_debug = new_id()
        app_release = new_id()
        test_debug = new_id()
        test_release = new_id()
        proj_debug = new_id()
        proj_release = new_id()

        app_settings = [
            "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
            "CODE_SIGN_STYLE = Automatic;",
            "CURRENT_PROJECT_VERSION = 1;",
            'DEVELOPMENT_TEAM = "";',
            "ENABLE_PREVIEWS = YES;",
            "GENERATE_INFOPLIST_FILE = YES;",
            'INFOPLIST_KEY_CFBundleDisplayName = Prisma;',
            'INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.news";',
            "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;",
            "INFOPLIST_KEY_UILaunchScreen_Generation = YES;",
            "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;",
            "IPHONEOS_DEPLOYMENT_TARGET = 26.0;",
            'LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");',
            "MARKETING_VERSION = 1.0;",
            "PRODUCT_BUNDLE_IDENTIFIER = com.prisma.app;",
            'PRODUCT_NAME = "$(TARGET_NAME)";',
            "SWIFT_EMIT_LOC_STRINGS = YES;",
            "SWIFT_VERSION = 5.0;",
            "TARGETED_DEVICE_FAMILY = 1;",
        ]

        for cfg_id, name, extra in [
            (app_debug, "Debug", [
                "DEBUG_INFORMATION_FORMAT = dwarf;",
                "GCC_OPTIMIZATION_LEVEL = 0;",
                "ONLY_ACTIVE_ARCH = YES;",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
                'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
            ]),
            (app_release, "Release", ["SWIFT_COMPILATION_MODE = wholemodule;"]),
        ]:
            self.add(cfg_id, {
                "isa": "XCBuildConfiguration",
                "buildSettings": {line.split(" = ")[0]: line.split(" = ", 1)[1].rstrip(";") for line in app_settings + extra},
                "name": name,
            })

        # Fix buildSettings - dict approach breaks quoted values; use raw strings instead
        for cfg_id, name, extra, is_debug in [
            (app_debug, "Debug", True),
            (app_release, "Release", False),
        ]:
            lines = list(app_settings)
            if is_debug:
                lines += [
                    "DEBUG_INFORMATION_FORMAT = dwarf;",
                    "GCC_OPTIMIZATION_LEVEL = 0;",
                    "ONLY_ACTIVE_ARCH = YES;",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
                    'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
                ]
            else:
                lines.append("SWIFT_COMPILATION_MODE = wholemodule;")
            self.objects[cfg_id] = {
                "isa": "XCBuildConfiguration",
                "buildSettings": self._parse_settings(lines),
                "name": name,
            }

        for cfg_id, name in [(test_debug, "Debug"), (test_release, "Release")]:
            self.add(cfg_id, {
                "isa": "XCBuildConfiguration",
                "buildSettings": self._parse_settings([
                    'BUNDLE_LOADER = "$(TEST_HOST)";',
                    "CODE_SIGN_STYLE = Automatic;",
                    "CURRENT_PROJECT_VERSION = 1;",
                    "GENERATE_INFOPLIST_FILE = YES;",
                    "IPHONEOS_DEPLOYMENT_TARGET = 26.0;",
                    "MARKETING_VERSION = 1.0;",
                    "PRODUCT_BUNDLE_IDENTIFIER = com.prisma.app.tests;",
                    'PRODUCT_NAME = "$(TARGET_NAME)";',
                    "SWIFT_VERSION = 5.0;",
                    "TARGETED_DEVICE_FAMILY = 1;",
                    'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Prisma.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Prisma";',
                ]),
                "name": name,
            })

        for cfg_id, name in [(proj_debug, "Debug"), (proj_release, "Release")]:
            self.add(cfg_id, {
                "isa": "XCBuildConfiguration",
                "buildSettings": self._parse_settings([
                    "ALWAYS_SEARCH_USER_PATHS = NO;",
                    "CLANG_ENABLE_MODULES = YES;",
                    "COPY_PHASE_STRIP = NO;",
                    "IPHONEOS_DEPLOYMENT_TARGET = 26.0;",
                    "SDKROOT = iphoneos;",
                    "SWIFT_VERSION = 5.0;",
                ]),
                "name": name,
            })

        self.add(self.app_config_list, {
            "isa": "XCConfigurationList",
            "buildConfigurations": [app_debug, app_release],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        })
        self.add(self.test_config_list, {
            "isa": "XCConfigurationList",
            "buildConfigurations": [test_debug, test_release],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        })
        self.add(self.project_config_list, {
            "isa": "XCConfigurationList",
            "buildConfigurations": [proj_debug, proj_release],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        })

        test_dep = new_id()
        self.add(test_dep, {
            "isa": "PBXTargetDependency",
            "target": self.app_target_id,
            "targetProxy": new_id(),
        })

        proxy_id = list(self.objects.keys())[-1]  # hack - set properly below

        container_proxy = new_id()
        self.add(container_proxy, {
            "isa": "PBXContainerItemProxy",
            "containerPortal": self.project_id,
            "proxyType": 1,
            "remoteGlobalIDString": self.app_target_id,
            "remoteInfo": "Prisma",
        })
        self.objects[test_dep]["targetProxy"] = container_proxy

        self.add(self.app_target_id, {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": self.app_config_list,
            "buildPhases": [self.app_sources_phase, self.app_frameworks_phase, self.app_resources_phase],
            "buildRules": [],
            "dependencies": [],
            "name": "Prisma",
            "productName": "Prisma",
            "productReference": self.app_product_id,
            "productType": '"com.apple.product-type.application"',
        })
        self.add(self.test_target_id, {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": self.test_config_list,
            "buildPhases": [self.test_sources_phase, self.test_frameworks_phase],
            "buildRules": [],
            "dependencies": [test_dep],
            "name": "PrismaTests",
            "productName": "PrismaTests",
            "productReference": self.test_product_id,
            "productType": '"com.apple.product-type.bundle.unit-test"',
        })

        self.add(self.project_id, {
            "isa": "PBXProject",
            "attributes": {
                "BuildIndependentTargetsInParallel": 1,
                "LastSwiftUpdateCheck": 1500,
                "LastUpgradeCheck": 1500,
            },
            "buildConfigurationList": self.project_config_list,
            "compatibilityVersion": '"Xcode 14.0"',
            "developmentRegion": "es",
            "hasScannedForEncodings": 0,
            "knownRegions": ["es", "en", "Base"],
            "mainGroup": main_group,
            "productRefGroup": products_group,
            "projectDirPath": '""',
            "projectRoot": '""',
            "targets": [self.app_target_id, self.test_target_id],
        })

        self._render()

    def _parse_settings(self, lines: list[str]) -> dict:
        result = {}
        for line in lines:
            key, val = line.split(" = ", 1)
            result[key] = val.rstrip(";")
        return result

    def _render(self) -> None:
        lines = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {};", "\tobjectVersion = 56;", "\tobjects = {"]

        def fmt(val, indent=2):
            pad = "\t" * indent
            if isinstance(val, dict):
                if not val:
                    return "{}"
                parts = ["{"]
                for k, v in val.items():
                    parts.append(f"{pad}\t{k} = {fmt(v, indent + 1)};")
                parts.append(f"{pad}}}")
                return "\n".join(parts)
            if isinstance(val, list):
                if not val:
                    return "()"
                return "(\n" + ",\n".join(f"{pad}\t{fmt(v, indent + 1)}" for v in val) + f",\n{pad})"
            if isinstance(val, str):
                if val in ('""', '"<group>"') or val.startswith('"com.apple') or val.startswith('"$(') or val.startswith('"@') or val.startswith('"public') or val.startswith('"Xcode') or val.startswith('"-'):
                    return val
                if val in ("BUILT_PRODUCTS_DIR", "es", "en", "Base") or val.isdigit():
                    return val
                return f'"{val}"'
            if isinstance(val, int):
                return str(val)
            return str(val)

        for oid, body in self.objects.items():
            lines.append(f"\t\t{oid} = {fmt(body, 2)};")

        lines.append("\t};")
        lines.append(f"\trootObject = {self.project_id} /* Project object */;")
        lines.append("}")

        PROJECT_DIR.mkdir(parents=True, exist_ok=True)
        out = PROJECT_DIR / "project.pbxproj"
        out.write_text("\n".join(lines) + "\n")
        print(f"Wrote {out}")
        print(f"  Unique objects: {len(self.objects)}")
        print(f"  App sources: {len(self.app_source_files)}")
        print(f"  Test sources: {len(self.test_source_files)}")
        print(f"  Resources: {len(self.resource_files)}")


def main() -> None:
    # Clean rewrite using simpler deterministic approach
    write_simple_project()


def write_simple_project() -> None:
    """Simpler generator with guaranteed unique IDs."""

    def uid() -> str:
        return uuid.uuid4().hex[:24].upper()

    app_swift = sorted(PRISMA_DIR.rglob("*.swift"))
    test_swift = sorted(TESTS_DIR.rglob("*.swift"))

    resources: list[Path] = []
    assets = PRISMA_DIR / "Resources" / "Assets.xcassets"
    for p in [PRISMA_DIR / "Resources" / "Localizable.xcstrings", PRISMA_DIR / "Resources" / "RecommendedFeeds.json"]:
        if p.exists():
            resources.append(p)
    if assets.exists():
        resources.append(assets)

    ids = {k: uid() for k in [
        "project", "main", "products", "prisma_group", "tests_group",
        "app_target", "test_target", "app_product", "test_product",
        "src", "res", "fw", "test_src", "test_fw",
        "app_cfg", "test_cfg", "proj_cfg", "debug", "release",
        "test_debug", "test_release", "proj_debug", "proj_release",
        "dep", "proxy",
    ]}

    file_ref: dict[Path, str] = {}
    build_src: dict[Path, str] = {}
    build_res: dict[Path, str] = {}

    for f in app_swift + test_swift:
        file_ref[f] = uid()
        build_src[f] = uid()
    for f in resources:
        file_ref[f] = uid()
        build_res[f] = uid()

    group_id: dict[Path, str] = {}

    def ensure_group(directory: Path) -> str:
        if directory in group_id:
            return group_id[directory]
        gid = uid()
        group_id[directory] = gid
        return gid

    all_dirs = {PRISMA_DIR, TESTS_DIR}

    def add_ancestors(path: Path) -> None:
        current = path
        while current not in (ROOT, PRISMA_DIR.parent, TESTS_DIR.parent):
            all_dirs.add(current)
            if current.parent == current:
                break
            current = current.parent

    for f in app_swift + test_swift + resources:
        add_ancestors(f.parent)

    # Include non-Swift config files (e.g. StoreKit)
    for extra in PRISMA_DIR.rglob("*.storekit"):
        add_ancestors(extra.parent)

    for d in sorted(all_dirs, key=lambda p: len(p.parts)):
        ensure_group(d)

    children_map: dict[Path, list[str]] = {}

    storekit_files = sorted(PRISMA_DIR.rglob("*.storekit"))

    for f in app_swift + test_swift:
        children_map.setdefault(f.parent, []).append(file_ref[f])
    for f in resources:
        children_map.setdefault(f.parent, []).append(file_ref[f])
    for f in storekit_files:
        if f not in file_ref:
            file_ref[f] = uid()
        children_map.setdefault(f.parent, []).append(file_ref[f])

    for d in sorted(all_dirs, key=lambda p: len(p.parts), reverse=True):
        if d in (ROOT,):
            continue
        parent = d.parent if d.parent in all_dirs else None
        if parent and d != PRISMA_DIR and d != TESTS_DIR:
            children_map.setdefault(parent, []).append(group_id[d])

    lines: list[str] = []
    w = lines.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")

    for f, bid in build_src.items():
        w(f"\t\t{bid} /* {f.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref[f]} /* {f.name} */; }};")
    for f, bid in build_res.items():
        label = "Assets.xcassets" if f.suffix == ".xcassets" else f.name
        w(f"\t\t{bid} /* {label} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref[f]} /* {label} */; }};")

    w(f"\t\t{ids['app_product']} /* Prisma.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Prisma.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w(f"\t\t{ids['test_product']} /* PrismaTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PrismaTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")

    for f, fid in file_ref.items():
        if f.suffix == ".swift":
            ftype = "sourcecode.swift"
        elif f.suffix == ".xcstrings":
            ftype = "text.json.xcstrings"
        elif f.suffix == ".xcassets":
            ftype = "folder.assetcatalog"
        else:
            ftype = "text.json"
        w(f"\t\t{fid} /* {f.name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {f.name}; sourceTree = \"<group>\"; }};")

    for d, gid in sorted(group_id.items(), key=lambda x: len(x[0].parts)):
        kids = children_map.get(d, [])
        name = d.name
        w(f"\t\t{gid} = {{")
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for kid in kids:
            w(f"\t\t\t\t{kid},")
        w("\t\t\t);")
        if d in (PRISMA_DIR, TESTS_DIR):
            w(f"\t\t\tpath = {name};")
        else:
            w(f"\t\t\tpath = {name};")
        w("\t\t\tsourceTree = \"<group>\";")
        w("\t\t};")

    w(f"\t\t{ids['products']} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{ids['app_product']} /* Prisma.app */,")
    w(f"\t\t\t\t{ids['test_product']} /* PrismaTests.xctest */,")
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    w(f"\t\t{ids['main']} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{group_id[PRISMA_DIR]} /* Prisma */,")
    w(f"\t\t\t\t{group_id[TESTS_DIR]} /* PrismaTests */,")
    w(f"\t\t\t\t{ids['products']} /* Products */,")
    w("\t\t\t);")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    for phase_id, phase_name, files in [
        (ids["fw"], "PBXFrameworksBuildPhase", []),
        (ids["test_fw"], "PBXFrameworksBuildPhase", []),
    ]:
        w(f"\t\t{phase_id} = {{")
        w(f"\t\t\tisa = {phase_name};")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")

    w(f"\t\t{ids['res']} = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for f in resources:
        w(f"\t\t\t\t{build_res[f]} /* {f.name} in Resources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")

    w(f"\t\t{ids['src']} = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for f in app_swift:
        w(f"\t\t\t\t{build_src[f]} /* {f.name} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")

    w(f"\t\t{ids['test_src']} = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for f in test_swift:
        w(f"\t\t\t\t{build_src[f]} /* {f.name} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")

    app_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Prisma;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.news";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.prisma.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
"""

    w(f"\t\t{ids['debug']} /* Debug */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(app_settings)
    w("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    w("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    w("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    w('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
    w("\t\t\t};")
    w("\t\t\tname = Debug;")
    w("\t\t};")

    w(f"\t\t{ids['release']} /* Release */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    w(app_settings)
    w("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    w("\t\t\t};")
    w("\t\t\tname = Release;")
    w("\t\t};")

    for cfg, name in [(ids["test_debug"], "Debug"), (ids["test_release"], "Release")]:
        w(f"\t\t{cfg} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w('\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";')
        w("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        w("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        w("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        w("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;")
        w("\t\t\t\tMARKETING_VERSION = 1.0;")
        w("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.prisma.app.tests;")
        w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
        w("\t\t\t\tSWIFT_VERSION = 5.0;")
        w("\t\t\t\tTARGETED_DEVICE_FAMILY = 1;")
        w('\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/Prisma.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Prisma";')
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    for cfg, name in [(ids["proj_debug"], "Debug"), (ids["proj_release"], "Release")]:
        w(f"\t\t{cfg} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        w("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        w("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        w("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;")
        w("\t\t\t\tSDKROOT = iphoneos;")
        w("\t\t\t\tSWIFT_VERSION = 5.0;")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    w(f"\t\t{ids['proj_cfg']} = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{ids['proj_debug']} /* Debug */,")
    w(f"\t\t\t\t{ids['proj_release']} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    w(f"\t\t{ids['app_cfg']} = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{ids['debug']} /* Debug */,")
    w(f"\t\t\t\t{ids['release']} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    w(f"\t\t{ids['test_cfg']} = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{ids['test_debug']} /* Debug */,")
    w(f"\t\t\t\t{ids['test_release']} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    w(f"\t\t{ids['proxy']} = {{")
    w("\t\t\tisa = PBXContainerItemProxy;")
    w(f"\t\t\tcontainerPortal = {ids['project']} /* Project object */;")
    w("\t\t\tproxyType = 1;")
    w(f"\t\t\tremoteGlobalIDString = {ids['app_target']};")
    w("\t\t\tremoteInfo = Prisma;")
    w("\t\t};")

    w(f"\t\t{ids['dep']} = {{")
    w("\t\t\tisa = PBXTargetDependency;")
    w(f"\t\t\ttarget = {ids['app_target']} /* Prisma */;")
    w(f"\t\t\ttargetProxy = {ids['proxy']} /* PBXContainerItemProxy */;")
    w("\t\t};")

    w(f"\t\t{ids['app_target']} /* Prisma */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {ids['app_cfg']} /* Build configuration list for PBXNativeTarget \"Prisma\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{ids['src']} /* Sources */,")
    w(f"\t\t\t\t{ids['fw']} /* Frameworks */,")
    w(f"\t\t\t\t{ids['res']} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = Prisma;")
    w("\t\t\tproductName = Prisma;")
    w(f"\t\t\tproductReference = {ids['app_product']} /* Prisma.app */;")
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")

    w(f"\t\t{ids['test_target']} /* PrismaTests */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {ids['test_cfg']} /* Build configuration list for PBXNativeTarget \"PrismaTests\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{ids['test_src']} /* Sources */,")
    w(f"\t\t\t\t{ids['test_fw']} /* Frameworks */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w(f"\t\t\t\t{ids['dep']} /* PBXTargetDependency */,")
    w("\t\t\t);")
    w("\t\t\tname = PrismaTests;")
    w("\t\t\tproductName = PrismaTests;")
    w(f"\t\t\tproductReference = {ids['test_product']} /* PrismaTests.xctest */;")
    w('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
    w("\t\t};")

    w(f"\t\t{ids['project']} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    w("\t\t\t\tLastUpgradeCheck = 1500;")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {ids['proj_cfg']} /* Build configuration list for PBXProject \"Prisma\" */;")
    w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    w("\t\t\tdevelopmentRegion = es;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\tes,")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w(f"\t\t\tmainGroup = {ids['main']};")
    w(f"\t\t\tproductRefGroup = {ids['products']} /* Products */;")
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{ids['app_target']} /* Prisma */,")
    w(f"\t\t\t\t{ids['test_target']} /* PrismaTests */,")
    w("\t\t\t);")
    w("\t\t};")

    w("\t};")
    w(f"\trootObject = {ids['project']} /* Project object */;")
    w("}")

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    out = PROJECT_DIR / "project.pbxproj"
    out.write_text("\n".join(lines) + "\n")

    # Validate unique IDs
    import re
    text = out.read_text()
    all_ids = re.findall(r"\b[0-9A-F]{24}\b", text)
    dupes = {i for i in all_ids if all_ids.count(i) > len(re.findall(rf"{i} /\*", text)) + len(re.findall(rf"= {i};", text)) + len(re.findall(rf"= {i} /\*", text))}
    # simpler dupe check
    from collections import Counter
    c = Counter(all_ids)
    bad = [k for k, v in c.items() if v > 20]
    print(f"Wrote {out}")
    print(f"  App swift: {len(app_swift)}, Tests: {len(test_swift)}, Resources: {len(resources)}")
    if bad:
        print(f"  WARNING possible duplicate-heavy ids: {bad[:5]}")


if __name__ == "__main__":
    main()
