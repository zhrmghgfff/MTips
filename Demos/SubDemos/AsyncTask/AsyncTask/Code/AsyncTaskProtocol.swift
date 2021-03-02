//
//  File.swift
//  
//
//  Created by Ma,Limin on 2020/12/28.
//

import Foundation

// MARK: - 任务结果
extension AsyncTask {
    /// 结果
    public struct Result {
        /// 状态码
        var code: Int
        /// 信息
        var message: String
        /// 数据
        var data: Any?
        /// 多任务结果
        var results: [Result]

        init(_ code: Int,_ message: String = "",_ data: Any? = nil,_ results: [Result] = []) {
            self.code = code
            self.message = message
            self.data = data
            self.results = results
        }
    }
}

// MARK: - 任务状态
extension AsyncTask {
    /// 任务状态
    public enum State {
        /// 空闲
        case idle
        /// 任务中
        case doing
        /// 完成
        case complete(Result)
        /// 错误
        case error(Result)
        /// 取消
        case cancel
        /// 多任务
        case completeAll([Result])
    }
}

//MARK: - 别名
extension AsyncTask {
    public typealias TaskAction = (OneTask) -> Void
    typealias Action = () -> Void
    public typealias ResultAction = (Result) -> Void
    public typealias EndAction = (State) -> Void
    typealias ErrorCallback = (@escaping ResultAction) -> Void
}

//MARK: - 任务协议
public protocol OneTask {
    /// 任务状态
    var state: AsyncTask.State {get set}
    /// 完成
    var complete: AsyncTask.ResultAction? { get set }
    /// 错误
    var error: AsyncTask.ResultAction? { get set }
    /// 结束回调
    var endAction: AsyncTask.EndAction? { get set }
    /// 锁
    var taskLock: pthread_mutex_t { get set }

    /// 开始
    func start()

    /// 结束
    /// - Parameter state: 结束的状态
    func end(_ state:AsyncTask.State)

    /// 取消
    func cancel()

    /// 加锁
    func lock()

    /// 解锁
    func unlock()
}
