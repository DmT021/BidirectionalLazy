//
//  File.swift
//  
//
//  Created by Dmitry Galimzyanov on 27.10.2023.
//

@usableFromInline
internal final class LazyRootImpl<T>: LazyImpl<T> {
  @usableFromInline
  typealias Getter = () -> T

  @usableFromInline
  enum State {
    case pending(
      getter: Getter,
      actions: [CompletedAction],
      interface: _Weak<Lazy<T>>
    )
    case loading(actions: [CompletedAction])
    case loaded
  }

  @usableFromInline
  var _state: State

  @inlinable
  init(getter: @escaping Getter) {
    _state = .pending(
      getter: getter,
      actions: [],
      interface: nil
    )
  }

  @inlinable
  override func setInterface(_ interface: Lazy<T>) {
    switch _state {
    case let .pending(getter, actions, _):
      _state = .pending(
        getter: getter,
        actions: actions,
        interface: _Weak(interface)
      )
    case .loading, .loaded:
      assertionFailure()
    }
  }

  @inlinable
  deinit {
    switch _state {
    case .loaded:
      break
    case .loading:
      fatalError()
    case let .pending(_, actions, _):
      for action in actions {
        action(.failure(LazyBecameUnreachable()))
      }
    }
  }

  @inlinable
  override func load() {
    switch _state {
    case let .pending(getter, actions, interface):
      _state = .loading(actions: actions)
      let value = getter()
      guard case let .loading(actions) = _state else {
        assertionFailure()
        return
      }
      _state = .loaded
      interface.value?._setLoaded(value)
      for action in actions {
        action(.success(value))
      }

    case .loading, .loaded:
      fatalError()
    }
  }

  @inlinable
  override func whenCompleted(perform action: @escaping Lazy<T>.CompletedAction) {
    switch _state {
    case .pending(let getter, var actions, let interface):
      actions.append(action)
      _state = .pending(getter: getter, actions: actions, interface: interface)
    case var .loading(actions):
      actions.append(action)
      _state = .loading(actions: actions)
    case .loaded:
      assertionFailure()
    }
  }
}
