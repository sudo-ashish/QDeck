pragma Singleton
import QtQuick

QtObject {
    id: root

    // =========================================================================
    // Material Design 3 (M3) Motion Duration Tokens
    // Spec: https://m3.material.io/styles/motion/overview/how-it-works
    // =========================================================================
    // Short durations (micro-interactions, simple icons, utility fades)
    readonly property int short1: 50
    readonly property int short2: 100
    readonly property int short3: 150
    readonly property int short4: 200

    // Medium durations (spatial transitions, dialogs, expanding sheets)
    readonly property int medium1: 250
    readonly property int medium2: 300
    readonly property int medium3: 350
    readonly property int medium4: 400

    // Long durations (container transform, full-screen transitions)
    readonly property int long1: 450
    readonly property int long2: 500
    readonly property int long3: 550
    readonly property int long4: 600

    // Extra Long durations (extensive layout re-flows, splash/onboarding)
    readonly property int extraLong1: 700
    readonly property int extraLong2: 800
    readonly property int extraLong3: 900
    readonly property int extraLong4: 1000

    // =========================================================================
    // Material Design 3 (M3) Easing Curves (Cubic Bezier Splines)
    // Spec: https://m3.material.io/styles/motion/overview/how-it-works
    // Format: [x1, y1, x2, y2, 1.0, 1.0] for QtQuick Easing.BezierSpline
    // =========================================================================
    // Emphasized Easing (Signature M3 Expressive style)
    // 1. Emphasized (begin and end on screen): cubic-bezier(0.2, 0.0, 0.0, 1.0)
    readonly property var emphasizedCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    // 2. Emphasized Decelerate (elements entering the screen): cubic-bezier(0.05, 0.7, 0.1, 1.0)
    readonly property var emphasizedDecelerateCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]

    // 3. Emphasized Accelerate (elements exiting the screen): cubic-bezier(0.3, 0.0, 0.8, 0.15)
    readonly property var emphasizedAccelerateCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    // Standard Easing (Utilitarian transitions)
    // 1. Standard (begin and end on screen): cubic-bezier(0.2, 0.0, 0.0, 1.0)
    readonly property var standardCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    // 2. Standard Decelerate (elements entering): cubic-bezier(0.0, 0.0, 0.2, 1.0)
    readonly property var standardDecelerateCurve: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]

    // 3. Standard Accelerate (elements exiting): cubic-bezier(0.3, 0.0, 1.0, 1.0)
    readonly property var standardAccelerateCurve: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]

    // =========================================================================
    // M3 Transition Patterns Specifications
    // Spec: https://m3.material.io/styles/motion/transitions/transition-patterns
    // =========================================================================
    // Container Transform: morphing card dimensions and radii
    readonly property int containerTransformDuration: 500
    readonly property var containerTransformEasing: root.emphasizedCurve

    // Shared Axis Y (Bottom sheets, popups, launcher dock)
    readonly property int enterYDuration: 400
    readonly property var enterYEasing: root.emphasizedDecelerateCurve
    readonly property int exitYDuration: 200
    readonly property var exitYEasing: root.emphasizedAccelerateCurve

    // Shared Axis Z (Scale & elevation, dialogs, cards)
    readonly property int enterZDuration: 400
    readonly property var enterZEasing: root.emphasizedDecelerateCurve
    readonly property real enterZScaleStart: 0.92
    readonly property int exitZDuration: 200
    readonly property var exitZEasing: root.emphasizedAccelerateCurve
    readonly property real exitZScaleEnd: 0.92

    // Fade Through (Switching top-level views/destinations)
    readonly property int fadeThroughExitDuration: 150
    readonly property var fadeThroughExitEasing: root.standardAccelerateCurve
    readonly property int fadeThroughEnterDuration: 250
    readonly property var fadeThroughEnterEasing: root.standardDecelerateCurve

    // Expressive Spring & Tactile Micro-Interactions
    readonly property int springDuration: 320
    readonly property real springOvershoot: 1.25
    readonly property int hoverDuration: 150
    readonly property int pressDuration: 100
    readonly property int colorDuration: 180
}
