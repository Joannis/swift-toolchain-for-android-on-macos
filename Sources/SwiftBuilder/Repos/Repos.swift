import Foundation

enum Repos {
    static let checkoutOrder: [Checkoutable] = [
        swift,
        llvm,
        cmark,
        yams,
        swiftArgumentParser,
        swiftSystem,
        toolsSupportCore,
        llbuild,
        swiftDriver,
        crypto,
        collections,
        spm,
        libDispatchRepo,
    ]

    static let buildOrder: [BuildableItem] = {
        let upToSwift: [BuildableItem] = [
            llvm,
            cmark,
            yams,
            swiftArgumentParser,
            swiftSystem,
            toolsSupportCore,
            llbuild,
            swiftDriver,
            crypto,
            collections,
            spm,
            swift,
        ]

        return upToSwift + libs
    }()

    static let libs: [BuildableItem] = {
        let libs: [BuildableItem] = AndroidArchs.all.flatMap { arch -> [BuildableItem] in
            let stdLib = StdLib(
                swift: Repos.swift,
                arch: arch,
                dependencies: [
                    "LLVM": LLVMModule(llvm: Repos.llvm),
                    "LibDispatch": libDispatchRepo,
                    "NDK": NDKDependency(),
                ]
            )

            let libDispatch = LibDispatchBuild(arch: arch,
                                               libDispatchRepo: libDispatchRepo,
                                               swift: swift,
                                               stdlib: stdLib)
            return [stdLib, libDispatch]
        }

        return libs
    }()

    static let llvm = LlvmProjectRepo()
    static let cmark = CMarkRepo()
    static let yams = YamsRepo()
    static let swiftArgumentParser = SwiftArgumentParserRepo()
    static let swiftSystem = SwiftSystemRepo()
    static let llbuild = SwiftLLBuildRepo()
    static let crypto = SwiftCryptoRepo()
    static let collections = SwiftCollectionsRepo()

    static let toolsSupportCore = SwiftToolsSupportCoreRepo(dependencies: [
        "SwiftSystem": swiftSystem
    ])

    static let swiftDriver = SwiftDriverRepo(dependencies: [
        "TSC": toolsSupportCore,
        "LLBuild": llbuild,
        "Yams": yams,
        "ArgumentParser": swiftArgumentParser,
        "SwiftSystem": swiftSystem,
    ])

    static let spm = SPMRepo(dependencies: [
        "TSC": toolsSupportCore,
        "LLBuild": llbuild,
        "ArgumentParser": swiftArgumentParser,
        "SwiftSystem": swiftSystem,
        "SwiftDriver": swiftDriver,
        "SwiftCrypto": crypto,
        "SwiftCollections": collections,
    ])

    static let swift = SwiftRepo(dependencies: [
        "LLVM": LLVMModule(llvm: llvm),
        "Clang": LLVMModule(llvm: llvm),
        "Cmark": CmarkAsDependency(cmark: cmark),
        "NDK": NDKDependency(),
    ])

    static let libDispatchRepo = LibDispatchRepo()
}

struct LlvmProjectRepo: BuildableItem, Checkoutable {
    let githubUrl = "https://github.com/apple/llvm-project.git"

    let buildSubfolder: String? = "llvm"

    let targets: [String] = [
        "clang",
        "llvm-tblgen",
        "clang-tblgen",
        "llvm-libraries",
        "clang-libraries"
    ]

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "LLVM_INCLUDE_EXAMPLES=false",
            "LLVM_INCLUDE_TESTS=false",
            "LLVM_INCLUDE_DOCS=false",
            "LLVM_BUILD_TOOLS=false",
            "LLVM_INSTALL_BINUTILS_SYMLINKS=false",
            "LLVM_ENABLE_ASSERTIONS=TRUE",
            "LLVM_BUILD_EXTERNAL_COMPILER_RT=TRUE",
            "LLVM_ENABLE_PROJECTS=clang",
        ]
    }
}

