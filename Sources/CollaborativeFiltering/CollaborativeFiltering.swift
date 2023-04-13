//
// Copyright (c) 2019 TSonono
// Copyright (c) 2023 Ryan Ashcraft
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import LASwift

/// Collaborative filtering is a type of recommendation algorithm that utilizes the preferences and behavior of similar
/// users to suggest items that a user may like. It works by finding patterns in the preferences of different users and
/// using these patterns to predict the preferences of new users.
///
/// Collaborative filtering can be used in a variety of applications such as recommending movies, music, or products
/// ("items") to customers ("users"). The algorithm is based on the assumption that people who have similar preferences
/// in the past will have similar preferences in the future.
///
/// The algorithm can also be applied to single-user use cases where you aim to predict future behavior based on past
/// behavior. In scenarios like this, users can instead represent distinct user sessions.
///
/// This implementation was ported from collaborative-filtering, a JavaScript [open-source project by TSonono](https://github.com/TSonono/collaborative-filtering).
public enum CollaborativeFiltering {
    public typealias Ratings = [[Double]]

    public enum Error: Swift.Error {
        case coMatrixWrongDimensions
        case userIndexOutOfRange
        case ratingArrayValueInvalid
    }

    /// Generates recommendations using collaborative filtering.
    ///
    /// This implementation runs in memory and has a runtime complexity of approximately O(U • I^2), where U is the number
    /// of users and I represents the number of items. Therefore, it is best suited for use cases with a reasonably small
    /// scale, e.g. 100 users and 100 items.
    ///
    /// - Parameters:
    ///     - ratings: A two-dimensional array of consisting of the user ratings. The array should be of the following format:
    ///
    ///       ```
    ///             I0 I1 I2 . . .
    ///            [
    ///        U0  [1  1  1  .  .  .],
    ///        U1  [1  0  1  .  .  .],
    ///        U2  [1  0  0  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///            ]
    ///       ```
    ///
    ///       Where IX is an item and UY is a user. Therefore, the size of the matrix be X by Y. The values in the
    ///       matrix should be the rating for a given user. If the user has not rated that item, the value should be 0.
    ///       If the user liked the item, it should be a 1.
    ///
    /// - Returns: An array of item indices, sorted by how recommended the item is.
    public static func collaborativeFilter(ratings: Ratings, userIndex: Int) throws -> [Int] {
        let coMatrix = try createCoMatrix(ratings: ratings)
        let recommendations = try getRecommendations(ratings: ratings, coMatrix: coMatrix, userIndex: userIndex)

        return recommendations
    }

    /// Generate recommendations for a user given a co-occurrence matrix.

    /// - Parameters:
    ///     - ratings: A two-dimensional array of consisting of the user ratings. The array should be of the following format:
    ///
    ///       ```
    ///             I0 I1 I2 . . .
    ///            [
    ///        U0  [1  1  1  .  .  .],
    ///        U1  [1  0  1  .  .  .],
    ///        U2  [1  0  0  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///            ]
    ///       ```
    ///
    ///       Where IX is an item and UY is a user. Therefore, the size of the matrix be X by Y. The values in the
    ///       matrix should be the rating for a given user. If the user has not rated that item, the value should be 0.
    ///       If the user liked the item, it should be a 1.
    ///     - coMatrix: A co-occurrence matrix.
    ///     - userIndex: The index of the user you want to know which items the user has rated.
    ///     - onlyRecommendFromSimilarTaste: When enabled, you will never receive a recommendation from someone who
    ///       has no similarity with the user.
    ///
    /// - Returns: An array of item indices, sorted by how recommended the item is.
    public static func getRecommendations(
        ratings: Ratings,
        coMatrix: Matrix,
        userIndex: Int,
        onlyRecommendFromSimilarTaste: Bool = true
    ) throws -> [Int] {
        let ratingsMatrix = Matrix(ratings)
        let itemCount = ratingsMatrix.cols

        // Runtime validations
        try validateMatrixSize(matrix: coMatrix, size: itemCount)
        try validateUserIndex(userIndex: userIndex, ratings: ratings)
        try validateRatingValues(matrix: ratingsMatrix)

        let ratedItemsForUser: [Int] = getRatedItemsForUser(ratings: ratings, userIndex: userIndex, itemCount: itemCount)
        let ratedItemCount = ratedItemsForUser.count
        let similarities = zeros(ratedItemCount, itemCount)

        // Sum of each row in similarity matrix becomes one row
        var recommendations = zeros(itemCount)

        // Mutate matrices using a mutable pointer to avoid perf penalty from copy on write behavior
        similarities.flat.withUnsafeMutableBufferPointer { similaritiesBuffer in
            recommendations.withUnsafeMutableBufferPointer { recommendationsBuffer in
                for i in 0 ..< ratedItemCount {
                    for j in 0 ..< itemCount {
                        similaritiesBuffer[i * similarities.cols + j] += coMatrix[ratedItemsForUser[i] * coMatrix.cols + j]
                    }
                }

                for i in 0 ..< ratedItemCount {
                    for j in 0 ..< itemCount {
                        recommendationsBuffer[j] += similaritiesBuffer[i * similarities.cols + j]
                    }
                }
            }
        }

        recommendations = rdivide(recommendations, Double(ratedItemCount))

        var rec: [Double?] = recommendations
        var recSorted = recommendations.sorted { $1.isLess(than: $0) }

        if onlyRecommendFromSimilarTaste {
            recSorted = recSorted.filter { $0 != 0 }
        }

        var recOrder: [Int] = recSorted.compactMap { element in
            guard let index = rec.firstIndex(of: element) else { return nil }

            rec[index] = nil // To ensure no duplicate indices in the future iterations

            return index
        }

        recOrder = recOrder.filter { !ratedItemsForUser.contains($0) }

        return recOrder
    }

