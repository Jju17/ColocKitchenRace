//
//  PersistenceKey+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 02/06/2024.
//

import Foundation
import Sharing

extension SharedKey where Self == FileStorageKey<User?>.Default {
  static var userInfo: Self {
      Self[.fileStorage(.userInfo), default: nil]
  }
}

extension SharedKey where Self == FileStorageKey<Cohouse?>.Default {
    static var cohouse: Self  {
        Self[.fileStorage(.cohouse), default: nil]
    }
}

extension SharedKey where Self == FileStorageKey<[News]>.Default {
    static var news: Self  {
        Self[.fileStorage(.news), default: []]
    }
}

extension SharedKey where Self == FileStorageKey<[Challenge]>.Default {
    static var challenges: Self  {
        Self[.fileStorage(.challenges), default: []]
    }
}

extension SharedKey where Self == FileStorageKey<CKRGame?>.Default {
    static var ckrGame: Self  {
        Self[.fileStorage(.ckrGame), default: nil]
    }
}