struct CMarkRepo: BuildableItem, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-cmark.git"

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "CMARK_TESTS=false",
            "CMAKE_C_FLAGS=\"-Wno-unknown-warning-option -Werror=unguarded-availability-new -fno-stack-protector\"",
            "CMAKE_CXX_FLAGS=\"-Wno-unknown-warning-option -Werror=unguarded-availability-new -fno-stack-protector\"",
        ]
    }
}

struct YamsRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/jpsim/yams.git"
}

struct SwiftArgumentParserRepo: BuildableItem, BuildableItemDependency, Checkoutable {

    let githubUrl = "https://github.com/apple/swift-argument-parser.git"

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "BUILD_SHARED_LIBS=YES",
            "BUILD_EXAMPLES=FALSE",
            "BUILD_TESTING=FALSE",
        ]
    }
}

struct SwiftSystemRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-system.git"
}

struct SwiftToolsSupportCoreRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-tools-support-core.git"

    let dependencies: [String: BuildableItemDependency]

    init(dependencies: [String: BuildableItemDependency]) {
        self.dependencies = dependencies
    }

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "SwiftSystem_DIR=/Users/nikolaydzhulay/ws/SwiftAndroid_working/build/swift-system/cmake/modules"
        ]
    }
}

struct SwiftLLBuildRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-llbuild.git"

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        // Here we have targer arch and macos version, and I might probably replace arm64 here with macOs arch, but 10.10 make no sense to replace with 12, as few placeses parse and looks like expect 10.x
        // TODO: Figure out does it work on x86_64, and find actual list of valid values. Will it accept arm64-apple-macosx13.0 ?!
        //       According to error from cmake, this mcosx13.0 is invalid value
        //             <unknown>:0: error: unable to load standard library for target 'arm64-apple-macosx13.0'
        //       Initial value was `arm64-apple-macosx10.10`
        //       I replaced arch and macOS version here, assuming that same values are valid with x86_64 arch.
        let target = "\(config.macOsArch)-apple-macosx\(config.macOsTarget)"

        return [
            "CMAKE_Swift_FLAGS=\"-Xlinker -v -Xfrontend -target -Xfrontend \(target) -target \(target) -v\"",
            "LLBUILD_SUPPORT_BINDINGS=Swift",
            "CMAKE_OSX_ARCHITECTURES=\(config.macOsArch)",
            "BUILD_SHARED_LIBS=false",
        ]
    }
}

struct SwiftDriverRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-driver.git"

    let dependencies: [String: BuildableItemDependency]

    init(dependencies: [String: BuildableItemDependency]) {
        self.dependencies = dependencies
    }
}

struct SwiftCryptoRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-crypto.git"
}

struct SwiftCollectionsRepo: BuildableItem, BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-collections.git"
}

struct SPMRepo: BuildableItem, Checkoutable {
    let repoName: String = "swiftpm"

    let githubUrl = "https://github.com/apple/swift-package-manager.git"

    let dependencies: [String: BuildableItemDependency]

    init(dependencies: [String: BuildableItemDependency]) {
        self.dependencies = dependencies
    }

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "CMAKE_Swift_FLAGS=\"-Xlinker -rpath -Xlinker @executable_path/../lib\"",
            "USE_CMAKE_INSTALL=TRUE",
            "CMAKE_BUILD_WITH_INSTALL_RPATH=true",
        ]
    }
}

struct SwiftRepo: BuildableItem, Checkoutable {
    let githubUrl = "https://github.com/apple/swift.git"

    let revision: CheckoutRevision = .tag("swift-5.7-RELEASE")

    let dependencies: [String: BuildableItemDependency]

    init(dependencies: [String: BuildableItemDependency]) {
        self.dependencies = dependencies
    }

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "SWIFT_DARWIN_DEPLOYMENT_VERSION_OSX=\(config.macOsTarget)",
            "SWIFT_HOST_VARIANT_ARCH=arm64",

