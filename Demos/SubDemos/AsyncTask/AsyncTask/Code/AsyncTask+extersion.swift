//
//  AsyncTask+extersion.swift
//  AsyncTask
//
//  Created by Ma,Limin on 2021/1/26.
//

import Foundation

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
