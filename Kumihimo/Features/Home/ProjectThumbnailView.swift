import ImageIO
import SwiftUI

struct ProjectThumbnailView: View {
    let thumbnailData: Data?

    var body: some View {
        Group {
            if let image = decodedImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.indigo.opacity(0.3), .teal.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "scribble.variable")
                        .font(.title)
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var decodedImage: CGImage? {
        guard
            let thumbnailData,
            let source = CGImageSourceCreateWithData(thumbnailData as CFData, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