            // SWIFT_ANDROID_NDK_PATH, SWIFT_ANDROID_NDK_GCC_VERSION, SWIFT_ANDROID_API_LEVEL - will be populated by `NDKDependency`

            "SWIFT_STDLIB_ENABLE_SIL_OWNERSHIP=FALSE",
            "SWIFT_ENABLE_GUARANTEED_NORMAL_ARGUMENTS=TRUE",
            "CMAKE_EXPORT_COMPILE_COMMANDS=TRUE",
            "SWIFT_STDLIB_ENABLE_STDLIBCORE_EXCLUSIVITY_CHECKING=FALSE",

            "SWIFT_ANDROID_DEPLOY_DEVICE_PATH=/data/local/tmp",
            "SWIFT_SDK_ANDROID_ARCHITECTURES=\"\(AndroidArchs.all.map { $0.swiftArch }.joined(separator: ";"))\"",
            "SWIFT_BUILD_SOURCEKIT=FALSE",
            "SWIFT_ENABLE_SOURCEKIT_TESTS=FALSE",
            "SWIFT_SOURCEKIT_USE_INPROC_LIBRARY=TRUE",
            "SWIFT_STDLIB_ASSERTIONS=FALSE",
            "SWIFT_INCLUDE_TOOLS=TRUE",
            "SWIFT_BUILD_REMOTE_MIRROR=TRUE",
            "SWIFT_STDLIB_SIL_DEBUGGING=FALSE",
            "SWIFT_BUILD_DYNAMIC_STDLIB=FALSE",
            "SWIFT_BUILD_STATIC_STDLIB=FALSE",
            "SWIFT_BUILD_DYNAMIC_SDK_OVERLAY=FALSE",
            "SWIFT_BUILD_STATIC_SDK_OVERLAY=FALSE",
            "SWIFT_BUILD_PERF_TESTSUITE=FALSE",
            "SWIFT_BUILD_EXTERNAL_PERF_TESTSUITE=FALSE",
            "SWIFT_BUILD_EXAMPLES=FALSE",
            "SWIFT_INCLUDE_TESTS=FALSE",
            "SWIFT_INCLUDE_DOCS=FALSE",
            "SWIFT_INSTALL_COMPONENTS='autolink-driver;compiler;clang-builtin-headers;stdlib;swift-remote-mirror;sdk-overlay;license'",
            "SWIFT_ENABLE_LLD_LINKER=FALSE",
            "SWIFT_ENABLE_GOLD_LINKER=TRUE",
            "SWIFT_ENABLE_DISPATCH=false",
            "LIBDISPATCH_CMAKE_BUILD_TYPE=Release",
            "SWIFT_OVERLAY_TARGETS=''",
            "SWIFT_HOST_VARIANT=macosx",
            "SWIFT_HOST_VARIANT_SDK=OSX",
            "SWIFT_ENABLE_IOS32=false",
            "SWIFT_SDKS='ANDROID;OSX'",
            "SWIFT_PRIMARY_VARIANT_SDK=ANDROID",
            "SWIFT_AST_VERIFIER=FALSE",
            "SWIFT_RUNTIME_ENABLE_LEAK_CHECKER=FALSE",
            "SWIFT_STDLIB_SUPPORT_BACK_DEPLOYMENT=FALSE",
            "LLVM_LIT_ARGS=-sv",
            "LLVM_ENABLE_ASSERTIONS=TRUE",
            "COVERAGE_DB=",
        ]
    }
}

struct StdLib: BuildableItem {

    init(swift: SwiftRepo,
         arch: AndroidArch,
         dependencies: [String: BuildableItemDependency]) {
        self.swift = swift
        self.arch = arch
        self.dependencies = dependencies
    }

    // MARK: BuildableItem

    var name: String { "stdlib-\(arch.name)" }

    let dependencies: [String: BuildableItemDependency]

    var underlyingRepo: BuildableItemRepo? {
        BuildableItemRepo(checkoutable: swift,
                          patchFileName: "stdlib.patch")
    }

