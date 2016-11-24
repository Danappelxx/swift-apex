import PackageDescription

let package = Package(
    name: "Apex",
    targets: [
        Target(name: "Apex"),
        Target(name: "ApexExample", dependencies: ["Apex"]),
    ],
    dependencies: [
        .Package(url: "https://github.com/Zewo/Axis.git", majorVersion: 0, minor: 14),
        .Package(url: "https://github.com/Zewo/Venice.git", majorVersion: 0, minor: 14),
    ]
)
