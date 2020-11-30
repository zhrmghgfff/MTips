//
//  MyGCD.swift
//  AsyncTask
//
//  Created by Ma,Limin on 2020/11/30.
//

import Foundation

public class MyGCD {
    
    public typealias TaskAction = (MyGCD) -> Void
    typealias Action = () -> Void
    public typealias ResultAction = (Result) -> Void
    public typealias EndAction = (State) -> Void
    typealias ErrorCallback = (@escaping ResultAction) -> Void

    /// 结果
    public struct Result {
        /// 状态码
        var code: Int
        /// 信息
        var message: String
        /// 数据
        var data: Any?

        init(_ code: Int,_ message: String = "",_ data: Any? = nil) {
            self.code = code
            self.message = message
            self.data = data
        }
    }

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
    }
    
    /// 下一个 Task
    fileprivate var nextTask: MyGCD?
    /// 任务
    fileprivate var task: Task?
    
    /// 队列
    fileprivate static var queue: DispatchQueue?
    /// 默认队列
    fileprivate static var defaultQueue: DispatchQueue = DispatchQueue(label: "AsyncTask", qos: .default, attributes: .concurrent)

    /// 错误处理已经添加的回调
    fileprivate var errorDidAdded: ErrorCallback?
    
    ///记录总创建的个数
    fileprivate static var count:Int = 0
    /// 标记，区分每个不同的对象
    fileprivate var tag: Int
    
    init() {

        tag = MyGCD.count

        print("init : \(tag)")

        MyGCD.count += 1
    }

    deinit {
        print("deinit : \(tag)")
    }
    
    // MARK: - 任务处理
    /// 任务
    /// - Parameter task: block 任务
    /// - Returns: AsyncTask
    @discardableResult
    public func task(_ task:@escaping TaskAction) -> Self {

        addTask(task)
        start()

        return self
    }

    /// 开始任务
    /// - Returns: AsyncTask
    @discardableResult
    public func start() -> Self {
        task?.start()
        return self
    }

    /// 下一个任务
    /// - Parameter action: block 任务
    /// - Returns: MyGCD
    @discardableResult
    public func next(_ task:@escaping TaskAction) -> MyGCD {

        nextTask = createTask(task)

        return nextTask!
    }

    /// 完成处理
    /// - Parameter action: block 处理
    /// - Returns: MyGCD
    @discardableResult
    public func complete(_ action:@escaping ResultAction) -> MyGCD {
        task?.complete = action
        return self
    }

    /// 错误处理
    /// - Parameter action: block 处理
    /// - Returns: MyGCD
    @discardableResult
    public func error(_ action:@escaping ResultAction) -> MyGCD {
        task?.error = action
        transmitError(action)

        return self
    }

    /// 任务结束
    fileprivate func end(_ state: State) {
        switch state {
            case .complete(_):
                fallthrough
            case .error(_):
                break//nextTask?.task?.cancel()
            case .cancel:
                break//nextTask?.task?.cancel()
            default:
                break
        }

        nextTask = nil
    }

    // MARK: 私有函数
    fileprivate func addTask(_ task:@escaping TaskAction) {
        self.task = Task(task)

        var gcd:MyGCD? = self
        self.task?.endAction = { state in
            gcd?.end(state)

            gcd = nil
        }
    }
}

// MARK: -
extension MyGCD {
    /// 任务
    class Task {
        /// 任务Block
        var task: TaskAction
        /// 任务状态
        var state: State = .idle
        /// 完成
        var complete: ResultAction?
        /// 错误
        var error: ResultAction?
        /// 结束回调
        var endAction: EndAction?

        /// 线程锁
        var taskLock:pthread_mutex_t = pthread_mutex_t()

        init(_ task: @escaping TaskAction) {
            self.task = task

            pthread_mutex_init(&taskLock, nil)
        }

        func start() {

            lock()
            guard case .idle = state else {
                unlock()
                return
            }

            state = .doing
            unlock()

//            AsyncTask.startTask { [weak self] in
//                guard let self = self else {
//                    return
//                }
//
//                self.task(self)
//            }
        }

        func end(_ state:State) {

            lock()
            self.state = state
            unlock()

            switch state {
                case .complete(let result):
                    if let complete = complete {
                        complete(result)
                }
                case .error(let result):
                    if let error = error  {
                        error(result)
                }
                default:
                    break
            }

            if let endAction = endAction {
                endAction(state)
            }
        }

        func cancel() {

            lock()
            guard case .idle = state else {
                unlock()
                return
            }

            state = .cancel
            unlock()

            if let endAction = endAction {
                endAction(state)
            }
        }
        
        // MARK: 锁
        func lock() {
            pthread_mutex_lock(&self.taskLock);
        }
        func unlock() {
            pthread_mutex_unlock(&self.taskLock);
        }
    }
}

// MARK: 私有辅助函数
extension MyGCD {

    /// 创建Task
    fileprivate func createTask(_ task: @escaping TaskAction) -> MyGCD {

        let newTask = MyGCD()
        newTask.errorDidAdded = {[weak self] action in
            if self?.task?.error == nil {
                self?.error(action)
            }else{
                self?.transmitError(action)
            }
        }

        newTask.addTask(task)

        return newTask
    }

    /// 传递Error处理
    fileprivate func transmitError(_ action:@escaping ResultAction) {

        if let errorDidAdded = errorDidAdded {
            errorDidAdded(action)
        }
    }

//    /// 开始任务
//    /// - Parameter action: 任务 block
//    fileprivate static func startTask(_ action:@escaping Action) {
//        self.queue.async(execute: action)
//    }
}

// MARK: 快捷方法
extension MyGCD {

    /// 任务
    /// - Parameter task: block 任务
    /// - Returns: AsyncTask
    @discardableResult
    public static func task(_ task:@escaping TaskAction) -> MyGCD {
        return MyGCD().task(task)
    }
}

extension MyGCD.Result {
    public static var success: MyGCD.Result {
        get {
            return MyGCD.Result(200)
        }
    }

    public static func result(_ code: Int,_ message: String?,_ data: Any? = nil) -> MyGCD.Result {
        return MyGCD.Result(code,message ?? "",data)
    }
}

extension MyGCD.State {
    public static func sucess(_ data:Any? = nil) -> MyGCD.State {
        return .complete(.result(200, nil, data))
    }

    public static func error(_ code: Int,_ message: String? = nil,_ data: Any? = nil) -> MyGCD.State {
        return .error(.result(code, message, data))
    }
}