    func sourceLocation(using buildConfig: BuildConfig) -> URL {
        let swiftLocation = swift.sourceLocation(using: buildConfig)
        return swiftLocation
    }

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        [
            "ANDROID_ABI=" + arch.ndkABI,
            "ANDROID_PLATFORM=android-" + config.androidApiLevel,
            "CMAKE_TOOLCHAIN_FILE=" + config.cmakeToolchainFile,

            // LLVM_DIR come form dependency

            "SWIFT_HOST_VARIANT_SDK=ANDROID",
            "SWIFT_HOST_VARIANT_ARCH=" + arch.swiftArch,
            "SWIFT_SDKS=\"ANDROID\"",
            "SWIFT_STANDARD_LIBRARY_SWIFT_FLAGS='-sdk;\(config.ndkToolchain)/sysroot'", // also might add `;-v` for verbose

            "SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=TRUE",

            "SWIFT_STDLIB_SINGLE_THREADED_RUNTIME=FALSE",

            // SWIFT_PATH_TO_LIBDISPATCH_SOURCE come from LibDispatch dependency

            "SWIFT_BUILD_DYNAMIC_SDK_OVERLAY=TRUE",
            "SWIFT_BUILD_STATIC_SDK_OVERLAY=FALSE",

            "SWIFT_BUILD_TEST_SUPPORT_MODULES=FALSE",

            "SWIFT_INCLUDE_TOOLS=NO",
            "SWIFT_INCLUDE_TESTS=FALSE",
            "SWIFT_INCLUDE_DOCS=NO",

            "SWIFT_BUILD_SYNTAXPARSERLIB=NO",
            "SWIFT_BUILD_SOURCEKIT=NO",
            
            "SWIFT_ENABLE_LLD_LINKER=FALSE",
            "SWIFT_ENABLE_GOLD_LINKER=TRUE",

            "SWIFT_ENABLE_DISPATCH=true",

            "SWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER=YES",
            "SWIFT_NATIVE_SWIFT_TOOLS_PATH=\(config.buildLocation(for: swift).path)/bin",

            // TODO: These pathes form pre-installed libxml2, so might be needed to build it before
            "LIBXML2_LIBRARY=/opt/homebrew/Cellar/libxml2/2.10.3/lib",
            "LIBXML2_INCLUDE_DIR=/opt/homebrew/Cellar/libxml2/2.10.3/include",
        ]
    }

    // MARK: Private

    private let swift: SwiftRepo
    private let arch: AndroidArch
}


struct LibDispatchRepo: BuildableItemDependency, Checkoutable {
    let githubUrl = "https://github.com/apple/swift-corelibs-libdispatch.git"

    func cmakeDepDirCaheEntry(depName: String, config: BuildConfig) -> [String] {
        return [
            "SWIFT_PATH_TO_LIBDISPATCH_SOURCE=\"\(config.location(for: self).path)\"",
        ]
    }
}

struct LibDispatchBuild: BuildableItem {

    init(arch: AndroidArch,
         libDispatchRepo: LibDispatchRepo,
         swift: SwiftRepo,
         stdlib: StdLib) {
        self.arch = arch
        self.libDispatchRepo = libDispatchRepo
        self.swift = swift
        self.stdlib = stdlib
    }

    var name: String { "libDispatch-\(arch.name)" }

    var underlyingRepo: BuildableItemRepo? {
        BuildableItemRepo(checkoutable: libDispatchRepo, patchFileName: "libDispatch")
    }

    func sourceLocation(using buildConfig: BuildConfig) -> URL {
        buildConfig.location(for: libDispatchRepo)
    }

