import SwiftUI

// MARK: - Color Palette (Earth Tones)

extension ShapeStyle where Self == Color {
    static var terracotta: Color   { Color(red: 0.722, green: 0.361, blue: 0.220) } // #B85C38
    static var appBackground: Color { Color(red: 0.969, green: 0.949, blue: 0.933) } // #F7F2EE
    static var cardBackground: Color { Color(red: 0.992, green: 0.980, blue: 0.969) } // #FDFAF7
    static var textPrimary: Color  { Color(red: 0.165, green: 0.118, blue: 0.078) } // #2A1E14
    static var textSecondary: Color { Color(red: 0.478, green: 0.400, blue: 0.329) } // #7A6654
    static var warmBorder: Color   { Color(red: 0.886, green: 0.835, blue: 0.784) } // #E2D5C8
    static var sageGreen: Color    { Color(red: 0.353, green: 0.478, blue: 0.329) } // #5A7A54
}

extension Color {
    static var terracotta: Color   { Color(red: 0.722, green: 0.361, blue: 0.220) }
    static var appBackground: Color { Color(red: 0.969, green: 0.949, blue: 0.933) }
    static var cardBackground: Color { Color(red: 0.992, green: 0.980, blue: 0.969) }
    static var textPrimary: Color  { Color(red: 0.165, green: 0.118, blue: 0.078) }
    static var textSecondary: Color { Color(red: 0.478, green: 0.400, blue: 0.329) }
    static var warmBorder: Color   { Color(red: 0.886, green: 0.835, blue: 0.784) }
    static var sageGreen: Color    { Color(red: 0.353, green: 0.478, blue: 0.329) }
}

// MARK: - Nunito Font

extension Font {
    static func app(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .custom("Nunito", size: style.nunitoSize, relativeTo: style)
            .weight(weight)
    }
}

private extension Font.TextStyle {
    var nunitoSize: CGFloat {
        switch self {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .subheadline: return 15
        case .body:        return 16
        case .callout:     return 15
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        @unknown default:  return 16
        }
    }
}

// MARK: - App Nav Bar

struct AppNavBar: ViewModifier {
    let title: String
    let onSettings: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbarRole(.editor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.terracotta)

                        Text("PinSave")
                            .font(.app(.headline, weight: .black))
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize()
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
    }
}

extension View {
    func appNavBar(title: String, onSettings: @escaping () -> Void) -> some View {
        modifier(AppNavBar(title: title, onSettings: onSettings))
    }
}

// MARK: - Card Style

struct CardModifier: ViewModifier {
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.warmBorder, lineWidth: 1)
            )
            .shadow(color: Color.textPrimary.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
