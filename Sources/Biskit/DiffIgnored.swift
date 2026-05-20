//
//  File.swift
//  Biskit
//
//  Created by lyfeoncloudnine on 5/20/26.
//

import Foundation

/// 상태(State) 비교 시 특정 프로퍼티의 변경사항을 무시하도록 만드는 프로퍼티 래퍼입니다.
///
/// 뷰의 리렌더링과 무관한 데이터 (예: 내부 캐시용 데이터, 스크롤 오프셋, 이벤트 트래킹용 속성 등)에 적용합니다.
/// 이 래퍼가 씌워진 프로퍼티는 값이 변경되어도 `==` 비교 시 항상 `true`를 반환하므로,
/// 불필요한 뷰 렌더링(State 갱신)을 방지하는 최적화 용도로 사용됩니다.
@propertyWrapper
public struct DiffIgnored<Value>: Equatable {
    public var wrappedValue: Value
    
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
    
    public static func == (lhs: DiffIgnored<Value>, rhs: DiffIgnored<Value>) -> Bool {
        return true
    }
}
