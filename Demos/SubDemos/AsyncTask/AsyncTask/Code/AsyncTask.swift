//
//  File.swift
//
//
//  Created by Ma,Limin on 2020/12/28.
//

import Foundation

public class AsyncTask {
    ///记录总创建的个数
    fileprivate static var count:Int = 0
    /// 标记，区分每个不同的对象
    fileprivate var tag: Int

    /// 下一个 Task
    var nextTask: AsyncTask?
    /// 任务
    var task: OneTask?

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
    func end(_ state: State) {
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
    func addTask(_ task:@escaping TaskAction) {
        self.task = Task(task)

        var gcd:AsyncTask? = self
        self.task?.endAction = { state in
            gcd?.end(state)

            gcd = nil
        }
    }
}

// MARK: -
extension AsyncTask {
    /// 任务
    class Task: OneTask {
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
        
        /// 开始
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
        
        /// 结束
        /// - Parameter state: 状态
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
        
        /// 取消
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

// MARK: - 私有辅助函数
extension AsyncTask {

    /// 创建Task
    func createTask(_ task: @escaping TaskAction) -> AsyncTask {

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
    func createMutiTask(_ tasks:[TaskAction]) -> AsyncTask {

        let newTask = AsyncTasks()
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
    func transmitError(_ action:@escaping ResultAction) {

        if let errorDidAdded = errorDidAdded {
            errorDidAdded(action)
        }
    }

    /// 开始任务
    /// - Parameter action: 任务 block
    static func startTask(_ action:@escaping Action) {
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
        return AsyncTasks().tasks(tasks)
    }
}
