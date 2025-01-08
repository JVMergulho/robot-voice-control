//
//  Functions.swift
//  ARRobot
//
//  Created by João Vitor Lima Mergulhão on 08/01/25.
//
import ARKit

// Helper to extract translation from a matrix
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3(x: columns.3.x, y: columns.3.y, z: columns.3.z)
    }
}
