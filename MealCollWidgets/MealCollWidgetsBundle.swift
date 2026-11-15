import WidgetKit
import SwiftUI

@main
struct MealCollWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MealCollCalendarWidget()
        MealCollQuickImportWidget()
        MealCollCategoryMediumWidget()
        MealCollRandomCategoryWidget()
        MealCollLatestDishWidget()
    }
}

