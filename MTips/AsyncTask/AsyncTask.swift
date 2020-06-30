//
//  AsyncTask.swift
//  MTips
//
//  Created by zhrmghgfff on 2020/7/1.
//  Copyright © 2020 zhrmghgfff. All rights reserved.
//

import Foundation

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

extension OneTask {
    // MARK: 锁
    func lock() {
        var `self` = self
        pthread_mutex_lock(&self.taskLock);
    }
    func unlock() {
        var `self` = self
        pthread_mutex_unlock(&self.taskLock);
    }
}

// MARK: - AsyncTask
public class AsyncTask {

    public typealias TaskAction = (OneTask) -> Void
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
        /// 多任务结果
        var results: [Result]

        init(_ code: Int,_ message: String = "",_ data: Any? = nil,_ results: [Result] = []) {
            self.code = code
            self.message = message
            self.data = data
            self.results = results
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
        /// 多任务
        case completeAll([Result])
    }

    ///记录总创建的个数
    fileprivate static var count:Int = 0
    /// 标记，区分每个不同的对象
    fileprivate var tag: Int

    /// 下一个 Task
    fileprivate var nextTask: AsyncTask?
    /// 任务
    fileprivate var task: OneTask?

    /// 错误处理已经添加的回调
    fileprivate var errorDidAdded: ErrorCallback?

    /// 队列
    fileprivate static var queue: DispatchQueue = DispatchQueue(label: "AsyncTask", qos: .default, attributes: .concurrent)

    init() {

        tag = AsyncTask.count

        print("init : \(tag)")

        AsyncTask.count += 1
    }

    deinit {
        print("deinit : \(tag)")
    }

    // MARK: 任务处理

    /// 任务
    /// - Parameter task: block 任务
    /// - Returns: AsyncTask
    @discardableResult
    public func task(_ task:@escaping TaskAction) -> AsyncTask {

        addTask(task)
        start()

        return self
    }

    /// 开始任务
    /// - Returns: AsyncTask
    @discardableResult
    public func start() -> AsyncTask {
        task?.start()
        return self
    }

    /// 下一个任务
    /// - Parameter action: block 任务
    /// - Returns: MyGCD
    @discardableResult
    public func next(_ task:@escaping TaskAction) -> AsyncTask {

        nextTask = createTask(task)

        return nextTask!
    }

    /// 完成处理
    /// - Parameter action: block 处理
    /// - Returns: MyGCD
    @discardableResult
    public func complete(_ action:@escaping ResultAction) -> AsyncTask {
        task?.complete = action
        return self
    }

    /// 错误处理
    /// - Parameter action: block 处理
    /// - Returns: MyGCD
    @discardableResult
    public func error(_ action:@escaping ResultAction) -> AsyncTask {
        task?.error = action
        transmitError(action)

        return self
    }

    /// 任务结束
    fileprivate func end(_ state: State) {
        switch state {
            case .complete(_):
                fallthrough
            case .completeAll(_):
                if let nextTask = nextTask {
                    nextTask.start()
            }
            case .error(_):
                nextTask?.task?.cancel()
            case .cancel:
                nextTask?.task?.cancel()
            default:
                break
        }

        nextTask = nil
    }

    // MARK: 私有函数
    fileprivate func addTask(_ task:@escaping TaskAction) {
        self.task = Task(task)

        var gcd:AsyncTask? = self
        self.task?.endAction = { state in
            gcd?.end(state)

            gcd = nil
        }
    }
}

// MARK: 私有辅助函数
extension AsyncTask {

    /// 创建Task
    fileprivate func createTask(_ task: @escaping TaskAction) -> AsyncTask {

        let newTask = AsyncTask()
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

    /// 创建MutiTask
    fileprivate func createMutiTask(_ tasks:[TaskAction]) -> AsyncTask {

        let newTask = AsyncMutiTask()
        newTask.errorDidAdded = {[weak self] action in
            if self?.task?.error == nil {
                self?.error(action)
            }else{
                self?.transmitError(action)
            }
        }

        newTask.addTasks(tasks)

        return newTask
    }

    /// 传递Error处理
    fileprivate func transmitError(_ action:@escaping ResultAction) {

        if let errorDidAdded = errorDidAdded {
            errorDidAdded(action)
        }
    }

    /// 开始任务
    /// - Parameter action: 任务 block
    fileprivate static func startTask(_ action:@escaping Action) {
        self.queue.async(execute: action)
    }
}

// MARK: 快捷方法
extension AsyncTask {

    /// 下一组任务
    /// - Parameter tasks: 任务数组
    /// - Returns: AsyncTask
    public func nexts(_ tasks:[TaskAction]) -> AsyncTask {

        nextTask = createMutiTask(tasks)

        return nextTask!
    }

    /// 任务
    /// - Parameter task: block 任务
    /// - Returns: AsyncTask
    @discardableResult
    public static func task(_ task:@escaping TaskAction) -> AsyncTask {
        return AsyncTask().task(task)
    }