    func cmakeCacheEntries(config: BuildConfig) -> [String] {
        let cmakeSwiftFlags = [
            "-resource-dir \(config.buildLocation(for: stdlib).path)/lib/swift",
            "-Xcc --sysroot=\(config.ndkToolchain)/sysroot",

            // Follow this unwer, otherwise, I got error, that can't find start stop files - https://stackoverflow.com/questions/69795531/after-ndk22-upgrade-the-build-fails-with-cannot-open-crtbegin-so-o-crtend-so
            // More detailed explanation - https://github.com/NikolayJuly/swift-toolchain-for-android-on-macos/issues/1#issuecomment-1426774354
            "-Xclang-linker -nostartfiles",

            "-Xclang-linker --sysroot=\(config.ndkToolchain)/sysroot/usr/lib/\(arch.ndkLibArchName)/\(config.androidApiLevel)",
            "-Xclang-linker --gcc-toolchain=\(config.ndkToolchain)",
            "-tools-directory \(config.ndkToolchain)/bin",

            //"-Xclang-linker -v",
            //"-v",
        ]

        let cFlags: [String] = [
            //"-v",
        ]

        let cxxFlags: [String] = [
            //"-v",
        ]

        let cmakeSwiftFlagsString = cmakeSwiftFlags.joined(separator: " ")
        let cFlagsString = cFlags.joined(separator: " ")
        let cxxFlagsString = cxxFlags.joined(separator: " ")

        return [
            "ANDROID_ABI=" + arch.ndkABI,
            "ANDROID_PLATFORM=android-" + config.androidApiLevel,
            "CMAKE_TOOLCHAIN_FILE=" + config.cmakeToolchainFile,

            "ENABLE_TESTING=NO",
            "ENABLE_SWIFT=YES",

            "CMAKE_Swift_COMPILER=\(config.buildLocation(for: swift).path)/bin/swiftc",
            "CMAKE_Swift_COMPILER_FORCED=true",

            "CMAKE_Swift_COMPILER_TARGET=\(arch.swiftTarget)",
            "CMAKE_Swift_FLAGS=\"\(cmakeSwiftFlagsString)\"",

            "CMAKE_C_FLAGS=\"-v\"",
            "CMAKE_CXX_FLAGS=\"-v\"",

            "CMAKE_C_FLAGS=\"\(cFlagsString)\"",
            "CMAKE_CXX_FLAGS=\"\(cxxFlagsString)\"",

            "CMAKE_BUILD_WITH_INSTALL_RPATH=true",
        ]
    }

    // MARK: Private

    private let arch: AndroidArch
    private let swift: SwiftRepo
    private let stdlib: StdLib
    private let libDispatchRepo: LibDispatchRepo
}


private struct LLVMModule: BuildableItemDependency {
    init(llvm: LlvmProjectRepo) {
        self.llvm = llvm
    }

    func cmakeDepDirCaheEntry(depName: String, config: BuildConfig) -> [String] {
        let depBuildUrl = config.buildLocation(for: llvm)
        let res = depName + "_DIR=\"\(depBuildUrl.path)/lib/cmake/\(depName.lowercased())\""
        return [res]
    }

    private let llvm: LlvmProjectRepo
}

private struct CmarkAsDependency: BuildableItemDependency {
    init(cmark: CMarkRepo) {
        self.cmark = cmark
    }

    func cmakeDepDirCaheEntry(depName: String, config: BuildConfig) -> [String] {
        let depRepoUrl = config.location(for: cmark)
        let depBuildUrl = config.buildLocation(for: cmark)
        return [
            "SWIFT_PATH_TO_CMARK_SOURCE=\"\(depRepoUrl.path)\"",
            "SWIFT_PATH_TO_CMARK_BUILD=\"\(depBuildUrl.path)\""
        ]
    }

    private let cmark: CMarkRepo
}

private struct NDKDependency: BuildableItemDependency {
    func cmakeDepDirCaheEntry(depName: String, config: BuildConfig) -> [String] {
        [
            "SWIFT_ANDROID_NDK_PATH=\"\(config.ndkPath)\"",
            "SWIFT_ANDROID_NDK_GCC_VERSION=" + config.ndkGccVersion,
            "SWIFT_ANDROID_API_LEVEL=" + config.androidApiLevel,
            "SWIFT_ANDROID_NDK_CLANG_VERSION=" + config.ndkClangVersion,
        ]
    }
}

