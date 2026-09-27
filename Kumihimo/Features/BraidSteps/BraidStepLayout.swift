import Foundation

/// **The step animation's stand, as drawn** (Task 066, Task 067): how large a
/// bobbin is, and how far apart the threads of an island are drawn. Where the
/// threads stand is the working's (`BraidBookWorking`); this only turns its
/// steps into angles.
struct BraidStepLayout: Equatable {
    let placeCount: Int
    /// A bobbin's radius, in units of the rim's radius.
    let ballRadius: Double
    /// Two neighbours drawn this far apart at the least, in turns: apart, with a
    /// little room between (`clearance`).
    let least: Double

    /// How far apart two bobbins stand at the least, beyond touching, in units
    /// of the rim's radius.
    static let clearance: Double = 0.04
    /// **A face of a round stand drawn as a fan** (the textbook's figures): its
    /// threads this far apart, in turns, so a face of six still leaves room
    /// before the next face.
    static let fan: Double = 1.0 / 20

    init(placeCount: Int) {
        self.placeCount = placeCount
        ballRadius = min(0.15, 0.4 * sin(.pi / Double(max(placeCount, 1))))
        // Two bobbins on the rim a turn share `t` apart are 2 sin(πt) apart.
        least = asin(min(1, ballRadius + Self.clearance / 2)) / .pi
    }

    /// **How far apart a step of the working is drawn**: a notch of the disk,
    /// spread just far enough to part two bobbins when a notch would put them
    /// on top of each other; a face's fan.
    func stepTurn(for form: BraidBookWorking.Form) -> Double {
        switch form {
        case .disk(let notches):
            let notch = 1 / Double(max(notches, 1))
            let touching = asin(min(1, ballRadius)) / .pi
            return notch < touching ? least : notch
        case .stand:
            return max(Self.fan, least)
        }
    }
}
