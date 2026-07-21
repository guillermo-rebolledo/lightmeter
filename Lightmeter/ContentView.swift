import SwiftUI

/// Placeholder scaffold screen. Replaced by the live camera meter in ticket #3.
struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.white)

                Text(AppInfo.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)

                Text(AppInfo.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
