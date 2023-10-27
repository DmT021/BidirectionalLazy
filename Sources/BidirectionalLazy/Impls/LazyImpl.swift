//
//  File.swift
//  
//
//  Created by Dmitry Galimzyanov on 27.10.2023.
//

@usableFromInline
internal class LazyImpl<T> {
  @usableFromInline
  typealias CompletedAction = Lazy<T>.CompletedAction

  @inlinable
  init() {}

  @inlinable
  deinit {}

  @inlinable
  func setInterface(_ interface: Lazy<T>) {
    fatalError()
  }

  @inlinable
  func load() {
    fatalError()
  }

  @inlinable
  func whenCompleted(perform action: @escaping Lazy<T>.CompletedAction) {
    fatalError()
  }
}
