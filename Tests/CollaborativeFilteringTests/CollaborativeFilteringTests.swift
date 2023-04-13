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

@testable import CollaborativeFiltering
import LASwift
import XCTest

struct Examples {
    static let invalid: CollaborativeFiltering.Ratings = [
        [1, 1, 2],
        [1, 0, 1],
        [1, 0, 0],
    ]

    static let simple: CollaborativeFiltering.Ratings = [
        [1, 1, 1],
        [1, 0, 1],
        [1, 0, 0],
    ]

    static let complex: CollaborativeFiltering.Ratings = [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1],
        [0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    ]

    static func makeRandom(userCount: Int, itemCount: Int) -> CollaborativeFiltering.Ratings {
        (0 ..< userCount).map { _ in
            (0 ..< itemCount).map { _ in
                Bool.random() ? 1 : 0
            }
        }
    }
}

final class CollaborativeFilteringTests: XCTestCase {
    func testCollaborativeFilter() async {
        let ratings: CollaborativeFiltering.Ratings = [
            [1, 1, 1, 1],
            [1, 0, 1, 1],
            [1, 0, 0, 1],
            [1, 0, 0, 1],
        ]

        let recs = try! CollaborativeFiltering.collaborativeFilter(ratings: ratings, userIndex: 2)

        XCTAssertEqual(recs, [2, 1])
    }

    func testSimpleCoMatrix() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.simple)

        XCTAssertEqual(
            coMatrix,
            Matrix(
                [
                    [0.0 / 1.0, 1.0 / 3.0, 2.0 / 3.0],
                    [1.0 / 3.0, 0.0 / 1.0, 1.0 / 2.0],
                    [2.0 / 3.0, 1.0 / 2.0, 0.0 / 1.0],
                ]
            )
        )
    }

    func testGetRecommendationsSimple1() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.simple)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.simple, coMatrix: coMatrix, userIndex: 1)

        XCTAssertEqual(recs, [1])
    }

    func testGetRecommendationsSimple2() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.simple)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.simple, coMatrix: coMatrix, userIndex: 2)

        XCTAssertEqual(recs, [2, 1])
    }

    func testGetRecommendationsSimple0() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.simple)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.simple, coMatrix: coMatrix, userIndex: 0)

        XCTAssertEqual(recs, [])
    }

    func testThrowsUserIndexOutOfRangeError() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.simple)

        XCTAssertThrowsError(try CollaborativeFiltering.getRecommendations(ratings: Examples.simple, coMatrix: coMatrix, userIndex: 3)) { error in
            XCTAssertEqual(error as! CollaborativeFiltering.Error, CollaborativeFiltering.Error.userIndexOutOfRange)
        }
    }

    func testThrowsCoMatrixWrongDimensionsError() async {
        do {
            _ = try CollaborativeFiltering.getRecommendations(ratings: Examples.simple, coMatrix: ones(4, 7), userIndex: 1)
        } catch {
            XCTAssertEqual(error as! CollaborativeFiltering.Error, CollaborativeFiltering.Error.coMatrixWrongDimensions)
        }
    }

    func testThrowsRatingArrayValueInvalidError() async {
        do {
            _ = try CollaborativeFiltering.createCoMatrix(ratings: Examples.invalid)
        } catch {
            XCTAssertEqual(error as! CollaborativeFiltering.Error, CollaborativeFiltering.Error.ratingArrayValueInvalid)
        }
    }

    func testGetRecommendationsComplex6() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.complex)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.complex, coMatrix: coMatrix, userIndex: 6)

        XCTAssertEqual(recs.first, 1)
        XCTAssertEqual(recs.last, 11)
    }

    func testGetRecommendationsComplex0() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.complex)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.complex, coMatrix: coMatrix, userIndex: 0)

        // The recommendations with rank 1-4 for U0 should be I14-I17 (in no specific order)
        XCTAssertTrue([14, 15, 16, 17].contains(recs[0]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[1]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[2]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[3]))

        // The recommendations with rank 5 for U0 should be I11
        XCTAssertEqual(recs[4], 11)

        // The number of recommendations for U0 should be 5
        XCTAssertEqual(recs.count, 5)
    }

    func testGetRecommendationsComplex9() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.complex)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.complex, coMatrix: coMatrix, userIndex: 9)

        // The only recommendation for U9 should be I12
        XCTAssertEqual(recs.first, 12)
        XCTAssertEqual(recs.count, 1)
    }

    func testGetRecommendationsComplex1() async {
        let coMatrix = try! CollaborativeFiltering.createCoMatrix(ratings: Examples.complex)
        let recs = try! CollaborativeFiltering.getRecommendations(ratings: Examples.complex, coMatrix: coMatrix, userIndex: 1)

        XCTAssertEqual(recs.count, 12)
        XCTAssertEqual(recs.first, 18)

        // The recommendations with rank 1-4 for U0 should be I14-I17 (in no specific order)
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[1]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[2]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[3]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[4]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[5]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[6]))
        XCTAssertTrue([0, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(recs[7]))

        // The recommendations with rank 9-12 should be (I14-I17) in no specific order
        XCTAssertTrue([14, 15, 16, 17].contains(recs[8]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[9]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[10]))
        XCTAssertTrue([14, 15, 16, 17].contains(recs[11]))
    }

    func testPerformance() async {
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let randomRatings = Examples.makeRandom(userCount: 100, itemCount: 100)

            startMeasuring()

            _ = try! CollaborativeFiltering.collaborativeFilter(ratings: randomRatings, userIndex: 1)

            stopMeasuring()
        }
    }
}
