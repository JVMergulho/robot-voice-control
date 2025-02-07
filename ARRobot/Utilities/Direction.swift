//
//  Direction.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 08/01/25.
//

enum Direction: String, CaseIterable{
    case forward
    case back
    case left
    case right
    case jump
    
    static func stringToDirection(word: String) -> Direction?{
        for direction in Direction.allCases{
            if direction.rawValue == word{
                return direction
            }
        }
        
        return nil
    }
}
