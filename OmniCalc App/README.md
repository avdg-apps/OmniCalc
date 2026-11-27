# OmniCalc: iPhone, iPad, Mac and Apple Vision

1. Xcode > File > New > Project > **Multiplatform** tab > **App** (name: OmniCalc, SwiftUI).
2. Target > General > Supported Destinations > "+" > add **Apple Vision** (needs the visionOS simulator: Xcode > Settings > Components).
3. Minimum versions: iOS 17, macOS 14, visionOS 1.
4. Delete the generated app + content files, then drag in every .swift file (tick all targets).
5. **Mac without App Sandbox:** Target > Signing & Capabilities > remove **App Sandbox** (click the x on its card).
   Then Build Settings > search "sandbox" > set **Enable App Sandbox = No** (if that row exists).
   Clean (Shift+Cmd+K) and run. The Mac App Store requires the sandbox, so for the store you'd turn it back on
   and tick Outgoing Connections (Client).
6. Secrets.swift holds the Gemini key. Keep it out of git.
