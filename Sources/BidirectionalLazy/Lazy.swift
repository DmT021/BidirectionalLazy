//
//  File.swift
//  
//
//  Created by Dmitry Galimzyanov on 27.10.2023.
//

public struct LazyBecameUnreachable: Error {
  @inlinable
  init() {}
}

public class Lazy<T> {
  public typealias Value = T
  public typealias Result = Swift.Result<T, LazyBecameUnreachable>
  public typealias CompletedAction = (Result) -> Void
  public typealias ResultAction = (T) -> Void

  internal enum State {
    case created(impl: LazyImpl<T>, associatedObject: AnyObject?)
    case loading(impl: LazyImpl<T>, associatedObject: AnyObject?)
    case loaded(T)
  }

  internal var _state: State

  init(impl: LazyImpl<T>, associatedObject: AnyObject?) {
    _state = .created(impl: impl, associatedObject: associatedObject)
    impl.setInterface(self)
  }

  convenience init(getter: @escaping () -> T) {
    let impl = LazyRootImpl(getter: getter)
    self.init(impl: impl, associatedObject: nil)
  }

  @usableFromInline
  internal func _setLoaded(_ value: T) {
    switch _state {
    case .created, .loading:
      _state = .loaded(value)
    case .loaded:
      assertionFailure()
    }
  }

  public var value: T {
    switch _state {
    case let .created(impl, associatedObject):
      _state = .loading(impl: impl, associatedObject: associatedObject)
      impl.load()
      guard case let .loaded(value) = _state else {
        fatalError()
      }
      return value
    case .loading:
      fatalError()
    case let .loaded(value):
      return value
    }
  }

  public var currentValue: T? {
    switch _state {
    case .created, .loading:
      return nil
    case let .loaded(value):
      return value
    }
  }

  public func map<U>(transform: @escaping (T) -> U) -> Lazy<U> {
    let impl = LazyMappedImpl(source: self, transform: transform)
    whenLoaded { value in
      impl.accept(value)
    }
    return Lazy<U>(
      impl: impl,
      associatedObject: self
    )
  }

  public func whenLoaded(perform action: @escaping ResultAction) {
    whenCompleted { result in
      switch result {
      case let .success(value):
        action(value)
      case .failure:
        return
      }
    }
  }

  public func whenCompleted(perform action: @escaping CompletedAction) {
    switch _state {
    case let .created(impl, _), let .loading(impl, _):
      impl.whenCompleted(perform: action)
    case let .loaded(value):
      action(.success(value))
    }
  }
}
