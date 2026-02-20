import Foundation

/// The two reading modes available in BlazeBooks.
///
/// - **page:** Traditional scrollable text with word-by-word TTS highlighting.
///   The user reads at their own pace; when TTS is active, the currently spoken word
///   is highlighted with a background color and the view auto-scrolls to follow.
/// - **rsvp:** Rapid Serial Visual Presentation -- one word at a time, centered at the
///   Optimal Recognition Point (ORP). Timer or TTS drives word advancement.
///
/// Raw string values are used directly in the segmented Picker display.
enum ReadingMode: String, CaseIterable {
    case page = "Page"
    case rsvp = "RSVP"
}
