#if DEBUG
import SwiftUI

/// The eight-thread tube as the app draws it, opened straight from a launch
/// argument at a chosen colouring and turn — **so that a comparison can be drawn
/// again by anyone, before and after a change** (Task 045).
///
/// **Debug builds only, and no control of its own.** It shows the same preview
/// the editor shows (`BraidPreviewForFamily`, the same material and lighting and
/// camera) and the same card (`BraidThumbnailForFamily`); all it adds is where
/// the braid starts turned. Nothing here reaches the release UI.
///
///     --ui-testing-yatsu-kongo-solid   the solid, full screen
///     --ui-testing-yatsu-kongo-card    the card, as the results list lays it out
///     --yatsu-kongo-recipe=s|z|maru    which braid (default s). `maru` is the
///                                      sixteen-thread maru-genji, added for
///                                      Task 047's comparisons; the launch
///                                      arguments keep their first name
///     --yatsu-kongo-colouring=plain|book|eight
///                                      one colour, book A p.54's, or all eight
///                                      told apart (default plain)
///                              maru only: plain|blue|fixture1|fixture2|fixture3|
///                                      bluewhite|sketch — natural, blue, the
///                                      editor's surface fixtures, fixture 1 with
///                                      its pink as white (the nearest the
///                                      catalogue comes to book A's navy and
///                                      white), and the four threads whose cells
///                                      meet at the front V in the first two rows
///                                      painted as the author's coloured sketch
///                                      paints them (Task 047 rework), the rest
///                                      natural
///     --yatsu-kongo-zoom=<factor>      zoomed in, as a pinch would (clamped)
///     --yatsu-kongo-no-detail          maru only: no stripe, roughness or
///                                      shading maps, to read the shape alone
///     --yatsu-kongo-roll=<degrees>     turned about the braid's own axis
@MainActor
enum YatsuKongoComparisonPreviewData {
    static let solidLaunchArgument = "--ui-testing-yatsu-kongo-solid"
    static let cardLaunchArgument = "--ui-testing-yatsu-kongo-card"

    static var recipe: BraidRecipe {
        switch value(of: "--yatsu-kongo-recipe") {
        case "z": return BraidMethodCatalog.yatsuKongoZ8Recipe
        case "maru": return BraidMethodCatalog.maruGenji16Recipe
        default: return BraidMethodCatalog.yatsuKongoS8Recipe
        }
    }

    static var assignments: [ThreadAssignment] {
        if recipe.id == BraidMethodCatalog.maruGenji16Recipe.id {
            return maruGenjiAssignments
        }
        switch value(of: "--yatsu-kongo-colouring") {
        case "book":
            return recipe.colouring
        case "eight":
            let names = ["red", "orange", "yellow", "green", "light-blue", "blue", "purple", "pink"]
            return names.enumerated().map {
                ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element))
            }
        default:
            return (1...8).map {
                ThreadAssignment(position: $0, colorID: ThreadColorColorIDs.natural)
            }
        }
    }

    private static var maruGenjiAssignments: [ThreadAssignment] {
        let fixture: [ThreadAssignment]
        switch value(of: "--yatsu-kongo-colouring") {
        case "blue": return ProjectEditorPreviewData.maruGenjiSurfacePlain
        case "fixture1": return ProjectEditorPreviewData.maruGenjiSurfaceFixture1
        case "fixture2": return ProjectEditorPreviewData.maruGenjiSurfaceFixture2
        case "fixture3": return ProjectEditorPreviewData.maruGenjiSurfaceFixture3
        case "bluewhite": fixture = ProjectEditorPreviewData.maruGenjiSurfaceFixture1
        case "sketch":
            // At the front V, row 1: thread 1 passes over, 12 under; row 2: 11
            // over, 2 under. Painted by which side of the V each is on, as the
            // sketch paints them: black and red on one side, yellow and blue on
            // the other.
            let sketch: [Int: String] = [12: "black", 1: "yellow", 11: "red", 2: "blue"]
            return (1...16).map {
                ThreadAssignment(
                    position: $0,
                    colorID: sketch[$0].map(ThreadColorID.init(rawValue:))
                        ?? ThreadColorColorIDs.natural
                )
            }
        default:
            return (1...16).map {
                ThreadAssignment(position: $0, colorID: ThreadColorColorIDs.natural)
            }
        }
        return fixture.map {
            ThreadAssignment(
                position: $0.position,
                colorID: $0.colorID.rawValue == "pink" ? ThreadColorID(rawValue: "white") : $0.colorID
            )
        }
    }

    static var zoom: Float {
        value(of: "--yatsu-kongo-zoom").flatMap(Float.init) ?? 1
    }

    static var drawsWithoutDetail: Bool {
        CommandLine.arguments.contains("--yatsu-kongo-no-detail")
    }

    static var rollDegrees: Float {
        value(of: "--yatsu-kongo-roll").flatMap(Float.init) ?? 0
    }

    private static func value(of key: String) -> String? {
        CommandLine.arguments
            .first { $0.hasPrefix(key + "=") }
            .map { String($0.dropFirst(key.count + 1)) }
    }
}

private enum ThreadColorColorIDs {
    static let natural = ThreadColorCatalog.defaultColor.id
}

struct YatsuKongoComparisonSolid: View {
    @StateObject private var controller: RoundTube16ViewerController = {
        let controller = RoundTube16ViewerController()
        controller.rotate(horizontal: YatsuKongoComparisonPreviewData.rollDegrees * .pi / 180)
        controller.zoom(by: YatsuKongoComparisonPreviewData.zoom)
        return controller
    }()

    var body: some View {
        let recipe = YatsuKongoComparisonPreviewData.recipe
        BraidPreviewForFamily(
            recipe: recipe,
            assignments: YatsuKongoComparisonPreviewData.assignments,
            controller: controller,
            isEmbedded: false,
            closeAction: {},
            nothingDrawsIt: "",
            prototypeNotice: BraidPresetCatalog.preset(for: BraidPresetID(rawValue: recipe.id))?.prototypeNotice ?? ""
        )
    }
}

struct YatsuKongoComparisonCard: View {
    var body: some View {
        BraidThumbnailForFamily(
            recipe: YatsuKongoComparisonPreviewData.recipe,
            assignments: YatsuKongoComparisonPreviewData.assignments,
            nothingDrawsIt: ""
        )
        .frame(height: 112)
        .padding()
    }
}
#endif
