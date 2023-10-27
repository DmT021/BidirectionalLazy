//
//  File.swift
//  
//
//  Created by Dmitry Galimzyanov on 27.10.2023.
//

@usableFromInline
internal final class LazyMappedImpl<T, U>: LazyImpl<T> {
  @usableFromInline
  typealias Transform = (U) -> T

  @usableFromInline
  enum State {
    case pending(
      transform: Transform,
      actions: [CompletedAction],
      interface: _Weak<Lazy<T>>,
      source: _Weak<Lazy<U>>
    )
    case loading(actions: [CompletedAction])
    case loaded
  }

  @usableFromInline
  var _state: State

  @inlinable
  init(source: Lazy<U>, transform: @escaping Transform) {
    _state = .pending(
      transform: transform,
      actions: [],
      interface: nil,
      source: _Weak(source)
    )
  }

  @inlinable
  override func setInterface(_ interface: Lazy<T>) {
    switch _state {
    case let .pending(transform, actions, _, source):
      _state = .pending(
        transform: transform,
        actions: actions,
        interface: _Weak(interface),
        source: source
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
    case let .pending(_, actions, _, _):
      assert(actions.isEmpty)
    }
  }

  @inlinable
  override func load() {
    switch _state {
    case let .pending(_, _, _, source):
      _ = source.value!.value
      guard case .loaded = _state else {
        assertionFailure()
        return
      }

    case .loading, .loaded:
      fatalError()
    }
  }

  @inlinable
  func accept(_ value: U) {
    switch _state {
    case let .pending(transform, actions, interface, _):
      _state = .loading(actions: actions)
      let transformedValue = transform(value)
      guard case let .loading(actions) = _state else {
        fatalError()
      }
      _state = .loaded
      interface.value?._setLoaded(transformedValue)
      for action in actions {
        action(.success(transformedValue))
      }

    case .loading, .loaded:
      fatalError()
    }
  }

  @inlinable
  override func whenCompleted(perform action: @escaping CompletedAction) {
    switch _state {
    case .pending(let transform, var actions, let interface, let source):
      actions.append(action)
      _state = .pending(
        transform: transform,
        actions: actions,
        interface: interface,
        source: source
      )
    case var .loading(actions):
      actions.append(action)
      _state = .loading(actions: actions)
    case .loaded:
      fatalError("Should be dead already")
    }
  }
}
