# CollaborativeFiltering

[Collaborative filtering](https://en.wikipedia.org/wiki/Collaborative_filtering) is a type of recommendation algorithm that utilizes the preferences and behavior of similar users to suggest items (e.g. movies, music, products, etc.) that a user may like. It works by finding patterns in the preferences of different users and using these patterns to predict the preferences of new users. This is based on the assumption that people who have similar preferences in the past will have similar preferences in the future.

This library provides one form of collaborative filtering that runs in-memory and uses [Jaccard similarity](https://en.wikipedia.org/wiki/Jaccard_index) to measure the similarity between users' preferences. It provides item recommendations for a user based on users with a similar taste.

You can also apply this algorithm to single-user use cases, where you aim to predict future behavior based on past behavior. In scenarios like this, "users" can instead represent distinct user sessions instead.

This library is largely a straightforward port from [collaborative-filtering](https://github.com/TSonono/collaborative-filtering), a JavaScript open-source project by TSonono.

## Usage

1. Prepare input data ("ratings").

You need to structure your input data as a two-dimensional array. Each row represents a user (or user session), and each column represents an item rating. Each item rating value can either be 0 or 1. 1 is a positive rating, e.g. a "like", rating, purchase, or some type of feature engagement. 0 indicates null or no usage.

```
     I0 I1 I2 . . .
    [
U0  [1  1  1  .  .  .],
U1  [1  0  1  .  .  .],
U2  [1  0  0  .  .  .],
.   [.  .  .  .  .  .],
.   [.  .  .  .  .  .],
.   [.  .  .  .  .  .],
    ]
```

The algorithm in this library runs in-memory and has a runtime complexity of approximately O(U(I^2)), where U is the number of users and I is the number of items. Therefore, it is best suited for use cases with a reasonably small scale.

The current user must be included in this 2D array. When preparing this data, you'll need to remember which row represents the current user and what each column index represents.

```swift
let recommendedItemIndices = try CollaborativeFiltering.collaborativeFilter(
    ratings: ratings,
    userIndex: userIndex
)
```

2. Map the resulting array of indices back to items to recommend.

## Example Use Cases

There are many ways this algorithm could be applied. Here are some creative examples:

1. Implement a feature similar to "Siri Suggestions" on iOS, where items are recommended based on recently selected items.
2. For a social movie tracking app, recommend movies based on what the user has liked versus what their friends have liked.
3. For an instant messaging app, recommend people to add to a group conversation based on other group conversations.
4. For a music playing app, automatically choose songs to play next based on last few songs that the user has selected. In this case, the "users" would represent previous listening sessions. The resulting recommendations could try to predict which songs the user would otherwise manually seek out next. 

## Challenges

### Sparse Data

Very large quantities of items or users will lead to significant performance challenges. Explore various strategies to reducing the size of either items or users. For example, you could only use data from X most recent days. Or you could only include users that have some level of usage.

### Cold Starts

If you don't have enough data for a given user, it's hard for the algorithm to generate good recommendations, especially if the number of items is large.

There is no universal strategy to handling cold starts. One possible solution is to simply suggest the most popular items. You can also try disabling `onlyRecommendFromSimilarTaste`, which is a parameter to the `getRecommendations` function (you'll need to generate the co-occurrence matrix using `createCoMatrix` first). If this flag is disabled, the algorithm may yield recommendations from others that have no similarity with the user.

## Dependencies

This library has one dependency, [LASwift](https://github.com/AlexanderTar/LASwift), which provides various linear algebra conveniences.

## Contributions

If you'd like to submit a bug fix or enhancement, please submit a pull request. Please include some context, your motivation, add tests if appropriate.

## License

See [LICENSE](/LICENSE.md).

Portions of this library were taken and modified from [collaborative-filtering](https://github.com/TSonono/collaborative-filtering), an MIT-licensed library, Copyright (c) 2019 TSonono. The code has been modified for use in this project.