    /// 任务
    /// - Parameter tasks: block 数组
    /// - Returns: AsyncTask
    @discardableResult
    public static func tasks(_ tasks:[TaskAction]) -> AsyncTask {
        return AsyncMutiTask().tasks(tasks)
    }
}

// MARK: - MutiTask
class AsyncMutiTask: AsyncTask {

    override init() {
        super.init()

        self.task = MutiTask()
        var gcd:AsyncTask? = self
        self.task?.endAction = { state in
            gcd?.end(state)

            gcd = nil
        }
    }

    /// 任务
    /// - Parameter tasks: block 数组
    /// - Returns: AsyncTask
    @discardableResult
    public func tasks(_ tasks:[TaskAction]) -> AsyncTask {
        addTasks(tasks)
        start()
        return self
    }

    /// 开始任务
    /// - Returns: AsyncTask
    @discardableResult
    public override func start() -> AsyncTask {
        self.task?.start()
        return self
    }

    // MARK: 私有函数
    fileprivate func addTasks(_ tasks:[TaskAction]) {
        guard let mutiTask = self.task as? MutiTask else {
            return
        }

        for task in tasks {
            mutiTask.add(Task(task))
        }
    }

    override fileprivate func addTask(_ task: @escaping TaskAction) {
        guard let mutiTask = self.task as? MutiTask else {
            return
        }
        mutiTask.add(Task(task))
    }
}

// MARK: -
extension AsyncTask {
    /// 任务
    class Task:OneTask {
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

            AsyncTask.startTask { [weak self] in
                guard let self = self else {
                    return
                }

                self.task(self)
            }
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
    }
}

extension AsyncMutiTask {

    class MutiTask:OneTask {
        ///任务List
        var tasks: [Task] = [Task]()
        /// 状态
        var state: State = .idle
        /// 完成
        var complete: ResultAction?
        /// 错误
        var error: ResultAction?
        /// 结束回调
        var endAction: EndAction?

        /// 线程锁
        var taskLock:pthread_mutex_t = pthread_mutex_t()

        /// 结束的任务个数
        var endCount = 0

        init(_ tasks: [Task] = [], complete: ResultAction? = nil, error: ResultAction? = nil) {
            self.tasks.append(contentsOf: tasks)

            pthread_mutex_init(&taskLock, nil)
        }

        func add(_ task:Task) {
            lock()
            guard case .idle = state else {
                print("MutiTask is doing, can't add new task!")
                unlock()
                return
            }
            unlock()

            self.tasks.append(task)

            task.complete = { [weak self] (result) in
                guard let self = self else {
                    return
                }

                if let complete = self.complete {
                    complete(result)
                }
            }

            task.error = { [weak self] (result) in
                guard let self = self else {
                    return
                }

                if let error = self.error {
                    error(result)
                }
            }

            task.endAction = { [weak self] (state) in
                guard let self = self else {
                    return
                }

                self.lock()
                self.endCount += 1
                self.unlock()

                self.end(state)
            }
        }

        func start() {
            lock()
            if case .idle = state {
                state = .doing
            }
            unlock()

            for task in tasks {
                task.start()
            }
        }

        func end(_ state: State) {
            lock()
            guard case .doing = self.state else {
                unlock()
                return
            }

            let count = endCount
            unlock()

            if count == tasks.count {

                var list = [Result]()
                for task in tasks {

                    switch task.state {
                        case .complete(let result):
                            list.append(result)
                        case .error(let result):
                            list.append(result)
                        default:
                            break
                    }

                }
                self.state = .completeAll(list)

                if let complete = self.complete {
                    complete(.results(list))
                }

                if let endAction = endAction {
                    endAction(self.state)
                }
            }
        }

        func cancel() {
            lock()
            self.state = .cancel
            unlock()

            for task in tasks {
                task.cancel()
            }
        }
    }
}

extension AsyncTask.Result {
    public static var success: AsyncTask.Result {
        get {
            return AsyncTask.Result(200)
        }
    }

    public static func result(_ code: Int,_ message: String?,_ data: Any? = nil) -> AsyncTask.Result {
        return AsyncTask.Result(code,message ?? "",data)
    }

    public static func results(_ code: Int,_ message: String?,_ data: Any? = nil,_ results: [AsyncTask.Result] = []) -> AsyncTask.Result {
        return AsyncTask.Result(code,message ?? "",data,results)
    }

    public static func results(_ results: [AsyncTask.Result],_ code: Int = 200,_ message: String? = nil) -> AsyncTask.Result {
        return AsyncTask.Result(code,message ?? "",nil,results)
    }
}

extension AsyncTask.State {
    public static func sucess(_ data:Any? = nil) -> AsyncTask.State {
        return .complete(.result(200, nil, data))
    }

    public static func error(_ code: Int,_ message: String? = nil,_ data: Any? = nil) -> AsyncTask.State {
        return .error(.result(code, message, data))
    }
}