    /// Generates a co-occurrence matrix.
    ///
    /// - Parameters:
    ///     - ratings: A two-dimensional array of consisting of the user ratings. The array should be of the following format:
    ///
    ///       ```
    ///             I0 I1 I2 . . .
    ///            [
    ///        U0  [1  1  1  .  .  .],
    ///        U1  [1  0  1  .  .  .],
    ///        U2  [1  0  0  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///        .   [.  .  .  .  .  .],
    ///            ]
    ///       ```
    ///
    ///       Where IX is an item and UY is a user. Therefore, the size of the matrix be X by Y. The values in the
    ///       matrix should be the rating for a given user. If the user has not rated that item, the value should be 0.
    ///       If the user liked the item, it should be a 1.
    ///     - normalizeOnPopularity: If false, the popularity of items will bias the results.
    ///
    /// - Returns: A two-dimensional co-occurrence matrix with size X by X (X being the number of items that have
    ///            received at least one rating). The diagonal from left to right should consist of only zeroes.
    public static func createCoMatrix(
        ratings: Ratings,
        normalizeOnPopularity: Bool = true
    ) throws -> Matrix {
        let ratingsMatrix = Matrix(ratings)
        let (userCount, itemCount) = ratingsMatrix.size
        let coMatrix = zeros(itemCount, itemCount)
        let normalizerMatrix = eye(itemCount, itemCount)

        // Mutate matrices using a mutable pointer to avoid perf penalty from copy on write behavior
        coMatrix.flat.withUnsafeMutableBufferPointer { coMatrixBuffer in
            normalizerMatrix.flat.withUnsafeMutableBufferPointer { normalizerMatrixBuffer in
                for y in 0 ..< userCount {
                    for x in 0 ..< itemCount - 1 {
                        for i in x + 1 ..< itemCount {
                            // Co-occurrence
                            if ratings[y][x] == 1 && ratings[y][i] == 1 {
                                coMatrixBuffer[x * itemCount + i] += 1
                                coMatrixBuffer[i * itemCount + x] += 1 // mirror
                            }

                            if normalizeOnPopularity, ratings[y][x] == 1 || ratings[y][i] == 1 {
                                normalizerMatrixBuffer[x * itemCount + i] += 1
                                normalizerMatrixBuffer[i * itemCount + x] += 1
                            }
                        }
                    }
                }
            }
        }

        return normalizeOnPopularity
            ? normalizeCoMatrix(coMatrix: coMatrix, normalizerMatrix: normalizerMatrix)
            : coMatrix
    }

    // MARK: - Private Helpers

    /// Normalizes a co-occurrence matrix based on popularity.
    ///
    /// - Parameters
    ///     - coMatrix: A co-occurrence matrix.
    ///     - normalizerMatrix: A matrix with division factors for the coMatrix. Should be the same size as coMatrix.
    ///
    /// - Returns A normalized co-occurrence matrix.
    static func normalizeCoMatrix(coMatrix: Matrix, normalizerMatrix: Matrix) -> Matrix {
        return rdivide(coMatrix, normalizerMatrix)
    }

    /// Extract which items have a rating for a given user.
    ///
    /// - Parameters:
    ///     - ratings: The ratings of all the users.
    ///     - userIndex: The index of the user you want to know which items he/she/they have rated.
    ///     - itemCount: The number of items which have been rated.
    ///
    /// - Returns: An array of indices noting what games which have been rated.
    static func getRatedItemsForUser(ratings: Ratings, userIndex: Int, itemCount: Int) -> [Int] {
        var ratedItems: [Int] = []

        for index in 0 ..< itemCount {
            if ratings[userIndex][index] != 0 {
                ratedItems.append(index)
            }
        }

        return ratedItems
    }

    // MARK: - Private Runtime Validations

    static func validateMatrixSize(matrix: Matrix, size: Int) throws {
        if matrix.size != (size, size) {
            throw CollaborativeFiltering.Error.coMatrixWrongDimensions
        }
    }

    static func validateUserIndex(userIndex: Int, ratings: Ratings) throws {
        if (userIndex < 0) || (userIndex >= ratings.count) {
            throw CollaborativeFiltering.Error.userIndexOutOfRange
        }
    }

    static func validateRatingValues(matrix: Matrix) throws {
        let allowedRatings: [Double] = [0, 1]

        try matrix.forEach { row in
            try row.forEach { value in
                if !allowedRatings.contains(value) {
                    throw CollaborativeFiltering.Error.ratingArrayValueInvalid
                }
            }
        }
    }
}

// MARK: - LASwift Extensions

private extension Matrix {
    var size: (Int, Int) {
        (rows, cols)
    }
}
