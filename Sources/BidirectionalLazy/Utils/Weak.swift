//
//  File.swift
//  
//
//  Created by Dmitry Galimzyanov on 27.10.2023.
//

@usableFromInline
internal struct _Weak<T: AnyObject>: ExpressibleByNilLiteral {
  @usableFromInline
  internal weak var value: T?

  @inlinable
  internal init(_ value: T?) {
    self.value = value
  }

  @inlinable
  internal init(nilLiteral: ()) {
    value = nil
  }
}
