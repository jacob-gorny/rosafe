import SwiftUI

/// An inner page's title: the home word that flew up into the top-left corner.
/// Tapping it goes back home, and the word flies back. Task 5's pages put it in their title row.
struct PageTitle: View {
    let namespace: Namespace.ID
    let page: Page
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onBack) {
            MorphingWord(text: page.title, rest: .title)
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint("Goes back to the home screen")
        .matchedWord(page, in: namespace, enabled: !reduceMotion)
        .transition(reduceMotion ? .wordFade(rest: .title) : .wordMorph(from: .home, rest: .title))
    }
}

/// A word that can morph between two styles while it flies. Its layout always has the size of
/// `rest`, so nothing around it moves; the drawn text, centered on that slot, takes whatever style
/// the transition is passing through.
struct MorphingWord: View {
    let text: String
    let rest: WordStyle
    @Environment(\.wordStyle) private var flying

    var body: some View {
        Text(text)
            .font(Theme.font(rest))
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .overlay {
                Text(text)
                    .font(Theme.font(flying ?? rest))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Theme.ink)
            }
            .contentShape(Rectangle())
    }
}

extension EnvironmentValues {
    /// The style a `MorphingWord` is drawn at while a transition morphs it; nil at rest.
    @Entry var wordStyle: WordStyle? = nil
}

/// Sets `wordStyle`; animatable, so a transition between two of these morphs size and weight.
struct WordMorph: ViewModifier, Animatable {
    var style: WordStyle

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(style.size, style.wght) }
        set { style = WordStyle(size: newValue.first, wght: newValue.second) }
    }

    func body(content: Content) -> some View {
        content.environment(\.wordStyle, style)
    }
}

extension AnyTransition {
    /// The word arrives looking like `from` (the copy it replaces) and morphs to `rest` while
    /// `matchedWord` flies it there. The copy that leaves can't morph (SwiftUI stops updating a
    /// view on its way out), so it fades within a few frames and only the arriving copy is seen.
    static func wordMorph(from: WordStyle, rest: WordStyle) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: WordMorph(style: from), identity: WordMorph(style: rest)),
            removal: AnyTransition.modifier(active: WordMorph(style: rest), identity: WordMorph(style: rest))
                .combined(with: AnyTransition.opacity.animation(.linear(duration: 0.06))))
    }

    /// Reduce Motion: no flight, no morph, just a fade.
    static func wordFade(rest: WordStyle) -> AnyTransition {
        AnyTransition.modifier(active: WordMorph(style: rest), identity: WordMorph(style: rest))
            .combined(with: .opacity)
    }
}

extension View {
    /// Links a home word and its page title, so one leaves where the other arrives.
    @ViewBuilder
    func matchedWord(_ page: Page, in namespace: Namespace.ID, enabled: Bool) -> some View {
        if enabled {
            matchedGeometryEffect(id: page.rawValue, in: namespace, properties: .position)
        } else {
            self
        }
    }
}

/// A slight press-in for words, like the prototype's `scale(.97)`.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
