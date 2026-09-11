#if os(iOS)
import SwiftUI

public enum PokerTheme {
    public static let background = Color(red: 0.047, green: 0.067, blue: 0.063)
    public static let surface = Color(red: 0.086, green: 0.110, blue: 0.102)
    public static let raised = Color(red: 0.122, green: 0.149, blue: 0.137)
    public static let border = Color(red: 0.24, green: 0.28, blue: 0.25)
    public static let text = Color(red: 0.957, green: 0.945, blue: 0.898)
    public static let muted = Color(red: 0.65, green: 0.70, blue: 0.65)
    public static let gold = Color(red: 0.86, green: 0.72, blue: 0.46)
    public static let green = Color(red: 0.53, green: 0.84, blue: 0.65)
    public static let red = Color(red: 0.98, green: 0.54, blue: 0.49)
    public static let ivory = Color(red: 0.965, green: 0.949, blue: 0.902)
    public static let cardInk = Color(red: 0.09, green: 0.16, blue: 0.13)
    public static let cardRed = Color(red: 0.66, green: 0.16, blue: 0.20)
    public static let radius: CGFloat = 24
}

struct CasinoPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(PokerTheme.surface, in: RoundedRectangle(cornerRadius: PokerTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: PokerTheme.radius).strokeBorder(PokerTheme.border.opacity(0.55), lineWidth: 1))
    }
}

extension View {
    func casinoPanel() -> some View { modifier(CasinoPanel()) }
}

struct CasinoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
#endif
