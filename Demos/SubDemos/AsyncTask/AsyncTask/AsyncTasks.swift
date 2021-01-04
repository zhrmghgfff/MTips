//
//  File.swift
//  
//
//  Created by Ma,Limin on 2020/12/28.
//

import Foundation

public class AsyncTasks : AsyncTask {
    
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

extension AsyncTasks {

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
