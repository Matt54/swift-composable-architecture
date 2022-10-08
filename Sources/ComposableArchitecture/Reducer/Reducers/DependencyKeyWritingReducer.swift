extension ReducerProtocol {
  /// Sets the dependency value of the specified key path to the given value.
  ///
  /// This overrides the dependency specified by `keyPath` for the execution of the receiving
  /// reducer _and_ all of its effects. It can be useful for altering the dependencies for just
  /// one portion of your application, while letting the rest of the application continue using the
  /// default live dependencies.
  ///
  /// For example, suppose you are creating an onboarding experience to teach people how to use one
  /// of your features. This can be done by constructing a new reducer that embeds the core
  /// feature's domain and layers on additional logic:
  ///
  /// ```swift
  /// struct Onboarding: ReducerProtocol {
  ///   struct State {
  ///     var feature: Feature.State
  ///     // Additional onboarding state
  ///   }
  ///   enum Action {
  ///     case feature(Feature.Action)
  ///     // Additional onboarding actions
  ///   }
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     Scope(state: \.feature, action: /Action.feature) {
  ///       Feature()
  ///     }
  ///
  ///     Reduce { state, action in
  ///       // Additional onboarding logic
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// This can work just fine, but the `Feature` reducer will have access to all of the live
  /// dependencies by default, and that might not be ideal. For example, the `Feature` reducer
  /// may need to make API requests and read/write from user defaults. It may be preferable
  /// to run the `Feature` reducer in an alternative environment for onboarding purposes, such
  /// as an API client that returns some mock data or an in-memory user defaults so that the
  /// onboarding experience doesn't accidentally trample on shared data.
  ///
  /// This can be by using the ``dependency(_:_:)`` method to override those dependencies
  /// just for the `Feature` reducer and its effects:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Scope(state: \.feature, action: /Action.feature) {
  ///     Feature()
  ///       .dependency(\.apiClient, .mock)
  ///       .dependency(\.userDefaults, .mock)
  ///   }
  ///
  ///   Reduce { state, action in
  ///     // Additional onboarding logic
  ///   }
  /// }
  /// ```
  ///
  /// See ``dependencies(_:)`` for a similar method that can modify multiple dependencies at once,
  /// and allows you to inspect the current dependency when overriding.
  ///
  /// - Parameters:
  ///   - keyPath: A key path that indicates the property of the `DependencyValues` structure to
  ///     update.
  ///   - value: The new value to set for the item specified by `keyPath`.
  /// - Returns: A reducer that has the given value set in its dependencies.
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  )
  // NB: We should not return `some ReducerProtocol<State, Action>` here. That would prevent the
  //     specialization defined below from being called, which fuses chained calls to `dependency`.
  -> _DependencyKeyWritingReducer<Self> {
    _DependencyKeyWritingReducer(base: self) { $0[keyPath: keyPath] = value }
  }

  /// Modifies a reducer's dependencies with a closure.
  ///
  /// This is similar to ``dependency(_:_:)``, except it allows you to mutate all depependencies
  /// at once. This can be handy when you want to alter a dependency but still use its current
  /// value.
  ///
  /// For example, suppose you want to see when a particular endpoint of a dependency gets called
  /// in your application. You can override that endpoint to insert a breakpoint or print state,
  /// but still call out to the original endpoint:
  ///
  /// ```swift
  ///   Feature()
  ///     .dependencies { values in
  ///       let current = speechClient.requestAuthorization
  ///       values.speechClient.requestAuthorization = {
  ///         print("requestAuthorization")
  /// 🔵      try await current()
  ///       }
  ///     }
  /// ```
  ///
  /// - Parameter update: A closure that is handed a mutable instance of dependency values.
  @inlinable
  public func dependencies(_ update: @escaping (inout DependencyValues) -> Void)
  // TODO: this isn't actually true, but we also can't use `some` until dropping support for swift 5.6
  // NB: We should not return `some ReducerProtocol<State, Action>` here. That would prevent the
  //     specialization defined below from being called, which fuses chained calls to `dependency`.
  -> _DependencyKeyWritingReducer<Self> {
    _DependencyKeyWritingReducer(base: self, update: update)
  }
}

public struct _DependencyKeyWritingReducer<Base: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let base: Base

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @inlinable
  init(base: Base, update: @escaping (inout DependencyValues) -> Void) {
    self.base = base
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> Effect<Base.Action, Never> {
    return DependencyValues.withValues {
      self.update(&$0)
    } operation: {
      self.base.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(base: self.base) { values in
      values[keyPath: keyPath] = value
      self.update(&values)
    }
  }
}