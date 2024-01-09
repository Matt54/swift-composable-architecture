import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how multiple independent screens can share state in the Composable \
  Architecture. Each tab manages its own state, and could be in separate modules, but changes in \
  one tab are immediately reflected in the other.

  This tab has its own state, consisting of a count value that can be incremented and decremented, \
  as well as an alert value that is set when asking if the current count is prime.

  Internally, it is also keeping track of various stats, such as min and max counts and total \
  number of count events that occurred. Those states are viewable in the other tab, and the stats \
  can be reset from the other tab.
  """

// MARK: - Feature domain

@Reducer
struct SharedState {
  enum Tab { case counter, profile }

  @ObservableState
  struct State: Equatable {
    var currentTab = Tab.counter
    var counter = CounterTab.State()
    var profile = ProfileTab.State()
  }

  enum Action {
    case counter(CounterTab.Action)
    case profile(ProfileTab.Action)
    case selectTab(Tab)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.counter, action: \.counter) {
      CounterTab()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileTab()
    }

    Reduce { state, action in
      switch action {
      case .counter, .profile:
        return .none
      case let .selectTab(tab):
        state.currentTab = tab
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct SharedStateView: View {
  @State var store = Store(initialState: SharedState.State()) {
    SharedState()
  }

  var body: some View {
    TabView(selection: $store.currentTab.sending(\.selectTab)) {
      NavigationStack {
        CounterTabView(
          store: self.store.scope(state: \.counter, action: \.counter)
        )
      }
      .tag(SharedState.Tab.counter)
      .tabItem { Text("Counter") }

      NavigationStack {
        ProfileTabView(
          store: self.store.scope(state: \.profile, action: \.profile)
        )
      }
      .tag(SharedState.Tab.profile)
      .tabItem { Text("Profile") }
    }
  }
}

@Reducer
struct CounterTab {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    @SharedDependency var stats: Stats
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case decrementButtonTapped
    case incrementButtonTapped
    case isPrimeButtonTapped

    enum Alert: Equatable {}
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .decrementButtonTapped:
        state.stats.decrement()
        return .none

      case .incrementButtonTapped:
        state.stats.increment()
        return .none

      case .isPrimeButtonTapped:
        state.alert = AlertState {
          TextState(
            isPrime(state.stats.count)
            ? "👍 The number \(state.stats.count) is prime!"
            : "👎 The number \(state.stats.count) is not prime :("
          )
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

struct CounterTabView: View {
  @Bindable var store: StoreOf<CounterTab>

  var body: some View {
    Form {
      Text(template: readMe, .caption)

      VStack(spacing: 16) {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.stats.count)")
            .monospacedDigit()

          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }

        Button("Is this prime?") { store.send(.isPrimeButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Shared State Demo")
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

@Reducer
struct ProfileTab {
  @ObservableState
  struct State: Equatable {
    @SharedDependency var stats: Stats

    fileprivate mutating func resetCount() {
      self.stats = Stats()
    }
  }

  enum Action {
    case resetStatsButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .resetStatsButtonTapped:
        state.resetCount()
        return .none
      }
    }
  }
}

struct ProfileTabView: View {
  let store: StoreOf<ProfileTab>

  var body: some View {
    Form {
      Text(
        template: """
            This tab shows state from the previous tab, and it is capable of reseting all of the \
            state back to 0.

            This shows that it is possible for each screen to model its state in the way that makes \
            the most sense for it, while still allowing the state and mutations to be shared \
            across independent screens.
            """,
        .caption
      )

      VStack(spacing: 16) {
        Text("Current count: \(store.stats.count)")
        Text("Max count: \(store.stats.maxCount)")
        Text("Min count: \(store.stats.minCount)")
        Text("Total number of count events: \(store.stats.numberOfCounts)")
        Button("Reset") { store.send(.resetStatsButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Profile")
  }
}

struct Stats: Equatable {
  private(set) var count = 0
  private(set) var maxCount = 0
  private(set) var minCount = 0
  private(set) var numberOfCounts = 0
  mutating func increment() {
    count += 1
    numberOfCounts += 1
    maxCount = max(minCount, count)
  }
  mutating func decrement() {
    count -= 1
    numberOfCounts += 1
    minCount = min(minCount, count)
  }
}

extension Stats: DependencyKey {
  static var liveValue: Self {
    Self()
  }
  static var testValue: Self {
    Self()
  }
}

// MARK: - SwiftUI previews

struct SharedState_Previews: PreviewProvider {
  static var previews: some View {
    SharedStateView()
  }
}

// MARK: - Private helpers

/// Checks if a number is prime or not.
private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}
