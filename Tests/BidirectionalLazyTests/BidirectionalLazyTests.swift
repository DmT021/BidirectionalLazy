import XCTest
@testable import BidirectionalLazy

final class BidirectionalLazyTests: XCTestCase {
  static func test_constant_over_time() {
    let l = Lazy<Bool>(getter: { .random() })
    let v = l.value
    for _ in 0..<1000 {
      XCTAssertEqual(v, l.value)
    }
  }

  static func test_map_transform_is_called_once() {
    let l1 = Lazy<Bool>(getter: { .random() })
    var l2_transform_callCount = 0
    let l2 = l1.map {
      l2_transform_callCount += 1
      return !$0
    }
    _ = l1.value
    XCTAssertEqual(l2_transform_callCount, 1)
    _ = l1.value
    XCTAssertEqual(l2_transform_callCount, 1)
    _ = l2.value
    XCTAssertEqual(l2_transform_callCount, 1)
  }

  static func test_hz() {
    let l1 = Lazy<Bool>(getter: { true })
    let l2 = l1.map { !$0 }
    l1.whenLoaded { _ in
      XCTAssertEqual(l2.value, true)
    }
    XCTAssertEqual(l2.value, true)
  }

  static func test_subscribe_during_preloading() {
    let l1 = Lazy<Bool>(getter: { true })
    let l2 = l1.map { !$0 }
    var l1_whenLoaded_callCount = 0
    var l2_whenLoaded_callCount = 0
    l1.whenLoaded { _ in
      l1_whenLoaded_callCount += 1
      l2.whenLoaded { _ in
        l2_whenLoaded_callCount += 1
      }
    }
    XCTAssertEqual(l1.value, true)
    XCTAssertEqual(l1_whenLoaded_callCount, 1)
    XCTAssertEqual(l2_whenLoaded_callCount, 1)
  }

  static func test_subscribe_during_loading() {
    var l1_whenLoaded_callCount = 0
    var l1: Lazy<Bool>!
    l1 = Lazy<Bool>(getter: {
      l1.whenLoaded { _ in
        l1_whenLoaded_callCount += 1
      }
      return true
    })
    XCTAssertEqual(l1.value, true)
    assert(l1_whenLoaded_callCount == 1)
  }

  static func test_root_release_impl_after_loaded() {
    var impl: LazyRootImpl<Int>! = .init(getter: { 1 })
    weak var weakImpl = impl
    let l = Lazy(impl: impl, associatedObject: nil)
    impl = nil
    XCTAssertNotNil(weakImpl)
    XCTAssertEqual(l.value, 1)
    XCTAssertNil(weakImpl)
  }

  static func test_mapped_release_impl_after_loaded() {
    let l1 = Lazy(getter: { 1 })
    let l = l1.map(transform: { "\($0 + 1)" })
    weak var weakImpl = l._test_impl!
    XCTAssertNotNil(weakImpl)
    XCTAssertEqual(l.value, "2")
    XCTAssertNil(weakImpl)
  }

  static func test_loosing_mapped_lazy_is_ok() {
    let l = Lazy(getter: { 1 })
    var r1: Int?
    l.whenLoaded {
      r1 = $0
    }

    var r2: String?
    l.map { "\($0 + 1)" }.whenLoaded {
      r2 = $0 as String
    }

    _ = l.value

    XCTAssertEqual(r1, 1)
    XCTAssertEqual(r2, "2")
  }

  static func test_loosing_source_lazy_is_ok() {
    var l1: Lazy<Int>! = Lazy(getter: { 1 })
    var r1: Int?
    l1?.whenLoaded {
      r1 = $0
    }

    let l2: Lazy<String>! = l1.map { "\($0 + 1)" }
    var r2: String?
    l2.whenLoaded {
      r2 = $0
    }

    l1 = nil
    _ = l2.value

    XCTAssertEqual(r1, 1)
    XCTAssertEqual(r2, "2")
  }

  static func test_reports_error_when_becomes_unreachable() {
    var l1: Lazy<Int>! = Lazy(getter: { 1 })
    var r1: Lazy<Int>.Result?
    l1?.whenCompleted {
      r1 = $0
    }

    var l2: Lazy<String>! = l1.map { "\($0 + 1)" }
    var r2: Lazy<String>.Result?
    l2.whenCompleted {
      r2 = $0
    }

    l1 = nil
    l2 = nil
    _ = l2.value

    XCTAssertTrue(r1?.isFailure ?? false)
    XCTAssertTrue(r2?.isFailure ?? false)
  }
}

extension Result {
  fileprivate var isFailure: Bool {
    switch self {
    case .success:
      return false
    case .failure:
      return true
    }
  }
}

extension Lazy {
  fileprivate var _test_impl: LazyImpl<T>? {
    switch _state {
    case let .created(impl, _), let .loading(impl, _):
      return impl
    case .loaded:
      return nil
    }
  }
}
