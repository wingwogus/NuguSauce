import Foundation

enum AppRoute: Hashable {
    case recipeDetail(Int)
    case recipeEdit(Int)
    case publicProfile(Int)
    case profileEdit
    case login
}
