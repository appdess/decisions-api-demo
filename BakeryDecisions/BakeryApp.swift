import SwiftUI

@main struct BakeryApp: App {
    var body: some Scene { WindowGroup { BakeryView().preferredColorScheme(.light) } }
}
extension Color {
    static let bakeryBG = Color(red:0.95,green:0.96,blue:0.98)
    static let bakeryInk = Color(red:0.12,green:0.15,blue:0.20)
    static let bakeryMuted = Color(red:0.40,green:0.44,blue:0.51)
    static let bakeryAccent = Color(red:0.27,green:0.37,blue:0.60)
}
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 28
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius:radius))
        } else {
            content.background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:radius))
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.white.opacity(0.8),lineWidth:1))
        }
    }
}
struct BakeryBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.bakeryBG
                Ellipse().fill(Color(red:0.76,green:0.82,blue:0.94).opacity(0.65)).frame(width:geometry.size.width,height:geometry.size.height * 0.65).blur(radius:75).offset(x:120,y:-180)
                Ellipse().fill(Color(red:0.95,green:0.82,blue:0.75).opacity(0.55)).frame(width:340,height:380).blur(radius:80).offset(x:-150,y:200)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
