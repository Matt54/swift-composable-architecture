import Perception
import SwiftUI

extension Binding {
  // TODO: Document
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    let isInViewBody = PerceptionLocals.isInPerceptionTracking
    return Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: {
        // TODO: Can this be localized to the `Perception` framework?
        PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
          self.wrappedValue.scope(state: state, action: action)
        }
      },
      set: { _ in }
    )
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Bindable {
  // TODO: Document
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: { self.wrappedValue.scope(state: state, action: action) },
      set: { _ in }
    )
  }
}

extension BindableStore {
  // TODO: Document
  public func scope<ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>> {
    Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: { self.wrappedValue.scope(state: state, action: action) },
      set: { _ in }
    )
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStack {
  /// Drives a navigation stack with a store.
  ///
  /// > Warning: The feature state containing ``StackState`` must be annotated with
  /// > ``ObservableObject`` for navigation to be observed.
  ///
  /// See the dedicated article on <doc:Navigation> for more information on the library's navigation
  /// tools, and in particular see <doc:StackBasedNavigation> for information on using this view.
  public init<State, Action, Destination: View, R>(
    path: Binding<Store<StackState<State>, StackAction<State, Action>>>,
    root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  )
  where
    Data == StackState<State>.PathView,
    Root == ModifiedContent<R, _NavigationDestinationViewModifier<State, Action, Destination>>
  {
    self.init(
      path: Binding(
        get: { path.wrappedValue.observableState._path },
        set: { pathView, transaction in
          if pathView.count > path.wrappedValue.withState({ $0 }).count,
            let component = pathView.last
          {
            path.wrappedValue.send(
              .push(id: component.id, state: component.element),
              transaction: transaction
            )
          } else {
            path.wrappedValue.send(
              .popFrom(id: path.wrappedValue.withState { $0 }.ids[pathView.count]),
              transaction: transaction
            )
          }
        }
      )
    ) {
      root()
        .modifier(
          _NavigationDestinationViewModifier(store: path.wrappedValue, destination: destination)
        )
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(value:label:)` for more.
  ///
  /// - Parameters:
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  ///   - label: A label that describes the view that this link presents.
  public init<P, L: View>(
    state: P?,
    @ViewBuilder label: () -> L,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, L> {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { StackState.Component(id: stackElementID(), element: $0) }) {
      _NavigationLinkStoreContent<P, L>(
        state: state, label: { label() }, fileID: fileID, line: line
      )
    }
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a localized string key.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - titleKey: A localized string that describes the view that this link
  ///     presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  public init<P>(
    _ titleKey: LocalizedStringKey, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(titleKey) }, fileID: fileID, line: line)
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a title string.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for a
  /// parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - title: A string that describes the view that this link presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a copy
  ///     of the value. Pass a `nil` value to disable the link.
  @_disfavoredOverload
  public init<S: StringProtocol, P>(
    _ title: S, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(title) }, fileID: fileID, line: line)
  }
}

public struct _NavigationLinkStoreContent<State, Label: View>: View {
  let state: State?
  @ViewBuilder let label: Label
  let fileID: StaticString
  let line: UInt
  @Environment(\._navigationDestinationType) var navigationDestinationType

  public var body: some View {
    #if DEBUG
      self.label.onAppear {
        if self.navigationDestinationType != State.self {
          runtimeWarn(
            """
            A navigation link at "\(self.fileID):\(self.line)" is unpresentable. …

              NavigationStackStore element type:
                \(self.navigationDestinationType.map(_typeName) ?? "(None found in view hierarchy)")
              NavigationLink state type:
                \(typeName(State.self))
              NavigationLink state value:
              \(String(customDumping: self.state).indent(by: 2))
            """
          )
        }
      }
    #else
      self.label
    #endif
  }
}

private struct NavigationDestinationTypeKey: EnvironmentKey {
  static var defaultValue: Any.Type? { nil }
}

extension EnvironmentValues {
  public var _navigationDestinationType: Any.Type? {
    get { self[NavigationDestinationTypeKey.self] }
    set { self[NavigationDestinationTypeKey.self] = newValue }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct _NavigationDestinationViewModifier<
  State: ObservableState, Action, Destination: View
>:
  ViewModifier
{
  @SwiftUI.State var store: Store<StackState<State>, StackAction<State, Action>>
  fileprivate let destination: (Store<State, Action>) -> Destination

  public func body(content: Content) -> some View {
    content
      .environment(\._navigationDestinationType, State.self)
      .navigationDestination(for: StackState<State>.Component.self) { component in
        var state = component.element
        WithPerceptionTracking {
          self
            .destination(
              self.store._scope(
                state: {
                  state = $0[id: component.id] ?? state
                  return state
                },
                id: _ScopeID(
                  state: \StackState<State>.[id: component.id],
                  action: \StackAction<State, Action>.Cases[id: component.id]
                ),
                action: { .element(id: component.id, action: $0) },
                isInvalid: { !$0.ids.contains(component.id) },
                removeDuplicates: nil
              )
            )
            .environment(\._navigationDestinationType, State.self)
        }
      }
  }
}

extension StackState {
  public var _path: PathView {
    _read { yield PathView(base: self) }
    _modify {
      var path = PathView(base: self)
      yield &path
      self = path.base
    }
    set { self = newValue.base }
  }

  public struct Component: Hashable {
    public let id: StackElementID
    public internal(set) var element: Element

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }

  public struct PathView: MutableCollection, RandomAccessCollection,
    RangeReplaceableCollection
  {
    var base: StackState

    public var startIndex: Int { self.base.startIndex }
    public var endIndex: Int { self.base.endIndex }
    public func index(after i: Int) -> Int { self.base.index(after: i) }
    public func index(before i: Int) -> Int { self.base.index(before: i) }

    public subscript(position: Int) -> Component {
      _read {
        yield Component(id: self.base.ids[position], element: self.base[position])
      }
      _modify {
        let id = self.base.ids[position]
        var component = Component(id: id, element: self.base[position])
        yield &component
        self.base[id: id] = component.element
      }
      set {
        self.base[id: newValue.id] = newValue.element
      }
    }

    init(base: StackState) {
      self.base = base
    }

    public init() {
      self.init(base: StackState())
    }

    public mutating func replaceSubrange<C: Collection>(
      _ subrange: Range<Int>, with newElements: C
    ) where C.Element == Component {
      for id in self.base.ids[subrange] {
        self.base[id: id] = nil
      }
      for component in newElements.reversed() {
        self.base._dictionary
          .updateValue(component.element, forKey: component.id, insertingAt: subrange.lowerBound)
      }
    }
  }
}
