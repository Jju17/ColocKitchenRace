//
//  PersistenceKey+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 02/06/2024.
//

import ComposableArchitecture
import Foundation

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<User?>> {
    static var userInfo: Self  {
        PersistenceKeyDefault(.fileStorage(.userInfo), nil)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<Cohouse?>> {
    static var cohouse: Self  {
        PersistenceKeyDefault(.fileStorage(.cohouse), nil)
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<[News]>> {
    static var news: Self  {
        PersistenceKeyDefault(.fileStorage(.news), [])
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<[Challenge]>> {
    static var challenges: Self  {
        PersistenceKeyDefault(.fileStorage(.challenges), [])
    }
}

extension PersistenceKey where Self == PersistenceKeyDefault<FileStorageKey<GlobalInfo?>> {
    static var globalInfos: Self  {
        PersistenceKeyDefault(.fileStorage(.globalInfos), nil)
    }
}
